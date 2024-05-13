local skynet = require "skynet"
require "skynet.manager"
local pairs = pairs
local ipairs = ipairs
local table = table
local sys = sys
local Improt = Improt
local string = string

local is_filedb = (skynet.getenv("is_filedb") == "true") and true or false
local DB_CNT = tonumber(skynet.getenv("database_num")) or 10
local PROXYSVR = nil
local SNODE_NAME = DPCLUSTER_NODE.self

-- {
	-- [num] = {addr, proxy},
	-- ...,
-- }
local address = {}
local isclose
local closed_dblist = {}
local close_co
local CMD = {}

function CMD.closealldb()
	if isclose then
		skynet.error("agagin close all db!")
		error("agagin close all db!")
	end
	isclose = true

	local isErr = false
	for i = 1, DB_CNT do
		skynet.fork(function ()
			local dbsvr = address[i].proxy
			local caller, closeerr = pcall(dbsvr.call.closedb)
			if not caller or not closeerr then
				skynet.error("db i:", i, address[i].addr, "close error!", caller, closeerr)
				isErr = true
			end
			closed_dblist[i] = true
			for j = 1, DB_CNT do
				if not closed_dblist[j] then
					return
				end
			end
			if close_co then
				skynet.wakeup(close_co)
			end
		end)
	end

	close_co = coroutine.running()
	skynet.wait()
	close_co = nil
	if isErr then
		error("close database error")
	end
	return true
end

function CMD.reconnectalldb()
	if isclose then
		skynet.error("already close all db!")
		return true
	end

	for i = 1, DB_CNT do
		local dbsvr = address[i].proxy
		local callerr, closeerr = pcall(dbsvr.call.reconnectdb)
		if not callerr or not closeerr then
			local msg = string.format("db i:%s add:%s reconnect callerr:%s closeerr:%s", i, address[i].addr, callerr, closeerr)
			skynet.error(msg)
			return msg
		end
	end
	return true
end

function CMD.assign(session, source, command, assigndata, msg, sz)
	if type(assigndata) ~= "string" then
		if command ~= "battlerecord_deletelist" and command ~= "resultrecord_getdatamap" and command ~= "resultrecord_deletelist" then
			-- 特殊处理
			skynet.trash(msg, sz)
			local msg = string.format("assigndata not string:%s, session:%s, source:%s, command:%s", assigndata, session, source, command)
			error(msg)
		end
	end

	local dbno = nil
	if command == "battlerecord_deletelist" then
		for _, _fId in pairs(assigndata) do
			dbno = string.hash(_fId, DB_CNT)
			break
		end
		if not dbno then
			skynet.trash(msg, sz)
			local msg = string.format("assigndata not dbno, data:%s, session:%s, source:%s, command:%s", assigndata, session, source, command)
			error(msg)
		end
	else
		dbno = string.hash(_fId, DB_CNT)
	end
	local addr = address[dbno] and address[dbno].addr
	if not addr then
		skynet.trash(msg, sz)
		error(string.format("not dbno:%s, assigndata:%s, source:%s, command:%s", dbno, assigndata or "", source, command))
	end
	skynet.redirect(addr, source, "lua", session, msg, sz)
end

skynet.register_protocol {
	name = "trans",
	id = skynet.PTYPE_TRANS,
	pack = skynet.pack,
	unpack = skynet.unpack,
}

if is_filedb then
	local FDATABASE = Improt("service/database/fdatabase.lua")
	skynet.start(function ()
		PROXYSVR = Import("lualib/base/proxysvr.lua")
		local DBALTER = Import("service/database/dbalter.lua")
		DBALTER.CreateGameLogTable()

		skynet.dispatch("lua", function (session, source, command, ...)
			if command == "closealldb" then
				FDATABASE.RESPONSE.closedb()
				skynet.retpack(true)
			else
				local f
				if session == 0 then
					f = assert(FDATABASE.ACCEPT[command])
					f(...)
				else
					f = assert(FDATABASE.RESPONSE[command])
					skynet.retpack(f(...))
				end
			end
		end)
	end)
