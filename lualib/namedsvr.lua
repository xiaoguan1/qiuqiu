local error = error
local string = string
local sys = sys

-- 任何节点都必须启动的服务
EVERY_NODE_SERVER = {
	{service = "loadxls", named = ".LOADXLS"},		-- 公共配置表服务
	{service = "database", named = ".DATABASE"},	-- 数据库服务(优先！因为要提前设置服务器环境配置)
	{service = "stimer", named = ".STIMER"},		-- 定时器服务
}

-- 节点启动详情
-- @named 注册的服务名
-- @node 限制某些节点才能启动
-- @son_num 子服务的数量
NODE_SERVER_INFO = {
	-- 节点管理
	nodemgr	= {named = ".NODEMGR", node = {"game_node", "cross_node"}},

	-- 网关
	logind	= {named = ".LOGIND", node = "game_node", son_num = 5},

	-- 场景服务
	scene 	= {named = ".SCENE", node = "game_node"},

	-- 运营管理
	admin	= {named = ".ADMIN", node = "game_node",}
}


-- 检查 EVERY_NODE_SERVER 配置
for index, serverInfo in ipairs(EVERY_NODE_SERVER) do
	if not serverInfo.service or not serverInfo.named then
		error(string.format("EVERY_NODE_SERVER _index:%s service:%s named:%s config error",
			index, serverInfo.service, serverInfo.named))
	end
	EVERY_NODE_SERVER[serverInfo.service] = {index = index, named = serverInfo.named}
end

-- 检查 NODE_SERVER_INFO 配置
for svrName, svrInfo in pairs(NODE_SERVER_INFO) do
	local condition1 = type(svrInfo.named) == "string" and #svrInfo.named > 0
	local condition2 = type(svrInfo.node) == "table" or type(svrInfo.node) == "string"
	local condition3 = (not svrInfo.son_num) or (type(svrInfo.son_num) == "number" and svrInfo.son_num > 0)

	if not (condition1 and condition2 and condition3) then
		error(string.format("namedsvr service config error! condition1:%s condition2:%s condition3:%s  svrname:%s  nodedata:%s",
			condition1, condition2, condition3, svrName, sys.dump(svrInfo)))
	end
end

-- 记录服务的子服务的名称
SERVER_SON_NAMED_MAP = {}
for svrName, svrInfo in pairs(NODE_SERVER_INFO) do
	if svrInfo.son_num then
		for i = 1, svrInfo.son_num do
			local sonNamed = svrInfo.named .. "_SON_" .. i
			SERVER_SON_NAMED_MAP[sonNamed] = {
				idx = i,	-- 序号
				father_named = svrInfo.named,	-- 父服务的一些信息
				svr_name = svrName,
			}
		end
	end
end
-- PRINT("SERVER_SON_NAMED_MAP: ", SERVER_SON_NAMED_MAP)

function GetSonNamed(svrName, idx)
	local fatherInfo = NODE_SERVER_INFO[svrName]
	if not fatherInfo then
		return
	end

	local maxIdx = fatherInfo.son_num or 0
	if maxIdx < idx or idx <= 0 then
		return
	end

	return fatherInfo.named .. "_SON_" .. idx
end

