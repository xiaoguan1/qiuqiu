local skynet = require "skynet"
local skynet_manager = require "skynet.manager"
local cluster = require "skynet.cluster"
local set_preload = skynet.getenv("set_preload")
local is_cross = skynet.getenv("is_cross") == "true" and true or false
local assert = assert
local table = table

local nodeType = skynet.getenv("node_type")

skynet.start(function ()
	assert(nodeType == "cross_node" or is_cross)

	skynet.setenv("preload", set_preload)
	dofile(set_preload)

	local NODEINFO = Import("lualib/base/nodeinfo.lua")
	local isOk, DPCLUSTER_NODE = NODEINFO.GetCrossNodeInfoByDatabase()
	if not isOk then
		error(DPCLUSTER_NODE)
	end
	skynet.setenv("DPCLUSTER_NODE", sys.dumptree(DPCLUSTER_NODE))

	_INFO("----- begin start main -----")
	local COMMON_START = Import("startup/common_start.lua")
	COMMON_START.EveryNodeServer()

end)
