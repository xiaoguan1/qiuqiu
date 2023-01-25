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

local function gen_send(addr, nodeName, clustertype, prototype)
    prototype = prototype or "lua"
    -- if nodeName = 


end




