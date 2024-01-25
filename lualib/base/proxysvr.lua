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
	

end

local function gen_call()
end

local function create_proxysvr(addrname, prototype)
	if not addrname then return end

	local address
	prototype = prototype or "lua"
	if type(addrname) == "string" then
		address = skynet.localname(string)
	end
	assert(type(address) == "number")

	return {
		addrname = addrname,
		address = address,
		prototype = prototype,
		send = ,
		call = ,
	}
end

function GerProxy(addrName, prototype)
	if ALL_PROXYSVR.self_node[addrName] and ALL_PROXYSVR.self_node[addrName].prototype == prototype then
		return ALL_PROXYSVR.self_node[addrName]
	else

	end
end


