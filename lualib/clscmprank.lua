local skynet = require "skynet"
local table = table
local tinsert = table.insert
local thas_value = table.has_value
local string = string
local os = os
local pairs = pairs
local ipairs = ipairs
local type = type
local assert = assert
local error = error
local math = math
local Super = Super
local SKIPLIST = require "skiplist"
local FIRSTKEY_BIRTH = "fkey_birth"
local UTIL = Import("base/util.lua")

assert(MODULE_DB, "not import MODULE_DB")

local function _SizeGreaterThanX(tbl, x)
	local size = 0
	for _, _ in pairs(tbl) do
		size = size + 1
		if size > x then
			return true
		end
	end
end

local function _NowUSecond()
	return skynet.time()
end

local function _GetSaveData(rankObj, unique)
	if rankObj.__SAVE_NAME then
		local hNo = UTIL.HashNo(unique, rankObj.__SAVE_NAME)
		return rankObj._saveData[hNo] and rankObj._saveData[hNo]._SaveData[unique]
	else
		return rankObj._saveData[unique]
	end
end

local function _GetKickSaveData(rankObj)
	return rankObj._KICK_DATA
end

local function _SetKickSaveData(rankObj, _kData)
	rankObj._KICK_DATA = _kData
end

local function _KickRole(rankObj, unique)
	local _kData = _GetKickSaveData(rankObj)
	if _kData[unique] then
		return true
	end
end

local function _SetSaveData(rankObj, unique, nData)
	if rankObj.__SAVE_NAME then
		local hNo = UTIL.HashNo(unique, rankObj.__SAVE_NAME)
		rankObj._saveData[hNo]._SaveData[unique] = nData
	else
		rankObj._saveData[unique] = nData
	end
end

local function _ClearSaveData(rankObj, unique)
	if rankObj.__SAVE_NAME then
		local hNo = UTIL.HashNo(unique, rankObj.__SAVE_NAME)
		rankObj._saveData[hNo]._SaveData[unique] = nil
	else
		rankObj._saveData[unique] = nil
	end
end

function GetBirthdayKey()
	return FIRSTKEY_BIRTH
end

clsCmpRank = clsObject:Inherit()
-- @params : uniqueKey			数据的唯一标识
-- @params : rankKeyList		排序的key(严格按照顺序来进行), 例如{"score", "grade"}，优化score，再到grade
--									还有额外的，主排序键修改时间，最后是uniqueKey(因为尽量防止唯一，加上uniqueKey就确保不会有问题了)
--									排序的字段不能有table，索然table可以用元表只做< >的操作
-- @params : rankCmp			排序用的自定义cmp
-- @params : maxNum				排序队列最大长度
function clsCmpRank:__init__(uniqueKey, rankKeyList, rankCmp, maxNum)
	assert(type(uniqueKey) == "string")
	assert(type(rankKeyList) == "table")
	assert(type(rankCmp) == "function")
	Super(clsCmpRank).__init__(self)

	self._uniqueKey = uniqueKey
	self._rankKeyList = table.copy(rankKeyList)
	self.rankCmpFunc = rankCmp
	self.maxNum = maxNum
	tinsert(self._rankKeyList, "fkey_birth")
	tinsert(self._rankKeyList, uniqueKey)

	local function _CompDataFunc(elem1, elem2)
		for _k, _key in pairs(self._rankKeyList) do
			if _key == FIRSTKEY_BIRTH or _key == uniqueKey then
				-- 表示符升序
				if elem1[_key] > elem2[_key] then
					return 1
				elseif elem1[_key] < elem2[_key] then
					return -1
				end
			else
				local ret = self.rankCmpFunc(elem1, elem2)
				if ret then
					return ret
				end
			end
		end
		return 0
	end

	local function _SameDataFunc(elem1, elem2)
		-- 判断两个数据是否一样，需要根据uniqueKey来判断
		if elem1[uniqueKey] == elem2[uniqueKey] then
			return true
		end
	end

	self._slData = SKIPLIST.Create(_CompDataFunc, _SameDataFunc)

	-- _saveData字段一般外部不能获取，但是有一种情况特殊
	--		假设一个活动排名需要记录上一次的排行榜，新的也能看到。那么就需要2个排行榜
	-- 		因为活动排行榜不会太多人，那么旧的排行榜就可以获取_saveData来赋给活动模块的存档table来达到存档
	-- 		而新的排行榜不用保存，到了活动结束就删除旧的排行榜，然后用新的_saveData赋给活动模块的存档table
	self._saveData = {}
	self._KICK_DATA = {}
end

