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

local function every_node_server()
	for named, registerName in pairs(EVERY_NODE_SERVER) do
		local sid = skynet.uniqueservice(named)
		skynet.name(registerName, sid)
	end
end

-- 游戏服启动
local function _GameStart()
	local nodeName = skynet.getenv("node_name")
	for svrName, svrInfo in pairs(NODE_SERVER_INFO) do
		local isSelfNode = false
		if type(svrInfo.node) == "string" and svrInfo.node == nodeName then
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

	local nodeName = skynet.getenv("node_name")
	local startFunc = nodeName and NODE_START_FUNC[nodeName]
	if not startFunc then
		error(string.format("node name:%s not find start func!", nodeName))
	end
	startFunc()

	_INFO("----- end start main -----")
	skynet.exit()
end)
