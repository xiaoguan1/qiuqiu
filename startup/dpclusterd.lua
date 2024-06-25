local skynet = require "skynet"
local sc = require "skynet.socketchannel"
local cluster = require "skynet.cluster"
local node_type = assert(skynet.getenv("node_type"))
local assert = assert
local DPCLUSTER_NODE = DPCLUSTER_NODE
assert(DPCLUSTER_NODE and DPCLUSTER_NODE.self)
local localhost = DPCLUSTER_NODE.self
local string = string

skynet.register_protocol({
	name = "rpc",
	id = skynet.PTYPE_RPC,
})

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

skynet.start(function ()
	-- 收集全部网络地址
	local allAddress = {__nowaiting = true}
	for nodeName, address in pairs(DPCLUSTER_NODE) do
		if type(address) == "table" then
			for _, _address in pairs(address) do
				local host, port = string.match(address, "([^:]+):(.*)$")
				if not host or not port then
					error(string.format("%s network address error", address))
				end

				if not allAddress[_address] then
					allAddress[_address] = _address
				end
			end
		else
			local host, port = string.match(address, "([^:]+):(.*)$")
			if not host or not port then
				error(string.format("%s network address error", address))
			end

			if not allAddress[_address] then
				allAddress[_address] = _address
			end
		end
	end
	cluster.reload(allAddress)	-- 后续要支持热更！
	cluster.register("dpclusterd", skynet.self())

	skynet.dispatch("lua", function (session, source, cmd, ...)
		local f = cmd and CMD[cmd]
		if not f then
			error(string.format("dpcluster cmd=%s not find func", cmd))
		end
		if session == 0 then
			f(...)
		else
			skynet.response(f(...))
		end
	end)

	if node_type == "game_node" then
		-- 游戏服节点（主动连接普通跨服）
		for nodeName, address in pairs(DPCLUSTER_NODE) do
			if string.endswith(nodeName, "_node") and address ~= localhost then
				if type(address) == "table" then
					for serverId, _address in pairs(address) do

					end
				else
					cluster.proxy(address, "dpclusterd")
				end
			end
		end

		-- cluster.query()
	elseif node_type == "cross_node" then
		-- 普通跨服节点（开启网络监听，等待游戏服进行连接）
		cluster.open(localhost)
	else
		error("dpcluster deal cluster, but node type error!")
	end

end)
