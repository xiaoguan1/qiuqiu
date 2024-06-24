local skynet = require "skynet"
local mysql = require "skynet.db.mysql"
local assert = assert
local table = table
local pairs = pairs
local is_crossserver = (skynet.getenv("is_cross") == "true") and true or false
local DATABASE_CFG = assert(load("return " .. skynet.getenv("centerdatadb_info"))())
local SNODE = assert(skynet.getenv("node"))
local host_id = tonumber(skynet.getenv("server_id"))
local merge_hosts = skynet.getenv("merge_hosts")
if merge_hosts then
	merge_hosts = assert(load("return " .. merge_hosts))()
end

local function _GetDb()
	local function on_connect(db)
		db:query("set charset utf8")
	end

	local db = mysql.connect({
		host = DATABASE_CFG.dbhost,
		port = DATABASE_CFG.dbport,
		database = DATABASE_CFG.dbname,
		user = DATABASE_CFG.dbuser,
		password = DATABASE_CFG.dbpasswd,
		max_pack_size = 1024 * 1024 * 2^9 - 1,	-- longtext
		on_connect = on_connect,
	})
	-- 询问query的时候如果是断开的还是会继续连接，直到连接上
	if not db then
		return false, string.format("connect mysql(%s:%s) dbname:%s error!", DATABASE_CFG.dbhost, DATABASE_CFG.dbport, DATABASE_CFG.dbname)
	end
	return true, db
end

local function _GetGameNodeInfoByDatabase(db)
	if is_crossserver then
		return false, "can`t use GetGameNodeInfoByDatabase is cross"
	end

	local dpcluster = {}
	local gsql = string.format("select * from game_server where server_id = %d;", host_id)
	local gres = db:query(gsql)
	if not gres["badresult"] then
		local dbData = gres[1]
		node = SNODE .. "_node"
		local node_ipport = dbData[node .. "_ip"] .. ":" .. dbData[node .. "_port"]
		if not node_ipport then
			return false, string.format("database has`t node:%s", node)
		end

		dpcluster.node_ipport = node_ipport
		dpcluster[node] = node_ipport

		for _key, _value in pairs(dbData) do
			if string.endswith(_key, "_serverid") then
				local sIdx = string.find(_key, "_serverid") - 1
				local cNode = string.sub(_key, 1, sIdx) .. "_node"
				local startNodeCol = "is_startup_" .. string.sub(_key, 1, sIdx)
				if _value == host_id then
					return false, string.format("cross:%s can not use same server_id:%s", _key, _value)
				end
				-- 获取数据库
				local csql = string.format("select * from cross_server where server_id = %d;", _value)
				local cres = db:query(csql)
				if not cres["badresult"] then
					local crossData = cres[1]
					local node_ipport = crossData["node_ip"] .. ":" .. crossData["node_port"]
					-- 判断是否活动开启，如果不是则报错
					if crossData[startNodeCol] ~= 1 then
						return false, string.format("cross:%s is not startup in database table:cross_server server_id:%s", _key, _value)
					end
					local namedData = nil
					for _serviceName, _namedData in pairs(CROSS_NAMED_SERVER_NODE) do
						if _namedData.node == cNode then
							namedData = _namedData
						end
					end
					-- 判断一下是否是 servercross 类型的服务
					if namedData and namedData.servercross then
						dpcluster[cNode] = {}
						dpcluster[cNode][host_id] = node_ipport
					else
						dpcluster[cNode] = node_ipport
					end
				else
					return false, string.format("query:%s database error! res:%s", csql, sys.dump(cres))
				end
			end
		end
	else
		return false, string.format("query:%s database error! res:%s", gsql, sys.dump(gres))
	end

	local check_svrdata = gres[1]
	for _server_id, _ in pairs(merge_hosts or {}) do
		if _server_id ~= host_id then
			local gsql = string.format("select * from game_server where server_id = %d;", _server_id)
			local gres = db:query(gsql)
			if not gres["badresult"] then
				if #gres == 1 then
					local data = gres[1]
					local isCheck = false
					for _key, _value in pairs(check_svrdata) do
						-- 如果是 servercross 类型的跨服则加对应服的地址
						if string.endswith(_key, "_serverid") then
							local sIdx = string.find(_key, "_serverid") - 1
							local cNode = string.sub(_key, 1, sIdx) .. "_node"
							local startNodeCol = "is_startup_" .. string.sub(_key, 1, sIdx)

							-- 获取数据库
							local csql = string.format("select * from cross_server where server_id = %d;", _value)
							local cres = db:query(csql)
							if not cres["badresult"] and #cres == 1 then
								local crossData = cres[1]
								local node_ipport = crossData["node_ip"] .. ":" .. crossData["node_port"]
								-- 判断是否活动开启，如果不是则报错
								if crossData[startNodeCol] ~= 1 then
									return false, string.format("cross:%s is not startup in database table:cross_server server_id:%s", _key, data[_key])
								end
								local namedData = nil
								for _serviceName, _namedData in pairs(CROSS_NAMED_SERVER_NODE) do
									if _namedData.node == cNode then
										namedData = _namedData
									end
								end
								-- 判断一下是否是 servercross 类型的跨服
								if namedData and namedData.servercross then
									dpcluster[cNode][_server_id] = node_ipport
									isCheck = true
								end
							else
								return false, string.format("query:%s database error! res:%s", csql, sys.dump(cres))
							end
						end
					end
				end
			else
				return false, string.format("query merge server:%s database error! res:%s", gsql, sys.dump(gres))
			end
		end
	end

	return true, dpcluster
