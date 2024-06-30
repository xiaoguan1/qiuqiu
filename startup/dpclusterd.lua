local skynet = require "skynet"
local cluster = require "skynet.cluster"
local assert = assert
local DPCLUSTER_NODE = DPCLUSTER_NODE
assert(DPCLUSTER_NODE and DPCLUSTER_NODE.self)
local localhost = DPCLUSTER_NODE.self
local string = string
local clusterName = EVERY_NODE_SERVER and
					EVERY_NODE_SERVER.dpclusterd and
					EVERY_NODE_SERVER.dpclusterd.cluster_named
assert(clusterName)

local node_type = assert(skynet.getenv("node_type"))
local host_id = assert(skynet.getenv("server_id"))
host_id = tonumber(host_id)

ALL_CLUSTER_ADDRESS = {}		-- 集群的网络地址
RELOAD_CFG = {}				-- cluster加载配置

CONNECTING = {}					-- 处于连接状态的数据

CLUSTER_CACHE = {				-- 集群数据的缓存
	-- [address] = {
	-- 	server_id = ...,
	-- 	agent = ...,			-- clusteragent
	-- 	sender = ...,			-- clustersender
	-- 	status = ...,			-- nil:正在连接中、false:网络中断、true:已连接可正常使用
	-- },
}

ACTION = true					-- 服务本次心跳的行为

-- 内部方法 --------------------
local function _Reload()
	-- 加载全部网络地址
	RELOAD_CFG.__nowaiting = true
	for _, address in pairs(DPCLUSTER_NODE) do
		if type(address) == "table" then
			for _, _address in pairs(address) do
				local host, port = string.match(_address, "([^:]+):(.*)$")
				if not host or not port then
					error(string.format("%s network address error", address))
				end

				if _address ~= localhost then
					ALL_CLUSTER_ADDRESS[_address] = _address
				end
				RELOAD_CFG[_address] = _address
			end
		else
			local host, port = string.match(address, "([^:]+):(.*)$")
			if not host or not port then
				error(string.format("%s network address error", address))
			end
			if address ~= localhost then
				ALL_CLUSTER_ADDRESS[address] = address
			end
			RELOAD_CFG[address] = address
		end
	end
	cluster.reload(RELOAD_CFG)
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

if node_type == GAME_NODE_TYPE then		-- 游戏服

	function CMD.accept(clusteragent, address, server_id)
		local data = CLUSTER_CACHE[address]
		if data then
			-- 重连中
			if data.status ~= false then
				_ERROR_F("reconnect server_id:%s address:%s fail.", server_id, address)
				return
			end

			data.agent = clusteragent
			data.server_id = server_id
			data.status = true
			skynet.send(data.sender, "lua", "push", "@dpclusterd", skynet.pack("cluster_ok", localhost, host_id))
			_INFO_F("reconnect server_id:%s address:%s success.", server_id, address)
		else
			local data = CONNECTING[address]
			if not data then
				_ERROR_F("connect error. because not find connect data! address:%s server_id:%s", server_id, address)
				return
			end

			CONNECTING[address] = nil
			CLUSTER_CACHE[address] = data
			data.agent = clusteragent
			data.server_id = server_id
			data.status = true

			-- 借鉴三次握手。本次消息是跨服发来的，所以跨服的网络是正常的(但不确保拥堵等情况)
			skynet.send(data.sender, "lua", "push", "@dpclusterd", skynet.pack("cluster_ok", localhost, host_id))
			_INFO_F("connect server_id:%s address:%s success.", server_id, address)
		end
	end

	-- 游戏服的心跳
	function LoopDeal()
		while true do
			skynet.sleep(500)	-- 10秒

			if ACTION then
				ACTION = false
				-- 主动连接普通跨服
				for _, address in pairs(ALL_CLUSTER_ADDRESS) do
					if not CLUSTER_CACHE[address] and not CONNECTING[address] then
						local clustersender = cluster.get_sender(address)
						if clustersender and not CONNECTING[address] then
							CONNECTING[address] = {
								sender = clustersender,
							}
						end
					end
				end
			else
				ACTION = true
				for address, data in pairs(CONNECTING) do
					skynet.send(data.sender, "lua", "push", "@dpclusterd", skynet.pack("accept", localhost, host_id))
					_INFO_F("connecting address:%s", address)
				end

				-- 网络中断,游戏服主动进行连接.
				for address, data in pairs(CLUSTER_CACHE) do
					if data.status == false then
						if pcall(skynet.call, data.sender, "lua", "changenode", address) then
							skynet.send(data.sender, "lua", "push", "@dpclusterd", skynet.pack("accept", localhost, host_id))
						end
					end
				end
			end
		end
	end