function clsCmpRank:GetMinRank()
	local len = self:GetLength()
	local list = SKIPLIST.GetElementList(self._slData, len, 1)
	return table.simple_readonly(list[1])
end

-- 注意：此函数是有调用call的，所以一般__init__或者__startup__的时候创建存盘的排行对象，并且立即调用Call_SaveRegister
-- @params : __SAVE_NAME	存盘文件名
-- @params : __SAVE_CNT		self._saveData 下有 __SAVE_CNT个table来分开序列化存盘
-- @params : initFunc		可选，初始化函数，在恢复数据重新插入的时候会优先调用initFunc，方便做数据兼容的initFunc(data)
function clsCmpRank:Call_SaveRegister(__SAVE_NAME, __SAVE_CNT, initFunc)
	-- 必须没有设置存盘值的
	assert(table.size(self._saveData) <= 0)
	assert(type(__SAVE_CNT) == "number")
	assert(assert(type(__SAVE_NAME) == "string"))
	if initFunc then
		assert(type(initFunc) == "function")
	end
	__SAVE_CNT = __SAVE_CNT or 1

	if self.__IS_REGISTER then
		return
	end
	self.__IS_REGISTER = true

	self.__SAVE_NAME = __SAVE_NAME
	self.__SAVE_CNT = __SAVE_CNT
	self.__IS_MERGE = false

	local nowSplitCnt = __SAVE_CNT
	MODULE_DB.RegisterByEnv(self, "__SAVE_CNT", "__IS_MERGE", "_KICK_DATA")
	local oldSplitCnt = self.__SAVE_CNT

	if nowSplitCnt < oldSplitCnt then
		-- 让拆分存盘可扩展到SAVE_SPLIT_MAXCNT, 无需变小
		nowSplitCnt = oldSplitCnt
	end
	for i = 1, oldSplitCnt do
		self._saveData[i] = {
			__SAVE_NAME = __SAVE_NAME .. "_" .. i,
			_SaveData = {},	-- {[unique] = {}, [unique2] = {}, ...}
		}
		local dsz = MODULE_DB.RegisterByEnv(self._saveData[i], "_SaveData")
		if dsz >= THRESHOLD_DATALEN then
			if _SizeGreaterThanX(self._saveData[i]._SaveData, 1) then
				local tCnt = oldSplitCnt * 2
				if tCnt > nowSplitCnt and tCnt <= SAVE_SPLIT_MAXCNT then
					nowSplitCnt = tCnt
					_ERROR(string.format("dsz:%s > THRESHOLD_DATALEN:%s to change __SAVE_CNT from %d to %d in clsCmpRank.Call_SaveRegister:%s",
						dsz, THRESHOLD_DATALEN, oldSplitCnt, nowSplitCnt, __SAVE_NAME
					))
				elseif tCnt > SAVE_SPLIT_MAXCNT then
					_ERROR(string.format("error dsz:%s > THRESHOLD_DATALEN:%s to change __SAVE_CNT, because tCnt:%s > %s in clsCmpRank.Call_SaveRegister:%s",
						dsz, THRESHOLD_DATALEN, tCnt, SAVE_SPLIT_MAXCNT, __SAVE_NAME
					))
				end
			else
				_ERROR(string.format("error dsz:%s > THRESHOLD_DATALEN:%s to change __SAVE_CNT, because size:%s <= 1 in clsCmpRank.Call_SaveRegister:%s",
					dsz, THRESHOLD_DATALEN, table.size(self._saveData[i]._SaveData), __SAVE_NAME
				))
			end
		end
	end

	local tSaveData = {}
	for _i, _data in pairs(self._saveData) do
		-- 备份数据，一会重排
		tSaveData[i] = table.copy(_data)
	end

	local o_SaveData = self._saveData
	if nowSplitCnt ~= oldSplitCnt then
		-- 前后两次存盘不一样
		_ERROR(string.format("change __SAVE_CNT from %d to %d in clsCmpRank.Call_SaveRegister:%s",
								oldSplitCnt, nowSplitCnt, __SAVE_NAME
		))

		__SAVE_CNT = nowSplitCnt
		self.__SAVE_CNT = __SAVE_CNT

		local n_SaveData = {}
		if nowSplitCnt > oldSplitCnt then
			for i = 1, nowSplitCnt do
				if o_SaveData[i] then
					n_SaveData[i] = o_SaveData[i]
					n_SaveData[i]._SaveData = {}
				else
					n_SaveData[i] = {
						__SAVE_NAME = __SAVE_NAME .. "_" .. i,
						_SaveData = {},
					}
				end
				MODULE_DB.RegisterByEnv(n_SaveData[i], "_SaveData")
			end
		else
			for i = 1, oldSplitCnt do
				if i <= nowSplitCnt then
					n_SaveData[i] = o_SaveData[i]
					n_SaveData[i]._SaveData = {}
					MODULE_DB.RegisterByEnv(n_SaveData[i], "_SaveData")
				else
					o_SaveData[i]._SaveData = {}
					MODULE_DB.RegisterByEnv(o_SaveData[i])	-- 设置为空
				end
			end
		end
		self._saveData = n_SaveData
	end

	for i = 1, nowSplitCnt do
		self._saveData[i]._SaveData = {}	-- 情况，等待重新排序
	end

	for _i, _data in pairs(tSaveData) do
		-- 重新排序
		for _uid, _nData in pairs(_data._SaveData) do
			if initFunc then
				initFunc(_nData)
			end
			self:Insert(_nData)
		end
	end
	if nowSplitCnt ~= oldSplitCnt or self.__IS_MERGE then
		-- 强制保存一次
		MODULE_DB.SaveOneModule(self, true)
		for i = 1, nowSplitCnt do
			MODULE_DB.SaveOneModule(self._saveData[i], true)
		end
		if oldSplitCnt > nowSplitCnt then
			for i = nowSplitCnt + 1, oldSplitCnt do
				MODULE_DB.SaveOneModule(o_SaveData[i], true)
			end
		end
		self.__IS_MERGE = false
	end
