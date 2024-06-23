local skynet = require "skynet"
local mysql = require "skynet.db.mysql"
local assert = assert
local type = type
local pairs = pairs
local xpcall = xpcall
local traceback = debug.traceback
local unpack = table.unpack
local error = error

-- local NODEINFO = Import("base/nodeinfo.lua")
-- local dpclusterData = assert(load("return " .. skynet.getenv("dpcluster"))())
local is_crossserver = (skynet.getenv("is_cross") == "true") and true or false
local is_testserver = (skynet.getenv("is_testserver") == "true") and true or false
local OVERTIME_HEARTBEAT	= 3000 		-- 心跳检测超时
local OVERTIME 				= 300 		-- 默认超时,3秒
local OVERTIME_MAX			= 6000		-- 最大超时,60秒
local lua_pack_func = skynet.get_prototype_pack(skynet.PTYPE_LUA)
local lua_unpack_func = skynet.get_prototype_unpack(skynet.PTYPE_LUA)
assert(lua_pack_func and lua_unpack_func)

-- {
-- 	[nodeName] = {
-- 		errFunc = ,
-- 		errCnt = ,
-- 	}
-- }
NODE_HEARTBEAT = {}
HAS_TIMER = false
dpclusterd = false

local function _ret_func(msg, sz, ok, ...)
	skynet.trash(msg, sz)	-- 释放内存
	if ok then
		if is_testserver then
			for _n, _v in pairs({...}) do
				if type(_v) == "userdata" then
					error("dpcluster ret has point error!")
				end
			end
		end
		return ...
	else
		error((...))
	end
end

local function _dp_call(overtime, node, address, prototype, ...)
	-- skynet.error("--_dp_call:", overtime, node, address, prototype, ...)
	-- ...不能有userdata, 判断一下
	for _n, _v in pairs({...}) do
		if type(_v) == "userdata" then
			error(string.format("node:%s, address:%s, elem no:%d is userdata", node, address, _n))
		end
	end

	local pack_func = skynet.get_prototype_pack(prototype)
	local unpack_func = skynet.get_prototype_unpack(prototype)
	assert(pack_func and unpack_func)

	local msg, sz = skynet.call(dpclusterd, "lua", "req", overtime, node, address, prototype, pack_func(...)) -- 肯定是当前节点，所以不用代理了
	return _ret_func(msg, sz, xpcall(unpack_func, traceback, msg, sz))
end

-- 一般不用的，除非有什么特殊的等待事件需要设置
function call_ot(overtime, node, address, ...)
	assert(overtime > 0 and overtime <= OVERTIME_MAX)
	return _dp_call(overtime, node, address, ...)
end

function call(node, address, ...)
	return _dp_call(OVERTIME, node, address, ...)
end

function send(node, address, prototype, ...)
	-- skynet.error("---send:", overtime, node, address, prototype, ...)
	for _n, _v in pairs({...}) do
		if type(_v) == "userdata" then
			error(string.format("node:%s, address:%s, elem no:%d is userdata", node, address, _n))
		end
	end

	local pack_func = skynet.get_prototype_pack(prototype)
	assert(pack_func)

	return skynet.send(dpclusterd, "lua", "push", node, address, prototype, pack_func(...))		-- 肯定是当前节点，所以不用代理了
end

function send_notips(node, address, prototype, ...)
	-- skynet.error("---send_notips:", overtime, node, address, prototype, ...)
	for _n, _v in pairs({...}) do
		if type(_v) == "userdata" then
			error(string.format("node:%s, address:%s, elem no:%d is userdata", node, address, _n))
		end
	end

	local pack_func = skynet.get_prototype_pack(prototype)
	assert(pack_func)

	return skynet.send(dpclusterd, "lua", "push_notips", node, address, prototype, pack_func(...))		-- 肯定是当前节点，所以不用代理了
end

function call_notips(node, address, prototype, ...)
	-- ...不能有userdata,判断一下
	for _n, _v in ipairs({...}) do
		if type(_v) == "userdata" then
			error(string.format("node:%s, address:%s, elem no:%d is userdata", node, address, _n))
		end
	end

	local pack_func = skynet.get_prototype_pack(prototype)
	local unpack_func = skynet.get_prototype_unpack(prototype)
	assert(pack_func and unpack_func)

	local msg, sz = skynet.call(dpclusterd, "lua", "req_notips", OVERTIME, node, address, prototype, pack_func(...))	-- 肯定是当前节点，所以不用代理了
	return _ret_func(msg, sz, xpcall(unpack_func, traceback, msg, sz))
end

-- 一般不直接调用，此函数是由pbc_send_msg区分节点推送到相应节点的
function write_proto(node, vfd_or_vfds, proto_str)
	assert(type(vfd_or_vfds) ~= "userdata" and type(proto_str) ~= "userdata")
	return skynet.send(dpclusterd, "lua", "write_proto", node, skynet.pack(vfd_or_vfds, proto_str))
end

function close_senderror()
	skynet.send(dpclusterd, "lua", "close_senderror")
end

function open_senderror()
	skynet.send(dpclusterd, "lua", "open_senderror")
end

function closeall()
	skynet.send(dpclusterd, "lua", "closeall")
end

function dealwish_timer()
	while true do
		skynet.sleep(OVERTIME_HEARTBEAT * 2)
		for _nodeName, _data in pairs(NODE_HEARTBEAT) do
			local ok, msg, sz = pcall(skynet.call,
				dpclusterd, "lua", "req_heartbeat", OVERTIME_HEARTBEAT, _nodeName, skynet.PTYPE_LUA, lua_pack_func(true)
			)
			local reOk = nil
			if ok then
				reOk = lua_unpack_func(msg, sz)
				skynet.trash(msg, sz)
			end
			if reOk then
				_data.errCnt = 0
			else
				_data.errCnt = _data.errCnt + 1
				if _data.errCnt >= 3 then
					NODE_HEARTBEAT[_nodeName] = nil
					_data.errFunc()
				end
			end
		end
	end
end

ENV = getfenv(1)
assert(ENV.dealwish_timer)
function heartbeat(errFunc, nodeName)
	assert(type(errFunc) == "function")
	NODE_HEARTBEAT[nodeName] = {
		errFunc = errFunc,
		errCnt = 0,
	}
	if not HAS_TIMER then
		HAS_TIMER = true
		skynet.timeout(0, ENV.dealwish_timer)
	end
end

function __init__()
	dpclusterd = skynet.uniqueservice("dpclusterd")
end

function __update__()
	if is_crossserver then return end	-- 跨服不处理节点变换

	-- local ok, data = NODEINFO.GetGameNodeInfoByDatabase()
	-- if not ok then
	-- 	_ERROR("update dpcluster error, NODEINFO.GetGameNodeInfoByDatabase return:", ok, data)
	-- 	return
	-- end

	-- 注意：热更节点暂时无法做，仅根据节点ip:port无法热更，因为不知道该ip:port对应哪个活动(暂时无法弄)
	-- 获取跨服节点数据库的信息，查看是否与当前的一致
	-- 1.断开要发送玩家在跨服下线(agent服务的)，游戏服也要通知跨服断开(gameserver)
	-- 2.巧妙的方法直接在base/dpcluster.lua替换节点发送(这种替换别的地方都不能变，只是在dpcluster替换，确保别的一直使用旧的)
	-- 3.然后在线玩家重新连回跨服(agent服务的)，游戏服也要通知跨服连接(gameserver)
end