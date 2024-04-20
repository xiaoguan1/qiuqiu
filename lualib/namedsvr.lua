local error = error
local string = string
local sys = sys

-- 任何节点都必须启动的服务
EVERY_NODE_SERVER = {
	database = ".database",	-- 数据库服务(优先！因为要提前设置服务器环境配置)
	stimer = ".stimer",		-- 定时器服务
    loadxls = ".loadxls",   -- 公共配置表服务
}

-- 节点启动详情
NODE_SERVER_INFO = {
	-- 节点管理
	nodemgr	= {named = ".NODEMGR", node = {"game_node", "cross_node"}},

	-- 网关
	gateway	= {named = ".GAMEWAY", node = "game_node", num = 5},

	-- 场景服务
	scene 	= {named = ".SCENE", node = "game_node"},

	-- 运营管理
	admin	= {named = ".ADMIN", node = "game_node",}
}

for svrName, nodeInfo in pairs(NODE_SERVER_INFO) do
	local condition1 = type(nodeInfo.named) == "string" and #nodeInfo.named > 0
	local condition2 = type(nodeInfo.node) == "table" or type(nodeInfo.node) == "string"
	local condition3 = (not nodeInfo.num) or (type(nodeInfo.num) == "number" and nodeInfo.num > 0)

	if not (condition1 and condition2 and condition3) then
		error(string.format("namedsvr service config error! condition1:%s condition2:%s condition3:%s  svrname:%s  nodedata:%s",
			condition1, condition2, condition3, svrName, sys.dump(nodeInfo)))
	end

	if not nodeInfo.num then
		nodeInfo.num = 1	-- 默认服务的数量为1
	end
end

-- 记录服务的num和named的关系
SERVER_NAMED_TO_NUM = {}
SERVER_NUM_TO_NAMED = {}
for svrName, nodeInfo in pairs(NODE_SERVER_INFO) do
	if nodeInfo.num > 1 then
		for i = 1, nodeInfo.num do
			local named = nodeInfo.named .. "_" .. i
			SERVER_NAMED_TO_NUM[named] = i

			if not SERVER_NUM_TO_NAMED[svrName] then
				SERVER_NUM_TO_NAMED[svrName] = {}
			end
			SERVER_NUM_TO_NAMED[svrName][i] = named
		end
	else
		SERVER_NAMED_TO_NUM[nodeInfo.named] = nodeInfo.num
		if not SERVER_NUM_TO_NAMED[svrName] then
			SERVER_NUM_TO_NAMED[svrName] = {}
		end
		SERVER_NUM_TO_NAMED[svrName][nodeInfo.num] = nodeInfo.named
	end
end
-- PRINT("SERVER_NAMED_TO_NUM: ", SERVER_NAMED_TO_NUM)
-- PRINT("SERVER_NUM_TO_NAMED: ", SERVER_NUM_TO_NAMED)
