local skynet = require "skynet"
local skynet_manager = require "skynet.manager"
local cluster = require "skynet.cluster"
local set_preload = skynet.getenv("set_preload")
local is_cross = skynet.getenv("is_cross") == "true" and true or false
local assert = assert
-- dofile("./lualib/base/base_class.lua")

DPCLUSTER_NODE = nil
CLUSTERCFG = nil

local function every_node_server()
	for named, registerName in pairs(EVERY_NODE_SERVER) do
		local sid = skynet.uniqueservice(named)
		skynet.name(registerName, sid)
	end
end

skynet.start(function ()
	skynet.setenv("preload", set_preload)
	dofile(set_preload)

	-- 初始化
	_INFO("----- begin start main -----")

	every_node_server()

	DPCLUSTER_NODE = skynet.getenv("DPCLUSTER_NODE")
	CLUSTERCFG = skynet.getenv("CLUSTERCFG")
	if not DPCLUSTER_NODE then
		error("service env config error!")
	end
	DPCLUSTER_NODE = load("return" .. DPCLUSTER_NODE)()
	CLUSTERCFG = load("return" .. CLUSTERCFG)()

	if is_cross then
		-- 跨服的逻辑未定 先随便写（后续再改）
		local proxy = cluster.proxy(DPCLUSTER_NODE.main_ip_port, "agentmgr")
		skynet.name("agentmgr", proxy)
	else
		-- 节点管理
		local nodemgr = skynet.newservice("nodemgr", "nodemgr", 0)
		skynet.name("nodemgr", nodemgr)

		-- 开启 gateway(需要优化，先创建服务，在call设置网关信息 开出socket)
		local gateway = skynet.newservice("gateway", "gateway", 1)
		skynet.name("gateway", gateway)

		local login_num = assert(tonumber(skynet.getenv("login_num")))
		-- 开启 login服务
		for i = 1, login_num do
			local login = skynet.newservice("login", "login", i)
			skynet.name("login_" .. i, login)
		end

		local agentmgr = skynet.newservice("agentmgr", "agentmgr", 0)
		skynet.name("agentmgr", agentmgr)

		-- -- 开启场景服务
		local scene = assert(load("return ".. skynet.getenv("scene"))())
		for _, sceneid in pairs(scene) do
			local srv = skynet.newservice("scene", "scene", sceneid)
			skynet.name("scene" .. sceneid, srv)
		end

		cluster.reload(CLUSTERCFG)
		cluster.open(DPCLUSTER_NODE.main_ip_port)
	end

	skynet.newservice("admin", "admin", 1)
	_INFO("----- end start main -----")
	skynet.exit()
end)
