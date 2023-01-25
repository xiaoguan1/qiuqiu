local skynet = require "skynet"
local skynet_manager = require "skynet.manager"
local cluster = require "skynet.cluster"
local runconfig = require "runconfig"
local set_preload = skynet.getenv("set_preload")
local is_cross = skynet.getenv("is_cross") == "true" and true or false
local assert = assert
local log = require "common_log"

skynet.start(function ()
	-- 初始化
	skynet.error("-----------------start main-------------------")

	skynet.setenv("preload", set_preload)
	dofile(set_preload)
	local Node_Info = require "node_info"
	local DPCLUSTER_NODE = assert(Node_Info.GetNodeInfo())
	local clusterCfg = assert(Node_Info.GetClusterCfg())

	if is_cross then
		-- 跨服的逻辑未定 先随便写（后续再改）
		local proxy = cluster.proxy(DPCLUSTER_NODE.main_ip_port, "agentmgr")
		skynet.name("agentmgr", proxy)
	else
		-- 节点管理
		local nodemgr = skynet.newservice("nodemgr", "nodemgr", 0)
		skynet.name("nodemgr", nodemgr)

		-- 开启 gateway(需要优化，先创建服务，在call设置网关信息 开出socket)
		local srv = skynet.newservice("gateway", "gateway", 1)
		skynet.name("gateway" .. 1, srv)

		local login_num = assert(tonumber(skynet.getenv("login_num")))
		-- 开启 login服务
		for i = 1, login_num do
			local srv = skynet.newservice("login", "login", i)
			skynet.name("login" .. i, srv)
		end

		local srv = skynet.newservice("agentmgr", "agentmgr", 0)
		skynet.name("agentmgr", srv)

		-- -- 开启场景服务
		local scene = assert(load("return ".. skynet.getenv("scene"))())
		for _, sceneid in pairs(scene) do
			local srv = skynet.newservice("scene", "scene", sceneid)
			skynet.name("scene" .. sceneid, srv)
		end

		cluster.reload(clusterCfg)
		cluster.open(DPCLUSTER_NODE.main_ip_port)
	end

	skynet.newservice("admin", "admin", 1)
	skynet.exit()
end)