else
	skynet.forward_type({[skynet.PTYPE_LUA] = skynet.PTYPE_TRANS}, function ()
		PROXYSVR = Import("lualib/base/proxysvr.lua")
		local DBALTER = Import("service/database/dbalter.lua")
		DBALTER.CreateRoleColumns()
		DBALTER.CreateGameLogTable()
		DBALTER.CreateSyncDataTable()

		skynet.dispatch("trans", function (session, source, command, ...)
			if command == "closealldb" then
				skynet.retpack(CMD.closealldb(...))
			elseif command == "reconnectalldb" then
				skynet.retpack(CMD.reconnectalldb(...))
			else
				CMD.assign(session, source, command, ...)
			end
			skynet.ignoreret()
		end)

		for i = 1, DB_CNT do
			-- local db = skynet.newservice("database", skynet.self(), i)
			-- table.insert(address, {
			-- 	addr = db,
			-- 	proxy = PROXYSVR.GetProxy(db, SNODE_NAME)
			-- })
		end

		DBCHECK = Import("service/database/dbcheck.lua")
		DBCHECK.StartUpCheck()
	end)
end




-- -- 因为代码比较少量，故直接在这里Import
-- local DATABASE_OPERATE = Import("service/database/database_operate.lua")

-- -- 内部方法 -------------------------------------------------
-- -- 获取当前节点的信息
-- local function GetNodeInfo()
-- 	local config = DATABASE_OPERATE.GetServerConfig()
-- 	return {
-- 		no = config.server_id,	-- 当前节点的服务器编号
-- 		main_node_ip = config.main_node_ip,
-- 		main_ip_port = config.main_node_ip .. ":" .. config.main_node_port,	-- 服务器地址
-- 		cluster_ip_port = config.cluster_node_ip .. ":" .. config.cluster_node_port, -- 集群地址
-- 		gateway_posts = config.gateway_posts,
-- 	}
-- end

-- -- 这里仅仅只是抄项目的，具体到时涉及到跨服再仔细考量!!!!!
-- local function GetClusterCfg()
-- 	local DPCLUSTER_NODE = GetNodeInfo()
-- 	if not DPCLUSTER_NODE then
-- 		error("GetClusterCfg error.")
-- 	end

-- 	local ret = {}
-- 	for key, value in pairs(DPCLUSTER_NODE) do
-- 		if key ~= "no" and key ~= "gateway_posts" and key ~= "main_node_ip" then
-- 			ret[value] = value
-- 		end
-- 	end

-- 	ret.__nowaiting = skynet.getenv("nowaiting") == "true" and true or false
-- 	return ret
-- end

-- -- 外部方法 -------------------------------------------------

-- skynet.start(function()
--     skynet.dispatch("dboperate", function (session, address, cmd, ...)
-- 		local f = DATABASE_OPERATE[cmd]
-- 		if not f then
-- 			_ERROR_F("database not find func, session:%s address:%s cmd:%s",  session, address, cmd)
-- 			return
-- 		end

-- 		if session ~= 0 then
-- 			TryCall(f, ...)
-- 		else
-- 			local ret = table.pack(TryCall(f, ...))
-- 			if not ret[1] then
-- 				skynet.ret()
-- 				return
-- 			end
-- 			skynet.retpack(table.unpack(ret, 2))
-- 		end
-- 	end)

-- 	-- 设置服务器环境
-- 	local DPCLUSTER_NODE = GetNodeInfo()
-- 	local CLUSTERCFG = GetClusterCfg()
-- 	if not DPCLUSTER_NODE or not CLUSTERCFG then
-- 		error("service env config error!")
-- 	end
-- 	skynet.setenv("DPCLUSTER_NODE", sys.dumptree(DPCLUSTER_NODE))
-- 	skynet.setenv("CLUSTERCFG", sys.dumptree(CLUSTERCFG))

-- 	-- local DPCLUSTER_NODE = skynet.getenv("DPCLUSTER_NODE")
-- 	-- PRINT(load("return " .. DPCLUSTER_NODE)())
-- end)





