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