end

local function _GetCrossNodeInfoByDatabase(db)
	if not is_crossserver then
		return false, "can`t use _GetCrossNodeInfoByDatabase is game"
	end

	local csql = string.format("select * from cross_server where server_id = %d;", host_id)
	local gres = db:query(csql)
	if not gres["badresult"] and #gres == 1 then
		local dpData = gres[1]
		local node_ipport = dpData["node_ip"] .. ":" .. dpData["node_port"]
		local dpcluster = {node_ipport = node_ipport}

		for _key, _value in pairs(dpData) do
			if string.beginswith(_key, "is_startup_") then
				if _value == 1 then
					local sIdx, eIdx = string.find(_key, "is_startup_")
					local cNode = string.sub(_key, eIdx + 1) .. "_node"
					-- 如果没有对应的服务节点，或者服务节点不是自己的才设置，否则应该设置dpData[cNode]的ipport
					local serverKey = string.sub(_key, eIdx + 1) .. "_serverid"
					if not dpData[serverKey] or dpData[serverKey] == host_id then
						dpcluster[cNode] = node_ipport
					end
				end
			elseif string.endswith(_key, "_serverid") then
				local sIdx = string.find(_key, "_serverid") - 1
				local cNode = string.sub(_key, 1, sIdx) .. "_node"
				local startNodeCol = "is_startup_" .. string.sub(_key, 1, sIdx)
				if _value ~= host_id then	-- 不是自己节点
					-- 获取数据库
					local csql = string.format("select * from cross_server where server_id = %d;", _value)
					local cres = db:query(csql)
					if not cres["badresult"] and #cres == 1 then
						local crossData = cres[1]
						local node_ipport = crossData["node_ip"] .. ":" .. crossData["node_port"]
						-- 判断是否活动开启，如果不是则报错
						if crossData[startNodeCol] ~= 1 then
							return false, string.format("cross:%s is not startup in database table:cross_server server_id:%s", _key, _value)
						end
						dpcluster[cNode] = node_ipport
					else
						return false, string.format("query:%s database error! res:%s", csql, sys.dump(cres))
					end
				end
			end
		end
		if table.size(dpcluster) <= 1 then
			return false, string.format("server_id:%s not cross activity startup", host_id)
		end
		return true, dpcluster
	else
		return false, string.format("query:%s database error!, res:%s", csql, sys.dump(gres))
	end
end

-- 注意：里面有协程的，会阻塞当前协程，需要处理重入问题
function GetGameNodeInfoByDatabase()
	local ok, db = _GetDb()
	if not ok then
		return false, db
	end
	local ok, ret = _GetGameNodeInfoByDatabase(db)
	db:disconnect()
	return ok, ret
end

-- 注意：里面有协程的，会阻塞当前协程，需要处理重入问题
function GetCrossNodeInfoByDatabase()
	local ok, db = _GetDb()
	if not ok then
		return false, db
	end
	local ok, ret = _GetCrossNodeInfoByDatabase(db)
	db:disconnect()
	return ok, ret
end
