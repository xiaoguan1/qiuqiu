--------------------
-- 模块作用：服务代理，替代skynet的send与call，拓展成不单单对当前节点的send与call
--------------------

local skynet = require "skynet"
local setmetatable = setmetatable
local assert = assert
local error = error
local type = type
local DPCLUSTER_NODE = DPCLUSTER_NODE
local selfnode_name = DPCLUSTER_NODE.self

local readonly_meta = {__newindex = function () error("read only") end}
local cluster = require "skynet.cluster"

local skynet_send = skynet.send
local skynet_call = skynet.call

local cluster_send = cluster.send
local cluster_call = cluster.call

ALL_PROXYSVR = {
	self_node = {},
	othernode = {},
	-- ....
}

local function gen_send(addr, prototype)
	prototype = prototype or "lua"
	local addrtype = type(addr)
	local addrnum = nil
	local cache_func = {}
	return setmetatable({},  {
		__index = function (t, k)
			if addrtype == "string" then
				if not addrnum then
					addrnum = skynet.localname(addr)
					if not addrnum then
						error("not service by name" .. addr)
					end
				end
			else
				addrnum = addr
			end
			if not cache_func[k] then
				cache_func[k] = function(...)
					return skynet_send(addrnum, prototype, k, ...)
				end
			end
			return cache_func[k]
		end,
		__call = function (t, ...)
			if addrtype == "string" then
				if not addrnum then
					addrnum = skynet.localname(addr)
					if not addrnum then
						error("not service by name" .. addr)
					end
				end
			else
				addrnum = addr
			end
			return skynet_send(addrnum, prototype, ...)
		end
	})
end

local function gen_call(addr, prototype)
	prototype = prototype or "lua"
	local addrtype = type(addr)
	local addrnum = nil
	local cache_func = {}
	return setmetatable({},  {
		__index = function (t, k)
			if addrtype == "string" then
				if not addrnum then
					addrnum = skynet.localname(addr)
					if not addrnum then
						error("not service by name" .. addr)
					end
				end
			else
				addrnum = addr
			end
			if not cache_func[k] then
				cache_func[k] = function(...)
					return skynet_call(addrnum, prototype, k, ...)
				end
			end
			return cache_func[k]
		end,
		__call = function (t, ...)
			if addrtype == "string" then
				if not addrnum then
					addrnum = skynet.localname(addr)
					if not addrnum then
						error("not service by name" .. addr)
					end
				end
			else
				addrnum = addr
			end
			return skynet_call(addrnum, prototype, ...)
		end
	})
end

local READONLY_META = { __newindex = function () error("read only") end }

local function create_proxysvr(addr, nodeName, clustertype, prototype)
	return setmetatable({
		addr = addr,
		nodeName = nodeName,
		clustertype = clustertype,
		prototype = prototype,

		send = gen_send(addr, prototype),
		call = gen_call(addr, prototype),
	}, READONLY_META)
end


-- 外部接口 ------------------------------
function GetProxy(addr, node_name, clustertype, prototype)
	if node_name == selfnode_name then
		-- 本服节点
		if ALL_PROXYSVR.self_node[addr] and ALL_PROXYSVR.self_node[addr].prototype == prototype then
			return ALL_PROXYSVR.self_node[addr]
		else
			local proxy = create_proxysvr(addr, node_name, clustertype, prototype)
			ALL_PROXYSVR.self_node[addr] = proxy
			return proxy
		end
	else
		-- 跨服节点
		assert(node_name)
		if ALL_PROXYSVR.othernode[addr] and ALL_PROXYSVR.othernode[addr][node_name] and ALL_PROXYSVR.othernode[addr][node_name].prototype == prototype then
			local proxy = ALL_PROXYSVR.othernode[addr][node_name]
			assert(clustertype == proxy.clustertype)
			return proxy
		else
			local proxy = create_proxysvr(addr, node_name, clustertype, prototype)
			ALL_PROXYSVR.othernode[addr] = ALL_PROXYSVR.othernode[addr] or {}
			ALL_PROXYSVR.othernode[addr][node_name] = ALL_PROXYSVR.othernode[addr][node_name] or {}
			ALL_PROXYSVR.othernode[addr][node_name] = proxy
			return proxy
		end
	end
end