end

-- 是否存在于排行榜
-- @params : unique 	唯一表示
function clsCmpRank:HasUnique(unique)
	local nData = _GetSaveData(self, unique)
	if nData then
		return true
	end
end

-- 是否属性一直
-- @params : unique 	唯一表示
-- @params : key 		检验属性的key
-- @params : value 		检验属性的value
-- @return : 如果没有该唯一表示返回的nil，value不一致则返回false，一直则为true
function clsCmpRank:IsSameVarUnique(unique, key, value)
	local nData = _GetSaveData(self, unique)
	if not nData then
		return
	end
	if nData[key] == value then
		return true
	else
		return false
	end
end

-- 与排行榜中踢出某个玩家
function clsCmpRank:KickUnique(unique)
	self:Delete(unique)
	local _kData = _GetKickSaveData(self)
	if _kData[unique] then
		return
	end
	_kData[unique] = true
	_SetKickSaveData(self, _kData)
end

-- 根据唯一表示，获取某个字段的数据
-- @params : unique 唯一标识
-- @params : key	字段名
function clsCmpRank:GetDataVar(unique, key)
	local nData = _GetSaveData(self, unique)
	if not nData then
		return
	end
	return nData[key]	-- 这里不怕table被修改，如果这个key对应的是table，那么这个key就一定不是排序所需的数据
end

-- 根据唯一表示，获取只读数据
-- @params : unique 唯一标识
-- @return : readonlyData / nil		只读table，防止被修改了里面的值导致排行榜混乱
function clsCmpRank:GetReadonlyData(unique)
	local nData = _GetSaveData(self, unique)
	if not nData then
		return
	end
	return table.simple_readonly(nData)
end

-- 根据唯一表示获取当前排名
-- @return : rank / 0 	0表示没有排名
function clsCmpRank:GetRank(unique)
	local nData = _GetSaveData(self, unique)
	if not nData then
		return 0
	end
	return SKIPLIST.GetRank(self._slData, nData)
end

-- 根据排名获取只读数据
-- @params : rank 	排名
-- @return : readonlyData / nil  只读table，防止被修改了里面的值导致排行榜混乱
function clsCmpRank:GetReadonlyDataByRank(rank)
	if rank <= 0 then
		return
	end
	local nData = SKIPLIST.GetElementByRank(self._slData, rank)
	if nData then
		return table.simple_readonly(nData)
	end
end

function clsCmpRank:GetDataVarByRank(rank, key)
	if rank <= 0 then
		return
	end
	local nData = SKIPLIST.GetElementByRank(self._slData, rank)
	if nData then
		return nData[key]
	end
end

