local skynet = require "skynet"
local sc = require "skynet.socketchannel"
local cluster = require "skynet.cluster"
local node_type = assert(skynet.getenv("node_type"))
local assert = assert
local DPCLUSTER_NODE = DPCLUSTER_NODE
assert(DPCLUSTER_NODE and DPCLUSTER_NODE.self)
local localhost = DPCLUSTER_NODE.self
local string = string

ALL_CLUSTER_ADDRESS = false		-- 集群的网络地址
RELOAD_CFG = false				-- cluster加载配置
CONNECTING = {}					-- 正在连接的对端

-- 内部方法 --------------------
local function _Reload()
	-- 加载全部网络地址
	RELOAD_CFG = {__nowaiting = true}
	ALL_CLUSTER_ADDRESS = {}
	for nodeName, address in pairs(DPCLUSTER_NODE) do
		if address ~= localhost then
			if type(address) == "table" then
				for _, _address in pairs(address) do
					local host, port = string.match(_address, "([^:]+):(.*)$")
					if not host or not port then
						error(string.format("%s network address error", address))
					end

					if not ALL_CLUSTER_ADDRESS[_address] then
						ALL_CLUSTER_ADDRESS[_address] = _address
						RELOAD_CFG[_address] = _address
					end
				end
			else
				local host, port = string.match(address, "([^:]+):(.*)$")
				if not host or not port then
					error(string.format("%s network address error", address))
				end

				if not ALL_CLUSTER_ADDRESS[address] then
					ALL_CLUSTER_ADDRESS[address] = address
					RELOAD_CFG[address] = address
				end
			end
		end
	end
	cluster.reload(RELOAD_CFG)
end

local function _NodeCluster()
	assert(ALL_CLUSTER_ADDRESS)
	-- 节点集群
	if node_type == GAME_NODE_TYPE then
		-- 游戏服节点（主动连接普通跨服）
		for nodeName, address in pairs(ALL_CLUSTER_ADDRESS) do
			local dp = cluster.query(address, "dpclusterd")
			CONNECTING[address] = dp
		end
	elseif node_type == CROSS_NODE_TYPE then -- 跨服
		-- 普通跨服节点（开启网络监听，等待游戏服进行连接）
		cluster.open(localhost)
	else
		error("dpcluster deal cluster, but node type error!")
	end
end

-- 内部方法 --------------------

-- 命令方法 --------------------
CMD = {}
function CMD.req_heartbeat()
end
function CMD.req()
end
function CMD.push()
end
function CMD.push_notips()
end
function CMD.req_notips()
end
function CMD.write_proto()
end
function CMD.close_senderror()
end
function CMD.open_senderror()
end
function CMD.closeall()
end

-- 网络中断
function CMD.interrupt(...)
	local node = ...
	CONNECTING[node] = nil
end
-- 命令方法 --------------------

skynet.register_protocol({
	name = "rpc",
	id = skynet.PTYPE_RPC,
})
skynet.start(function ()
	cluster.register("dpclusterd", skynet.self())
	_Reload()
	_NodeCluster()

	skynet.dispatch("lua", function (session, source, cmd, ...)
		local f = cmd and CMD[cmd]
		if not f then
			error(string.format("dpcluster cmd = [%s] not find func", cmd))
		end
		if session == 0 then
			f(...)
		else
			skynet.response(f(...))
		end
	end)
end)
