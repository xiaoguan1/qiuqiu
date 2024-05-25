local skynet = require "skynet"
require "skynet.manager"
local cluster = require "skynet.cluster"
local set_preload = skynet.getenv("set_preload")
local is_cross = skynet.getenv("is_cross") == "true" and true or false
local assert = assert
local table = table
local Import = Import

local nodeType = skynet.getenv("node_type")

skynet.start(function ()
    assert(nodeType == "game_node" or not is_cross)

    skynet.setenv("preload", set_preload)
    dofile(set_preload)

	local NODEINFO = Import("lualib/base/nodeinfo.lua")
    local isOk, DPCLUSTER_NODE = NODEINFO.GetGameNodeInfoByDatabase()
    if not isOk then
        error(DPCLUSTER_NODE)
    end
    skynet.setenv("DPCLUSTER_NODE", sys.dumptree(DPCLUSTER_NODE))

	_INFO("----- begin start main -----")
    local COMMON_START = Import("startup/common_start.lua")
	COMMON_START.EveryNodeServer()

    for _, svrInfo in pairs(NODE_SERVER_INFO) do
        local isSelfNode = false
        if type(svrInfo.node) == "string" and svrInfo.node == nodeType then
			isSelfNode = true
		elseif type(svrInfo.node) == "table" and table.is_has_value(svrInfo.node, nodeType) then
			isSelfNode = true
		end

        if isSelfNode then
            local svraddr
			if svrInfo.son_num then -- 这个子服务的方式 后续可以考虑去掉 可以参考database服务
				svraddr = skynet.uniqueservice(svrInfo.service)
			else
				svraddr = skynet.newservice(svrInfo.service)
			end
			skynet.name(svrInfo.named, svraddr)
        end
    end

    _INFO("----- end start main -----")
	skynet.exit()
end)