elseif node_type == CROSS_NODE_TYPE then	-- 普通跨服

	-- @param address:游戏服的网络地址
	function CMD.accept(clusteragent, address, server_id)
		if not RELOAD_CFG[address] then
			RELOAD_CFG[address] = address
			cluster.reload(RELOAD_CFG)
		end

		local clusterData = CLUSTER_CACHE[address]
		if clusterData then
			-- 重连中
			if clusterData.status == false then
				if pcall(skynet.call, clusterData.sender, "lua", "changenode", address) then
					if clusterData.status == false then
						clusterData.status = nil
						clusterData.agent = clusteragent
						clusterData.server_id = server_id
						_INFO_F("address:%s server_id:%s reconnecting!", address, server_id)
					end
				end
			else
				_ERROR_F("reconnecting fali! server_id:%s address:%s clusterData:%s", address, server_id, sys.dump(clusterData))
			end
		else
			if CONNECTING[address] then
				if CONNECTING[address].agent == clusteragent and CONNECTING[address].server_id == server_id then
					_WARN_F("repeat accept address:%s server_id:%s", address, server_id)
					return
				end
			end
			CONNECTING[address] = {
				agent = clusteragent,
				server_id = server_id,
				status = nil,
			}
			_INFO_F("accepting server_id:%s address:%s", server_id, address)
		end
	end

	function CMD.cluster_ok(_, address, server_id)
		CLUSTER_CACHE[address].status = true
		_INFO_F("accept server_id:%s address:%s success.", server_id, address)
	end

	-- 普通跨服的心跳
	function LoopDeal()
		while true do
			skynet.sleep(500)	-- 10秒

			if ACTION then
				ACTION = false
				for address, data in pairs(CONNECTING) do
					local clustersender = cluster.get_sender(address)
					if clustersender then
						CONNECTING[address] = nil

						data.sender = clustersender
						CLUSTER_CACHE[address] = data
					end
				end

			else
				ACTION = true
				for _, data in pairs(CLUSTER_CACHE) do
					if data.status == nil then
						skynet.send(data.sender, "lua", "push", "@dpclusterd", skynet.pack("accept", localhost, host_id))
					end
				end
			end
		end
	end

end

-- 网络中断
function CMD.interrupt(source, address)
	_WARN_F("address:%s network interrupt!", address)
	local data = CLUSTER_CACHE[address]
	if data then
		data.status = false
	end
end

-- 命令方法 --------------------

skynet.register_protocol({
	name = "rpc",
	id = skynet.PTYPE_RPC,
})

skynet.start(function ()
	cluster.register(clusterName, skynet.self())
	_Reload()

	skynet.dispatch("lua", function (session, source, cmd, ...)
		local f = cmd and CMD[cmd]
		if not f then
			error(string.format("dpcluster cmd = [%s] not find func", cmd))
		end
		if session == 0 then
			f(source, ...)
		else
			skynet.ret(skynet.pack(f(...)))
		end
	end)

	-- 开启网络监听
	cluster.open(localhost)

	skynet.fork(LoopDeal)
end)

-- 一个小想法
-- 如果能利用clusteragent和clustersender这两个服务检测到的socket状态(例如CMD.interrupt)，就不需要集群之间的心跳消息来保活！