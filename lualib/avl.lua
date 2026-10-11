--------------------------------------
-- 创建时间：2024/07/10
-- 创建者：guanguowei
-- 模块：大小堆二叉树（应用场景：不需要很准确的排序，只是需要最大值或者最小值即可）
--------------------------------------
local table = table
local tinsert = table.insert
local error = error
local assert = assert
local pairs = pairs
local ipairs = ipairs
local string = string
local sformat = string.format
local FIRSTKEY_BIRTH = "fkey_birth"

heapTreeClass = clsObject:Inherit()

-- sortWay:排序方式（true：最大堆、false：最小堆）
function heapTreeClass:__init__(uniqueKey, rankKeyList, sortWay)
	assert(type(uniqueKey) == "string")
	assert(type(rankKeyList) == "table" and #rankKeyList >= 1)
	assert(not sortWay or type(sortWay) == "boolean")

	sortWay = sortWay or false -- 默认最小堆

	self._uniqueKey = uniqueKey
	self._rankKeyList = table.copy(rankKeyList)
	self._sortWay = sortWay

	local function _CompDataFunc(elem1, elem2)
		for _k, _key in ipairs(self._rankKeyList) do
			if elem1.data[_key] > elem2.data[_key] then
				if self._sortWay then
					return true			--最大堆
				else
					return false		--最小堆
				end
			else
				if self._sortWay then
					return false		--最大堆
				else
					return true			--最小堆
				end
			end
		end
	end

	self._compDataFunc = _CompDataFunc
	self.root = nil
end

function heapTreeClass:IsUniqueKeyRepeat(uniqueKey)
	return self.uniqueKeyList and self.uniqueKeyList[uniqueKey]
end
function heapTreeClass:InsertUniqueKey(uniqueKey)
	if not self.uniqueKeyList then
		self.uniqueKeyList = {}
	end
	self.uniqueKeyList[uniqueKey] = true
end

-- insert接口只能新增
function heapTreeClass:Insert(element)
	assert(type(element) == "table")
	local uniqueKey = element[self._uniqueKey]
	assert(uniqueKey, "not include uniqueKey")

	if self:IsRepeat(uniqueKey) then
		error("double insert uniqueKey:" .. uniqueKey)
	end

	-- 检查排序的key是否齐全
	for i = 1, #self._rankKeyList do
		local key = self._rankKeyList[i]
		if not element[key] then
			error(sformat("rand key:%s must has value", key))
		end
	end

	if self.root then
		local node = self.root
		while node do
			if self._compDataFunc(node, element) then
				node = node.right
			else
				node = node.left
			end
		end



		self._compDataFunc(node, element)
	else
		-- 创建根节点
		self.root = {
			data = element,
			right = nil,
			left = nil,
			hight = 1,
		}
		self:InsertUniqueKey(uniqueKey)
	end


end