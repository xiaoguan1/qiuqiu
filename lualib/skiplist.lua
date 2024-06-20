-- gaoshi chen

local pairs = pairs
local ipairs = ipairs
local table = table
local tonumber = tonumber
local tostring = tostring
local assert = assert
local type = type
local math = math
local mrandom = math.random

local RANDOM_MAX = 10000
local SKIPLIST_P = 2500
local SKIPLIST_MAXLEVEL = 32

local function _SLRandomLevel()
	local level = 1
	while level < SKIPLIST_MAXLEVEL and mrandom(RANDOM_MAX) < SKIPLIST_P do
		level = level + 1
	end
	return level
end

local function _SLCreateNode(level, nData)
	local slNode = {
		nData = nData,			-- 节点数据
		backwardNode = nil,		-- 前驱节点
		-- {
		-- 	[level] = {
		-- 		forwardNode = ,	-- 该层后继节点
		-- 		span = ,		-- 该层跨越的节点数量
		-- 	}
		-- }
		lvData = {},
	}
	for i = 1, level do
		slNode.lvData[i] = {}
	end
	return slNode
end

local function _SLDeleteNode(slData, x, update)
	for i = 1, slData.level do
		if update[i].lvData[i].forwardNode == x then	-- update[i]->level[i]的后继等于要删除节点
			update[i].lvData[i].span = update[i].lvData[i].span + x.lvData[i].span - 1
			update[i].lvData[i].forwardNode = x.lvData[i].forwardNode
		else
			update[i].lvData[i].span = update[i].lvData[i].span - 1
		end
	end
	if x.lvData[1].forwardNode then
		x.lvData[1].forwardNode.backwardNode = x.backwardNode
	else
		slData.tailNode = x.backwardNode
	end

	-- 收缩level
	while slData.level > 1 and (not slData.headerNode.lvData[slData.level].forwardNode) do
		slData.level = slData.level - 1
	end
	-- 节点个数减1
	slData.length = slData.length - 1
end

local M = {}
-- compDataFunc(elem1, elem2)
-- sameDataFunc两个数据是一样的，一般nData里面的uid对比
function M.Create(compDataFunc, sameDataFunc)
	assert(type(compDataFunc) == "function")
	assert(type(sameDataFunc) == "function")
	local slData = {
		level = 1,
		length = 1,
		headerNode = nil,
		tailNode = nil,
		compDataFunc = compDataFunc,
		sameDataFunc = sameDataFunc,
	}

	slData.headerNode = _SLCreateNode(SKIPLIST_MAXLEVEL, nil)
	for i = 1, SKIPLIST_MAXLEVEL do
		slData.headerNode.lvData[i].forwardNode = nil
		slData.headerNode.lvData[i].span = 0
	end

	return slData
end

-- nData里面有一个主键，判断是否在slData中唯一，不唯一则无法排序
function M.Insert(slData, nData)
	local update = {}
	local x = nil
	local rank = {}
	local ro = 0

	x = slData.headerNode
	for i = slData.level, 1, -1 do
		-- rank[i]用来记录第i层达到插入位置的所跨越的节点总数，也就是该层最接近(小于)给定的排名
		-- rank[i]初始化为上一层所跨越的节点总数
		rank[i] = i == slData.level and 0 or rank[i + 1]

		-- 后继节点不为空，并且后继节点的compDataFunc < 0
		while (x.lvData[i].forwardNode and
				slData.compDataFunc(x.lvData[i].forwardNode.nData, nData) < 0) do
			rank[i] = rank[i] + x.lvData[i].span	-- 记录跨越了多少个节点
			ro = ro + x.lvData[i].span
			x = x.lvData[i].forwardNode		-- 继续向右走
		end
		update[i] = x	-- 保存访问的节点，并且将当前x移动到下一层
	end

	local level = _SLRandomLevel()	-- 随机获取新的level
	if level > slData.level then	-- 比当前整个跳表层级大，新的level需要进行升级
		for i = slData.level + 1, level do
			rank[i] = 0
			update[i] = slData.headerNode
			update[i].lvData[i].span = slData.length	-- 在未添加新节点之前，需要更新的节点跨越的节点数目自然就是zsl->length
		end
		slData.level = level
	end

	x = _SLCreateNode(level, nData)	-- 建立新节点

	-- 开始插入节点
	for i = 1, level do
		-- 新节点的后继就是插入位置节点的后继
		x.lvData[i].forwardNode = update[i].lvData.forwardNode
		-- 插入位置节点的后继就是新节点
		update[i].lvData[i].forwardNode = x

		x.lvData[i].span = update[i].lvData[i].span - (rank[1] - rank[i])
		update[i].lvData[i].span = (rank[1] - rank[i]) + 1
	end

	-- 如果新节点的level小于原来skiplist的level，那么在上层没有insert新节点的span需要加1
	for i = level + 1, slData.level do
		update[i].lvData[i].span = update[i].lvData[i].span + 1
	end

	-- 前驱指针，1层的
	if update[1] == slData.headerNode then
		x.backwardNode = nil
	else
		x.backwardNode = update[1]
	end

	if x.lvData[1].forwardNode then
		x.lvData[1].forwardNode.backwardNode = x
	else
		slData.tailNode = x
	end
	slData.length = slData.length + 1
	return x, ro + 1
