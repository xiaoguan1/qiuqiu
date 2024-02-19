--------------------
-- 模块作用：服务代理，替代skynet的send与call，拓展成不单单对当前节点的send与call
--------------------

local skynet = require "skynet"
local setmetatable = setmetatable
local assert = assert
local error = error
local type = type

local readonly_meta = {__newindex = function () error("read only") end}
local cluster = require "skynet.cluster"

local skynet_send = skynet.send
local skynet_call = skynet.call

local cluster_send = cluster.send
local cluster_call = cluster.call

ALL_PROXYSVR = {
	self_node = {},
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

local function create_proxysvr(addrname, prototype)
	assert(type(addrname) == "string")

	return {
		addrname = addrname,
		prototype = prototype,
		send = gen_send(addrname, prototype),
		call = gen_call(addrname, prototype),
	}
end


-- 外部接口 ------------------------------
function GetProxy(addrname, prototype)
	if ALL_PROXYSVR.self_node[addrname] and ALL_PROXYSVR.self_node[addrname].prototype == prototype then
		return ALL_PROXYSVR.self_node[addrname]
	else
		local proxy = create_proxysvr(addrname, prototype)
		ALL_PROXYSVR.self_node[addrname] = proxy
		return proxy
	end
end
