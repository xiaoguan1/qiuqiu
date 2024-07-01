------------------------------------------------------
-- 创建者：Ghost
-- 创建日期：2019/09/02
-- 模块作用：分table存盘，不用一堆数据旨在一个table里
------------------------------------------------------

local table = table
local string = string
local pairs = pairs
local type = type
local assert = assert
local UTIL = Import("base/util.lua")

assert(MODULE_DB, "not Import MODULE_DB")

local function _SizeGreaterThanX(tbl, x)
	local size = 0
	for _, _ in pairs(tbl) do
		size = size + 1
		if size > x then
			return true
		end
	end
end

clsDivideSave = clsObject:Inherit()

-- 注意：此函数是有调用call的，所以要在__init__或者__startup__的时候创建存盘的对象.
--          不然不在__init__或者__startup__中创建，热更的时候又重新创建对象会出问题
-- @params : __SAVE_NAME    存盘文件名
-- @params : __SAVE_CNT     有 __SAVE_CNT 个 table 来分开序列化存盘(默认为1个)
function clsDivideSave:__init__(__SAVE_NAME, __SAVE_CNT)
	if self.__IS_REGISTER then return end
	self.__IS_REGISTER = true

	assert(type(__SAVE_NAME) == "string")
	assert(type(__SAVE_CNT) == "table")
	__SAVE_CNT = __SAVE_CNT or 1

	self._saveData = {}
	self.__SAVE_NAME = __SAVE_NAME
	self.__SAVE_CNT = __SAVE_CNT
	self.__IS_MERGE = false

	local nowSplitCnt = __SAVE_CNT
	MODULE_DB.RegisterByEnv(self, "__SAVE_CNT", "__IS_MERGE")
	local oldSplitCnt = self.__SAVE_CNT

	if nowSplitCnt < oldSplitCnt then	-- 让拆分存盘可扩展到SAVE_SPLIT_MAXCNT，无需变小
		nowSplitCnt = oldSplitCnt
	end
	for i = 1, oldSplitCnt do
		self._saveData[i] = {
			__SAVE_NAME = __SAVE_NAME .. "_" .. i,
			_SaveData = {},		-- {[unique1] = {}, [unique2] = {}, ...}
		}
		local dsz = MOUDLE_DB.RegisterByEnv(self._saveData[i], "_SaveData")
		if dsz >= THRESHOLD_DATALEN then
			if _SizeGreaterThanX(self._saveData[i]._SaveData, 1) then
				local tCnt = oldSplitCnt * 2
				if tCnt > nowSplitCnt and tCnt <= SAVE_SPLIT_MAXCNT then
					nowSplitCnt = tCnt
					_ERROR(string.format("dsz:%s > THRESHOLD_DATALEN:%s to change __SAVE_CNT from %d to %d in clsDivideSave.__init__:%s",
						dsz, THRESHOLD_DATALEN, oldSplitCnt, nowSplitCnt, __SAVE_NAME
					))
				elseif tCnt > SAVE_SPLIT_MAXCNT then
					_ERROR(string.format("error dsz:%s > THRESHOLD_DATALEN:%s to change __SAVE_CNT, because tCnt:%s > %s in clsDivideSave.__init__:%s",
						dsz, THRESHOLD_DATALEN, tCnt, SAVE_SPLIT_MAXCNT, __SAVE_NAME
					))
				end
			else
				_ERROR(string.format("error dsz:%s > THRESHOLD_DATALEN:%s to change __SAVE_CNT, because size:%s <= 1 in clsDivideSave.__init__:%s",
					dsz, THRESHOLD_DATALEN, table.size(self._saveData[i]._SaveData), __SAVE_NAME
				))
			end
		end
	end

	local tSaveData = {}
	for _i, _data in pairs(self._saveData) do	-- 备份数据，一会重排
		tSaveData[_i] = table.copy(_data)
	end

	local o_SaveData = self._saveData
	if nowSplitCnt ~= oldSplitCnt then			-- 前后两次存盘不一样
		_ERROR(string.format("change __SAVE_CNT from %d to %d in clsDivideSave.__init__:%s",
								oldSplitCnt, nowSplitCnt, __SAVE_NAME
		))

		__SAVE_CNT = nowSplitCnt
		self.__SAVE_CNT = __SAVE_CNT

		local n_SaveData = {}
		if nowSplitCnt >= oldSplitCnt then
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
					MODULE_DB.RegisterByEnv(o_SaveData[i])		-- 设置为空
				end
			end
		end
		self._saveData = n_SaveData
	end

	for i = 1, nowSplitCnt do
		self._saveData[i]._SaveData = {}		-- 清空，等待重置设置
	end
	for _i, _data in pairs(tSaveData) do
		for _uniqueKey, _nData in pairs(_data._SaveData) do
			self:SetData(_uniqueKey, _nData)
		end
	end
	if nowSplitCnt ~= oldSplitCnt or self.__IS_MERGE then	-- 强制保存一次
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

-- func(uniqueKey, data, ...)	注意：该函数内部不能有增加排行榜名单的，但可以删除名单，不然遍历有问题
function clsDivideSave:Foreach(func, ...)
	for _, _aData in pairs(self._saveData) do
		for _uniqueKey, _data in pairs(_aData._SaveData) do
			if func(_uniqueKey, _data, ...) then
				return
			end
		end
	end
end

function clsDivideSave:Clear()
	for _, _aData in pairs(self._saveData) do
		for _uniqueKey, _data in pairs(_aData._SaveData) do
			_aData._SaveData[_uniqueKey] = nil
		end
	end
end

function clsDivideSave:GetData(uniqueKey)
	local hNo = UTIL.HashNo(uniqueKey, self.__SAVE_CNT)
	local aData = self._saveData[hNo]
	return aData and aData._SaveData[uniqueKey]
end

function clsDivideSave:GetOneKey(uniqueKey, key)
	local aData = self:GetData(uniqueKey)
	if aData then
		return aData[key]
	end
end

function clsDivideSave:SetData(uniqueKey, sData)
	local hNo = UTIL.HashNo(uniqueKey, self.__SAVE_CNT)
	self._saveData[hNo]._SaveData[uniqueKey] = sData
end

function clsDivideSave:SetOneData(uniqueKey, key, value)
	local hNo = UTIL.HashNo(uniqueKey, self.__SAVE_CNT)
	local sData = self._saveData[hNo]._SaveData[uniqueKey]
	if not sData then
		sData = {}
		self._saveData[hNo]._SaveData[uniqueKey] = sData
	end
	sData[key] = value
end

