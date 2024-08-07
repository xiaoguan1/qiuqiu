local skynet = require "skynet"
local nodeType = skynet.getenv("node_type")
local error = error
local string = string
local sys = sys

-- 任何节点都必须启动的服务
NODE_ONLYSERVER = {
	{service = "stimer", named = ".STIMER"},		-- 定时器服务
	{service = "loadxls", named = ".LOADXLS"},		-- 公共配置表服务
	{service = "database", named = ".DATABASE"},	-- 数据库服务
	{service = "dpclusterd", named = ".DPCLUSTERD", cluster_named = "dpclusterd"}, 	-- 集群服务
}

-- 节点启动详情
-- @named 注册的服务名
-- @node 限制某些节点才能启动
-- @son_num 子服务的数量
if nodeType == GAME_NODE_TYPE then
	NODE_SERVER_INFO = {
		-- 节点管理
		{service = "nodemgr", named = ".NODEMGR", node = {GAME_NODE_TYPE, CROSS_NODE_TYPE}},

		-- 运营管理
		{service = "admin", named = ".ADMIN", node = GAME_NODE_TYPE},

		-- 网关
		{service = "logind", named = ".LOGIND", node = GAME_NODE_TYPE, son_num = 5},
	}
elseif nodeType == CROSS_NODE_TYPE then
	NODE_SERVER_INFO = {}
else
	error("error node type")
end

-- 跨服服务
CROSS_NAMED_SERVER_NODE = {
	["crosssvr/cadvarena"] = {
		named = ".CADVARENA",
		node = "cadvarena_node",	-- 注意：根据区服跨服，需要根据需求设置
		servercross = true,
		subsvc = {	-- 跨服内的其他子服务
			["crosssvr/svrbattle"] = {named = ".SVRBATTLE"},
			["crosssvr/display"] = {named = ".DISPLAY"},
		},
	},
	["crosssvr/centerchat"] = {
		named = ".CENTERCHAT",
		node = "centerchat_node",
	},
	["crosssvr/cmultpfcenter"] = {
		named = ".CMULTPFCENTER",
		node = "cmultpfcenter_node",
		isc2c = true,			-- 注意：是否是跨服调用跨服的，如果是则游戏服rpc没有对应的接口
	},
	["crosssvr/cmultpfcross_example"] = {
		named = ".CMPFCROSS_EXAMPLE",
		node = "cmultpfcross_node",
		ismultpfcross = true,	-- 注意：这个跨服是游戏服通过中心服获取分配再连接的
		subsvc = {
			["crosssvr/cmultpfcross_slvmonitor"] = {named = ".MULTSLVMONITOR"},
		},
	},
	["crosssvr/cmultpfcross_league"] = {
		named = "CMPFCROSS_LEAGUE",
		node = "cmultpfcross_node",
		ismultpfcross = true,
		subsvc = {
			["crosssvr/cmultpfcross_slvmonitor"] = {named = ".MULTSLVMONITOR"},
			["crosssvr/filedisplay"] = {named = ".FILEDISPLAY"},
			["crosssvr/svrbattle"] = {named = ".SVRBATTLE"},
			["crosssvr/cmultpfcross_chat"] = {named = ".CROSS_CHAT"},
		},
	},
	-- ...
}

-- 检查 NODE_ONLYSERVER 配置 并生成镜像
NODE_ONLYSERVER_MIRROR = {}
for index, serverInfo in ipairs(NODE_ONLYSERVER) do
	if not serverInfo.service or not serverInfo.named then
		error(string.format("NODE_ONLYSERVER _index:%s service:%s named:%s config error",
			index, serverInfo.service, serverInfo.named))
	end

	local data = table.copy(serverInfo)
	data.index = index
	NODE_ONLYSERVER_MIRROR[serverInfo.service] = data
end

-- 检查 NODE_SERVER_INFO 配置 并生成镜像
NODE_SERVER_INFO_MIRROR = {}
for index, svrInfo in pairs(NODE_SERVER_INFO) do
	local condition1 = type(svrInfo.named) == "string" and #svrInfo.named > 0
	local condition2 = type(svrInfo.node) == "table" or type(svrInfo.node) == "string"
	local condition3 = (not svrInfo.son_num) or (type(svrInfo.son_num) == "number" and svrInfo.son_num > 0)

	if not (condition1 and condition2 and condition3 and svrInfo.service) then
		error(string.format("namedsvr service config error! condition1:%s condition2:%s condition3:%s  svrname:%s  nodedata:%s",
			condition1, condition2, condition3, svrInfo.service, sys.dump(svrInfo)))
	end

	local data = table.copy(svrInfo)
	data.index = index
	NODE_SERVER_INFO_MIRROR[svrInfo.service] = data
end

-- 记录服务的子服务的名称
SERVER_SON_NAMED_MAP = {}
for _, svrInfo in pairs(NODE_SERVER_INFO) do
	if svrInfo.son_num then
		for i = 1, svrInfo.son_num do
			local sonNamed = svrInfo.named .. "_SON_" .. i
			SERVER_SON_NAMED_MAP[sonNamed] = {
				idx = i,	-- 序号
				father_named = svrInfo.named,	-- 父服务的一些信息
				svr_name = svrInfo.service,
			}
		end
	end
end
-- PRINT("SERVER_SON_NAMED_MAP: ", SERVER_SON_NAMED_MAP)
