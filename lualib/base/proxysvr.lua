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

local is_testserver = (skynet.getenv("is_testserver") == "true") and true or false
local function _obj_check(...)
	if is_testserver then
		local n = select("#", ...)
		local arg = {...}
		for i = 1, n do
			if type(arg[i]) == "table" then
				if getmetatable(arg[i]) and getmetatable(arg[i]).__ObjectType then	-- 是对象
					error("param can not be obj")
				end
			end
		end
	end
end

ALL_PROXYSVR = {
	self_node = {},
	othernode = {},
	-- ....
}

local function gen_send(addr, nodeName, clustertype, prototype)
	prototype = prototype or "lua"
	if nodeName == selfnode_name then
		local addrtype = type(addr)
		local addr_num = nil
		local cache_func = {}
		return setmetatable({},  {
			__index = function (t, k)
				if addrtype == "string" then
					if not addr_num then
						addr_num = skynet.localname(addr)
						if not addr_num then error("not service by name" .. addr) end
					end
				else
					addr_num = addr
				end
				if not cache_func[k] then
					cache_func[k] = function(...)
						_obj_check(...)
						return skynet_send(addr_num, prototype, k, ...)		-- skynet.send那里有返回是否有那个节点的信息
					end
				end
				return cache_func[k]
			end,
			__call = function (t, ...)
				if addrtype == "string" then
					if not addr_num then
						addr_num = skynet.localname(addr)
						if not addr_num then error("not service by name" .. addr) end
					end
				else
					addr_num = addr
				end
				_obj_check(...)
				return skynet_send(addr_num, prototype, ...)				-- skynet.send那里有返回是否有那个节点的信息
			end
		})
	else
		local cache_func = {}
		if clustertype == "cluster" then
			return setmetatable({}, {
				__index = function (t, k)
					if not cache_func[k] then
						cache_func[k] = function (...)
							_obj_check(...)
							cluster_send(nodeName, addr, prototype, k, ...)
						end
					end
					return cache_func[k]
				end,
				__call = function (t, ...)
					_obj_check(...)
					cluster_send(nodeName, addr, prototype, ...)
				end
			})
		elseif not clustertype or clustertype == "dpcluster" then
			return setmetatable({}, {
				__index = function (t, k)
					if not cache_func[k] then
						cache_func[k] = function (...)
							_obj_check(...)
							return DPCLUSTER.send(nodeName, addr, prototype, k, ...)	-- skynet.send那里有返回是否有那个节点的信息
						end
					end
					return cache_func[k]
				end,
				__call = function (t, ...)
					_obj_check(...)
					return DPCLUSTER.send(nodeName, addr, prototype, ...)				-- skynet.send那里有返回是否有那个节点的信息
				end
			})
		else
			error(string.format("error clustertype:%s, addr:%s, nodeName:%s", clustertype, addr, nodeName))
		end
	end
end

local function gen_call(addr, nodeName, clustertype, prototype)
	prototype = prototype or "lua"
	if nodeName == selfnode_name then
		local addrtype = type(addr)
		local addr_num = nil
		local cache_func = {}
		return setmetatable({},  {
			__index = function (t, k)
				if addrtype == "string" then
					if not addr_num then
						addr_num = skynet.localname(addr)
						if not addr_num then error("not service by name" .. addr) end
					end
				else
					addr_num = addr
				end
				if not cache_func[k] then
					cache_func[k] = function(...)
						_obj_check(...)
						return skynet_call(addr_num, prototype, k, ...)		-- skynet.send那里有返回是否有那个节点的信息
					end
				end
				return cache_func[k]
			end,
			__call = function (t, ...)
				if addrtype == "string" then
					if not addr_num then
						addr_num = skynet.localname(addr)
						if not addr_num then error("not service by name" .. addr) end
					end
				else
					addr_num = addr
				end
				_obj_check(...)
				return skynet_call(addr_num, prototype, ...)				-- skynet.send那里有返回是否有那个节点的信息
			end
		})
	else
		local host, port = string.match(nodeName, "([^:]+):(.*)$")
		if not host or not port then
			error("not math host:port " .. nodeName)
		end
		local cache_func = {}
		if clustertype == "cluster" then
			return setmetatable({}, {
				__index = function (t, k)
					if not cache_func[k] then
						cache_func[k] = function (...)
							_obj_check(...)
							cluster_call(nodeName, addr, prototype, k, ...)
						end
					end
					return cache_func[k]
				end,
				__call = function (t, ...)
					_obj_check(...)
					cluster_call(nodeName, addr, prototype, ...)
				end
			})
		elseif not clustertype or clustertype == "dpcluster" then
			return setmetatable({}, {
				__index = function (t, k)
					if not cache_func[k] then
						cache_func[k] = function (...)
							_obj_check(...)
							return DPCLUSTER.call(nodeName, addr, prototype, k, ...)
						end
					end
					return cache_func[k]
				end,
				__call = function (t, ...)
					_obj_check(...)
					return DPCLUSTER.call(nodeName, addr, prototype, ...)
				end
			})
		else
			error(string.format("error clustertype:%s, addr:%s, nodeName:%s", clustertype, addr, nodeName))
		end
	end
