local skynet = require "skynet"
local skynet_manager = require "skynet.manager"
local cluster = require "skynet.cluster"
local runconfig = require "runconfig"
local mynode = skynet.getenv("node")

skynet.start(function ()
	-- 初始化
	skynet.error("-----------------start main-------------------")

	-- 节点配置
	local nodecfg = runconfig[mynode]

	-- 节点管理
	local nodemgr = skynet.newservice("nodemgr", "nodemgr", 0)
	skynet.name("nodemgr", nodemgr)

	-- 集群
	cluster.reload(runconfig.cluster)
	cluster.open(mynode)

	-- 开启 gateway
	for i, v in pairs(nodecfg.gateway or {}) do
		local srv = skynet.newservice("gateway", "gateway", i)
		skynet.name("gateway" .. i, srv)
	end

	-- 开启 login服务
	for i, v in pairs(nodecfg.login or {}) do
		local srv = skynet.newservice("login", "login", i)
		skynet.name("login" .. i, srv)
	end

	-- 开启 agentmgr服务
	local anode = runconfig.agentmgr.node
	if mynode == anode then
		local srv = skynet.newservice("agentmgr", "agentmgr", 0)
		skynet.name("agentmgr", srv)
	else
		local proxy = cluster.proxy(anode, "agentmgr")
		skynet.name("agentmgr", proxy)
	end

	-- 开启场景服务
	for _, sceneid in pairs(runconfig.scene[mynode] or {}) do
		local srv = skynet.newservice("scene", "scene", sceneid)
		skynet.name("scene" .. sceneid, srv)
	end

	skynet.exit()
end)