end

-- 根据nData来删除节点
function M.Delete(slData, nData)
	local update = {}
	local x = nil

	x = slData.headerNode
	for i = slData.level, 1, -1 do
		while (x.lvData[i].forwardNode and
				slData.compDataFunc(x.lvData[i].forwardNode.nData, nData) < 0) do
			x = x.lvData[i].forwardNode			
		end
		update[i] = x
	end

	x = x.lvData[1].forwardNode
	-- 因为多个不同的member可能有相同的compDataFunc
	-- 所以要确保x的member和sameDataFunc都匹配时，才进行删除
	if x and x.nData and slData.sameDataFunc(x.nData, nData) then
		_SLDeleteNode(slData, x, update)
		return x.nData
	end
	return nil
end

-- 得到nData在skiplist中的排名，如果元素不在skiplist中，返回0
function M.GetRank(slData, nData)
	local x = nil
	local rank = 0

	x = slData.headerNode
	for i = slData.level, 1, -1 do
		while (x.lvData[i].forwardNode and
				slData.compDataFunc(x.lvData[i].forwardNode.nData, nData) <= 0) do
			rank = rank + x.lvData[i].span
			x = x.lvData[i].forwardNode
		end
		if x.nData and slData.sameDataFunc(x.nData, nData) then
			return rank
		end
	end
	return 0
end

-- 根据给定的rank查找元素
function M.GetElementByRank(slData, rank)
	local x = nil
	local traversed = 0

	x = slData.headerNode
	for i = slData.level, 1, -1 do
		while x.lvData[i].forwardNode and traversed + x.lvData[i].span <= rank do
			traversed = traversed + x.lvData[i].span
			x = x.lvData[i].forwardNode
		end
		if traversed == rank then
			return x.nData
		end
	end
	return nil
end

-- 轮询dealFunc(rank, value)
function M.PollingValueList(slData, rank, length, key, dealFunc)
	local x = nil
	local traversed = 0
	local rNode = nil

	x = slData.headerNode
	for i = slData.level, 1, -1 do
		while x.lvData[i].forwardNode and traversed + x.lvData[i].span <= rank do
			traversed = traversed + x.lvData[i].span
			x = x.lvData[i].forwardNode
		end
		if traversed == rank then
			rNode = x
			break
		end
	end
	if rNode then
		for i = 1, length do
			if rNode.nData then
				dealFunc(rank + i - 1, rNode.nData[key])
				if rNode.lvData[1].forwardNode then
					rNode = rNode.lvData[1].forwardNode
				else
					break
				end
			else
				break
			end
		end
	end
end

--根据给定的rank，length查找元素列表
function M.GetElementList(slData, rank, length, dealFunc)
	local x = nil
	local traversed = 0
	local rNode = nil

	x = slData.headerNode
	for i = slData.level, 1, -1 do
		while x.lvData[i].forwardNode and traversed + x.lvData[i].span <= rank do
			traversed = traversed + x.lvData[i].span
			x = x.lvData[i].forwardNode
		end
		if traversed == rank then
			rNode = x
			break
		end
	end
	if rNode then
		local list = {}
		for i = 1, length do
			if rNode.nData then
				if dealFunc then
					table.insert(list, dealFunc(rNode.nData))
				else
					table.insert(list, rNode.nData)
				end
				if rNode.lvData[1].forwardNode then
					rNode = rNode.lvData[1].forwardNode
				else
					break
				end
			else
				break
			end
		end
		return list
	end
end

-- 根据给定的rank查找元素
function M.GetNodeByRank(slData, rank)
	local x = nil
	local traversed = 0

	x = slData.headerNode
	for i = slData.level, 1, -1 do
		while x.lvData[i].forwardNode and traversed + x.lvData[i].span <= rank do
			traversed = traversed + x.lvData[i].span
			x = x.lvData[i].forwardNode
		end
		if traversed == rank then
			return x
		end
	end
	return nil
end

-- 获取当前节点数
function M.GetLength(slData)
	return slData.length
end

return M