end

local READONLY_META = { __newindex = function () error("read only") end }

local function create_proxysvr(addr, nodeName, clustertype, prototype)
	return setmetatable({
		addr = addr,
		nodeName = nodeName,
		clustertype = clustertype,
		prototype = prototype,

		send = gen_send(addr, nodeName, clustertype, prototype),
		call = gen_call(addr, nodeName, clustertype, prototype),
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

-- function GetProxyByServiceName(serviceName, prototype, serverId)
-- 	if NAMEDSVR_PFCROSS_NODES[serviceName] then
-- 		if not serverId then
-- 			error(string.format("GetProxyByServiceName serviceName:%s not has serverId", serviceName))
-- 		end
-- 		local namedData = CROSS_NAMED_SERVER_NODE[serviceName]
-- 		return pfwrapper(namedData.named, serviceName, serverId, namedData.clustertype, prototype)
-- 	elseif NAMEDSVR_MULTPFCROSS_NODES[serviceName] and not is_crossserver then	-- 调用自己节点的其他服务可以不用serverid
-- 		if not serverId then
-- 			error(string.format("GetProxyByServiceName serviceName:%s not has serverId", serviceName))
-- 		end
-- 		local namedData = CROSS_NAMED_SERVER_NODE[serviceName]
-- 		return multpfwrapper(namedData.named, serviceName, serverId, namedData.clustertype, prototype)
-- 	else
-- 		local namedData = NAMED_SERVER_NODE[serviceName]
-- 		if namedData then
-- 			assert(namedData.named)
-- 			local node_name = nil
-- 			if namedData.node then
-- 				node_name = DPCLUSTER_NODE[namedData.node]
-- 				if type(node_name) == "table" then
-- 					if not serverId then
-- 						error("servercross, has not 3th param")
-- 					end
-- 					node_name = node_name[serverId]
-- 				end
-- 				assert(node_name, namedData.node)
-- 			end
-- 			return GetProxy(namedData.named, node_name, namedData.clustertype, prototype)
-- 		end

-- 		local snamedData = NAME_SERVER_EVERY[serviceName]
-- 		if snamedData then
-- 			assert(snamedData.named)
-- 			return GetProxy(snamedData.named, selfnode_name, snamedData.clustertype, prototype)
-- 		end
-- 		error("not proxy:" .. serviceName)
-- 	end
-- end

function GetProxyByServiceName(serviceName, prototype, serverId)
	local namedData = NODE_ONLYSERVER_MIRROR[serviceName]
	if namedData then
		assert(namedData.named)
		return GetProxy(namedData.named, selfnode_name, namedData.clustertype, prototype)
	end

	namedData = NODE_SERVER_INFO_MIRROR[serviceName]
	if namedData then
		assert(namedData.named)
		local node_name = nil
		if namedData.node then
			node_name = DPCLUSTER_NODE[namedData.node]
			if type(node_name) == "table" then
				if not serverId then
					error("servercross, has not 3th param")
				end
				node_name = node_name[serverId]
			end
			assert(node_name, namedData.node)
		end
		return GetProxy(namedData.named, node_name, namedData.clustertype, prototype)
	end
	error("not proxy:" .. serviceName)
end
