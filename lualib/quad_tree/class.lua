local tsize = table.size
local tinsert = table.insert

local PLAYER_NUM = 100		-- 玩家数量
local MAX_COUNT = 5			-- 一个区域内最多包含多少个玩家

-- 四象限区域
local LX, LY, RX, RY = -200, -200, 200, 200
local COORDINATE = { LX = LX, LY = LY, RX = RX, RY = RY }

-- 深度
local DEPTH = 8

ClsTree = {desc = "quad_tree"}

-- 检查四象限区域
local function _CheckCoordinate(Coordinate)
	if not Coordinate then return COORDINATE end
	for key, _ in pairs(Coordinate) do
		if not COORDINATE[key] then
			error("init quad_tree fail")
		end
	end
	return Coordinate
end

-- 划分区域
function Split(Tree)
	local size = tsize(Tree.players)
	if size < MAX_COUNT then return end

	-- 均分法
	local sum_X, sum_Y = 0, 0
	for playerid, NodeInfo in pairs(Tree.players) do
		sum_X = sum_X + (NodeInfo.X - LX)
		sum_Y = sum_Y + (NodeInfo.Y - LY)
	end
	sum_X = sum_X / size
	sum_Y = sum_Y / size

	-- 创建孩子节点
	-- 第一象限
	tinsert(Tree.children, Tree:New({
		coordinate = {LX = LX + sum_X, LY = LY + sum_Y, RX = RX, RY = RY}
	}))

	-- 第二象限
	tinsert(Tree.children, Tree:New({
		coordinate = {LX = LX, LY = LY + sum_Y, RX = LX + sum_X, RY = RY}
	}))

	-- 第三象限
	tinsert(Tree.children, Tree:New({
		coordinate = {LX = LX, LY = LY, RX = LX + sum_X, RY = RY + sum_Y}
	}))

	-- 第四象限
	tinsert(Tree.children, Tree:New({
		coordinate = {LX = LX + sum_X, LY = LY, RX = RX, RY = LY + sum_Y}
	}))
end

local function GetIndex(Tree, NodeInfo)
	local X = NodeInfo.X
	local Y = NodeInfo.Y
	if not (X and Y and #(Tree.children) ~= 0) then return end

	-- quadrant 即象限也是index
	for quadrant, child in pairs(Tree.children) do
		local coordinate = child.coordinate
		if coordinate.LX <= X and coordinate.LY <= Y and coordinate.RX > X and coordinate.RY > Y then
			return quadrant
		end
	end
end

-- 插入
local function Insert(Tree, NodeInfo)
	if not (NodeInfo and NodeInfo.playerid and NodeInfo.X and NodeInfo.Y) then
		return
	end

	if #(Tree.children) == 0 then
		if tsize(Tree.players) + 1 <= MAX_COUNT then
			Tree.players[NodeInfo.playerid] = NodeInfo
		else
			Split(Tree)
			for playerid, NodeInfo in pairs(Tree.players) do
				local index = GetIndex(Tree, NodeInfo)
				local child = Tree.children[index]
				child.players[playerid] = NodeInfo
			end
			Tree.players = {}	-- 清空
			Insert(Tree, NodeInfo)
		end
	else
		-- 找出对应的象限【找出对应的孩子节点】
		local index = GetIndex(Tree, NodeInfo)
		if Tree.children[index] then
			Insert(Tree.children[index], NodeInfo)
		end
	end

	return true
end

-- 查询
local function Find()
end

function ClsTree:New(Args)
	self.coordinate = _CheckCoordinate(Args.coordinate)
	self.depth = Args.depth or DEPTH

	-- 数据域
	self.players = {}

	-- 关系域
	self.children = {}
end