-- 获取某个排名范围的数据
-- @params : rank 	开始的排名
-- @params : length 获取的长度 [rank, rank + length)
-- @return : {[1] = readonlyData, [2] = readonlyData, ...} / nil
function clsCmpRank:GetReadonlyDataByRange(rank, length)
	assert(rank > 0 and length > 0)
	local list = SKIPLIST.GetElementList(self._slData, rank, length, table.simple_readonly)
	if list then
		if #list > 256 then	-- 每次获取大于256就打印下
			local _print = _WARN or skynet.error
			_print(string.format("clsCmpRank:GetReadonlyDataByRange rank:%s length:%s #list:%s", rank, length, #list, debug.traceback()))
		end
		return list
	end
end

-- 轮询数据
-- @params : func 	func(unique, readonlyData, ...), 注意：该函数内部不能有增加排行榜名单的，但可以删除名单，不然遍历有问题
-- 			 func 	return true 结束轮询
-- @params : ... 	func的额外参数
function clsCmpRank:Foreach(func, ...)
	if self.__SAVE_NAME then
		for _, _aData in pairs(self._saveData) do
			for _unique, _data in pairs(_aData._SaveData) do
				local readonlyData = table.simple_readonly(_data)
				if func(_unique, readonlyData, ...) then
					return
				end
			end
		end
	else
		for _unique, _data in pairs(self._saveData) do
			local readonlyData = table.simple_readonly(_data)
			if func(_unique, readonlyData, ...) then
				return
			end
		end
	end
end

-- 当前已经有的排序数量
function clsCmpRank:GetLength()
	return SKIPLIST.GetLength(self._slData)
end

-- 添加排名
-- @params : data 插入排序的数据，data只是临时的，后面修改data也是无用了，不影响排名
-- @return : rank 插入后的排名
-- @return : delData 删除的数据
function clsCmpRank:Insert(data)
	-- 判断是否有唯一表示
	local unique = data[self._uniqueKey]
	if not unique then
		error("not include uniqueKey")
	end
	if _KickRole(self, unique) then
		return
	end
	-- 判断是否重复Insert了
	if _GetSaveData(self, unique) then
		error("double insert unique:" .. unique)
	end
	local nData = table.deepcopy(data)
	if not nData[FIRSTKEY_BIRTH] then
		nData[FIRSTKEY_BIRTH] = _NowUSecond()
	end

	-- 判断是否有排序key
	for i = 1, #self._rankKeyList do
		local key = self._rankKeyList[i]
		if not nData[key] then
			error(string.format("rank key:%s must has value", key))
		end
	end

	local delOk, delData = nil, nil
	local len = self:GetLength()
	if len >= self.maxNum then
		local _rData = self:GetMinRank()
		local cmp_value = self.rankCmpFunc(data, _rData)
		if cmp_value == -1 then
			delOk, delData = self:Delete(_rData[self._uniqueKey])
		else
			return
		end
	end

	local _, rank = SKIPLIST.Insert(self._slData, nData)
	_SetSaveData(self, unique, nData)
	return rank, delData
end

-- 删除某个排名
-- @params : unique 唯一标识
-- @return : true / nil
function clsCmpRank:Delete(unique)
	local nData = _GetSaveData(self, unique)
	if not nData then
		return
	end
	local retData = SKIPLIST.Delete(self._slData, nData)
	if retData then
		_ClearSaveData(self, unique)	-- 删除保存记录
		return true, retData
	end
end

-- 清空排行榜
function clsCmpRank:ClearRank()
	if self.__SAVE_NAME then
		for _, _aData in pairs(self._saveData) do
			for _unique, _data in pairs(_aData._SaveData) do
				self:Delete(_unique)
			end
		end
	else
		for _unique, _data in pairs(self._saveData) do
			self:Delete(_unique)
		end
	end
	if self:GetLength() ~= 0 then
		_ERROR("clsRank:ClearRank but length ~= 0", debug.traceback())
	end
end

-- 修改某个数据
-- @params : unique 唯一表示
-- @params : data = {
-- 		key1 = value1,
-- 		key2 = value2,
-- 		...
-- }
-- @return : (true/nil), rank 第一个参数返回true表示修改成功，nil为失败。第二个参数如果是修改与排名有关的，则为修改后排名
function clsCmpRank:ModifyValue(unique, data)
	if _KickRole(self, unique) then
		return
	end
	local nData = _GetSaveData(self, unique)
	if not nData then
		error("not unique:" .. unique)
	end

	local needDelete = nil
	for key, value in pairs() do
		if key == self._uniqueKey or key == FIRSTKEY_BIRTH then
			error("can`t modify key:" .. key)
		end

		local isRankKet = thas_value(self._rankKeyList, key)
		if isRankKet then
			if nData[key] ~= value then
				needDelete = true
				break
			end
		end
	end

	if needDelete then
		local ok = self:Delete(unique)
		if not ok then
			return
		end
		for key, value in pairs(data) do
			nData[key] = value
		end

		nData[FIRSTKEY_BIRTH] = _NowUSecond()	-- 只要有key改变就修改时间
		local _, rank = SKIPLIST.Insert(self._slData, nData)
		_SetSaveData(self, unique, nData)		-- self:Delete删除了，这里补充一下
		return true, rank
	else
		for key, value in pairs(data) do
			nData[key] = value
		end
	end
	return true
end