local tsize = table.size
local tinsert = table.insert

local PLAYER_NUM = 100		-- 玩家数量
local MAX_COUNT = 5			-- 一个区域内最多包含多少个玩家

-- 四象限区域
local LX, LY, RX, RY = -200, -200, 200, 200
local COORDINATE = { LX = LX, LY = LY, RX = RX, RY = RY }

-- 深度
local DEPTH = 8

local ClsTree = {desc = "quad_tree"}

local function _CheckCoordinate(Coordinate)
	if not Coordinate then return COORDINATE end
	for key, _ in pairs(Coordinate) do
		if not COORDINATE[key] then
			error("init quad_tree fail")
		end
	end
	return Coordinate
end

function ClsTree:New(T)
	self.coordinate = _CheckCoordinate(T.coordinate)
	self.depth = T.depth or DEPTH

	-- 数据域
	self.players = {}

	-- 关系域
	self.children = {}
end

function ClsTree:Split()
	local size = tsize(self.players)
	if size < MAX_COUNT then return end

	-- 均分法
	local sum_X, sum_Y = 0, 0
	for playerid, NodeInfo in pairs(self.players) do
		sum_X = sum_X + (NodeInfo.X - LX)
		sum_Y = sum_Y + (NodeInfo.Y - LY)
	end
	sum_X = sum_X / size
	sum_Y = sum_Y / size

	-- 创建孩子节点
	{coordinate = {LX = LX, LY = LY, }}
	local children1 = ClsTree:New({coordinate = {}})
	local children2 = ClsTree:New()
	local children3 = ClsTree:New()
	local children4 = ClsTree:New()
	tinsert(self.children, )
end

function ClsTree:Insert(NodeInfo)
	if not (NodeInfo and NodeInfo.playerid and NodeInfo.X and NodeInfo.Y) then
		return
	end

	if #(self.children) == 0 then
		if tsize(self.players) + 1 <= MAX_COUNT then
			self.players[NodeInfo.playerid] = NodeInfo
		else
			-- 划分区域

		end
	else


	end
	return true
end

