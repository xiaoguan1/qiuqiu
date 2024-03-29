local skynet = require "skynet"
local table = table
local sys = sys

-- 因为代码比较少量，故直接在这里Import
local DATABASE_OPERATE = Import("service/database/database_operate.lua")

-- 内部方法 -------------------------------------------------
-- 获取当前节点的信息
local function GetNodeInfo()
	local config = DATABASE_OPERATE.GetServerConfig()

	return {
		no = config.server_id,	-- 当前节点的服务器编号
		main_ip_port = config.main_node_ip .. ":" .. config.main_node_port,	-- 服务器地址
		cluster_ip_port = config.cluster_node_ip .. ":" .. config.cluster_node_port, -- 集群地址
	}
end

local function GetClusterCfg()
	local DPCLUSTER_NODE = GetNodeInfo()
	if not DPCLUSTER_NODE then
		error("GetClusterCfg error.")
	end

	local ret = {}
	for key, value in pairs(DPCLUSTER_NODE) do
		if key ~= "no" then
			ret[value] = value
		end
	end

	ret.__nowaiting = skynet.getenv("nowaiting") == "true" and true or false
	return ret
end

-- 外部方法 -------------------------------------------------

skynet.start(function()
    skynet.dispatch("dboperate", function (session, address, cmd, ...)
		local f = DATABASE_OPERATE[cmd]
		if not f then
			_ERROR_F("database not find func, session:%s address:%s cmd:%s",  session, address, cmd)
			return
		end

		if session ~= 0 then
			TryCall(f, ...)
		else
			local ret = table.pack(TryCall(f, ...))
			if not ret[1] then
				skynet.ret()
				return
			end
			skynet.retpack(table.unpack(ret, 2))
		end
	end)

	-- 设置服务器环境
	local DPCLUSTER_NODE = GetNodeInfo()
	local CLUSTERCFG = GetClusterCfg()
	if not DPCLUSTER_NODE or not CLUSTERCFG then
		error("service env config error!")
	end
	skynet.setenv("DPCLUSTER_NODE", sys.dumptree(DPCLUSTER_NODE))
	skynet.setenv("CLUSTERCFG", sys.dumptree(CLUSTERCFG))

	-- local DPCLUSTER_NODE = skynet.getenv("DPCLUSTER_NODE")
	-- PRINT(load("return " .. DPCLUSTER_NODE)())
end)
