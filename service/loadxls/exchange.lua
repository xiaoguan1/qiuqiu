local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
local mysql = require "skynet.db.mysql"
local table = table
local debug = debug
local string = string

-- 示例
local function _ExchangeRobotData(data)
	local index = #data + 1
	data[index] = data[#data]
	return data
end

-- 二次处理配置表
local EXCHANGE_SETTING = {
	RobotData           = _ExchangeRobotData,
}

function GetExchangeSetting()
	return EXCHANGE_SETTING
end

-- {
-- 	[SettingKeyName] = funcString
-- }
local FUNC_INFO = {}

local function _GetCurrentFuncInfo()
	local f = io.open("service/loadxls/exchange.lua")
	assert(f)
	local fLines = {}
	for line in f:lines() do
		table.insert(fLines, line)
	end
	f:close()
	local aFuncInfo = {}
	for _settingKeyName, _func in pairs(EXCHANGE_SETTING) do
		local tmp = {}
		local d = debug.getinfo(_func, "S")
		for i = d.linedefined, d.lastlinedefined do
			table.insert(tmp, fLines[i])
		end
		aFuncInfo[_settingKeyName] = table.concat(tmp, "\n")
	end
	return aFuncInfo
end

function __init__()
	FUNC_INFO = _GetCurrentFuncInfo()
end

function __update__()
	local nFuncInfo = _GetCurrentFuncInfo()
	for _settingKeyName, _funcSource in pairs(FUNC_INFO) do
		local needUpdate = false
		if nFuncInfo[_settingKeyName] then
			if nFuncInfo[_settingKeyName] ~= _funcSource then
				needUpdate = true
			end
		else
			needUpdate = true
		end
		if needUpdate then
			skynet.error(string.format("xls exchange func:%s has changed", _settingKeyName))
			DATA_MGR.UpdateSettingByKeyName(_settingKeyName)
		end
	end
	FUNC_INFO = nFuncInfo
end