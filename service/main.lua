local skynet = require "skynet"
local skynet_manager = require "skynet.manager"
local cluster = require "skynet.cluster"
local set_preload = skynet.getenv("set_preload")
local is_cross = skynet.getenv("is_cross") == "true" and true or false
local assert = assert
local table = table
-- dofile("./lualib/base/base_class.lua")

DPCLUSTER_NODE = nil
CLUSTERCFG = nil
DATABASE_OPERATE = false
NODEINFO = false
-- 获取当前节点的信息
local function GetNodeInfo()
	local config = DATABASE_OPERATE.GetServerConfig()
	return {
		no = config.server_id,	-- 当前节点的服务器编号
		main_node_ip = config.main_node_ip,
		main_ip_port = config.main_node_ip .. ":" .. config.main_node_port,	-- 服务器地址
		cluster_ip_port = config.cluster_node_ip .. ":" .. config.cluster_node_port, -- 集群地址
		gateway_posts = config.gateway_posts,
	}
end

-- 这里仅仅只是抄项目的，具体到时涉及到跨服再仔细考量!!!!!
local function GetClusterCfg()
	local DPCLUSTER_NODE = GetNodeInfo()
	if not DPCLUSTER_NODE then
		error("GetClusterCfg error.")
	end

	local ret = {}
	for key, value in pairs(DPCLUSTER_NODE) do
		if key ~= "no" and key ~= "gateway_posts" and key ~= "main_node_ip" then
			ret[value] = value
		end
	end

	ret.__nowaiting = skynet.getenv("nowaiting") == "true" and true or false
	return ret
end


local function GetNodeInfoByDatabase()
	if is_cross then
		-- 普通跨服

	else
		-- 游戏服
		-- 设置服务器环境
		NODEINFO.GetGameNodeInfoByDatabase()
		-- local DPCLUSTER_NODE = GetNodeInfo()
		-- local CLUSTERCFG = GetClusterCfg()
		-- if not DPCLUSTER_NODE or not CLUSTERCFG then
		-- 	error("service env config error!")
		-- end
		-- skynet.setenv("DPCLUSTER_NODE", sys.dumptree(DPCLUSTER_NODE))
		-- skynet.setenv("CLUSTERCFG", sys.dumptree(CLUSTERCFG))
	end
end


local function every_node_server()
	for _, uniservice in ipairs(EVERY_NODE_SERVER) do
		local sid = skynet.uniqueservice(uniservice.service)
		skynet.name(uniservice.named, sid)
	end
end

-- 游戏服启动
local function _GameStart()
	local nodeType = skynet.getenv("node_type")
	for svrName, svrInfo in pairs(NODE_SERVER_INFO) do
		local isSelfNode = false
		if type(svrInfo.node) == "string" and svrInfo.node == nodeType then
			isSelfNode = true
		elseif type(svrInfo.node) == "table" and table.is_has_value(svrInfo.node) then
			isSelfNode = true
		end

		if isSelfNode then
			local svraddr
			if svrInfo.son_num then
				svraddr = skynet.uniqueservice(svrName)
			else
				svraddr = skynet.newservice(svrName)
			end
			skynet.name(svrInfo.named, svraddr)
		end
	end

	cluster.reload(CLUSTERCFG)
	cluster.open(DPCLUSTER_NODE.main_ip_port)
end

-- 跨服启动
local function _CrossStart()
	-- 跨服的逻辑未定 先随便写（后续再改）
	local proxy = cluster.proxy(DPCLUSTER_NODE.main_ip_port, "agentmgr")
	skynet.name("agentmgr", proxy)
end

-- 各种类型节点的启动定制函数
local NODE_START_FUNC = {
	["game_node"] = _GameStart,		-- 游戏服
	["cross_node"] = _CrossStart,	-- 普通跨服
	-- ["center_node"] = ,
	-- ["center_cross_node"] = ,
}

skynet.start(function ()
	skynet.setenv("preload", set_preload)
	dofile(set_preload)

	-- 加载 dbcluster 配置(暂时这样处理 没有更好的办法)
	-- DATABASE_OPERATE = Import("service/database/database_operate.lua")
	NODEINFO = Import("lualib/base/nodeinfo.lua")
	GetNodeInfoByDatabase()

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

	local nodeType = skynet.getenv("node_type")
	local startFunc = nodeType and NODE_START_FUNC[nodeType]
	if not startFunc then
		error(string.format("node type:%s not find start func!", nodeType))
	end
	startFunc()

	_INFO("----- end start main -----")
	skynet.exit()
end)
