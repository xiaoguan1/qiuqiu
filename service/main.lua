local skynet = require "skynet"
local skynet_manager = require "skynet.manager"
local cluster = require "skynet.cluster"
local runconfig = require "runconfig"
local set_preload = skynet.getenv("set_preload")
local is_cross = skynet.getenv("is_cross") == "true" and true or false
local assert = assert
local log = require "common_log"
-- dofile("./lualib/base/base_class.lua")

local EVERY_NODE_SERVER = {
	stimer = ".stimer",		-- 定时器服务
}

local function every_node_server()
	for named, registerName in pairs(EVERY_NODE_SERVER) do
		local sid = skynet.uniqueservice(named)
		skynet.name(registerName, sid)
	end
end

skynet.start(function ()
	-- 初始化
	skynet.error("-----------------start main-------------------")
	skynet.setenv("preload", set_preload)
	dofile(set_preload)
	local Node_Info = require "node_info"
	local DPCLUSTER_NODE = assert(Node_Info.GetNodeInfo())
	local clusterCfg = assert(Node_Info.GetClusterCfg())

	every_node_server()
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
		skynet.name("gateway" .. 1, gateway)

		local login_num = assert(tonumber(skynet.getenv("login_num")))
		-- 开启 login服务
		for i = 1, login_num do
			local login = skynet.newservice("login", "login", i)
			skynet.name("login" .. i, login)
		end

		local agentmgr = skynet.newservice("agentmgr", "agentmgr", 0)
		skynet.name("agentmgr", agentmgr)

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
