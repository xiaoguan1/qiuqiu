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

local function _ExchangeLogData(data)
	local exData = {}
	local logIndexsData = {}
	local logPartitionData = {}
	for _tableName, rowdata in pairs(data) do
		if rowdata.Indexs and not table.empty(rowdata.Indexs) then
			if not logIndexsData[_tableName] then
				logIndexsData[_tableName] = rowdata.Indexs
			end
		end
		if rowdata.IsPartition == 1 then
			logPartitionData[_tableName] = true
		end
		if not exData[_tableName] then
			exData[_tableName] = {}
		end
		exData[_tableName]["hostid"] = {
			FieldType = "int(11)",
			FieldDes = "服务器编号",
		}
		local fieldData = rowdata.Field
		for _fieldName, _data in pairs(fieldData) do
			if not MYSQL_FIELDTYPE_MAP[_data.FieldType] then
				error(string.format("FieldType:%s must be %s", _data.FieldType, sys.dumptree(MYSQL_FIELDTYPE_MAP)))
			end
			exData[_tableName][_fieldName] = {
				FieldType = _data.FieldType,
				FieldDes = _data.FieldDesc or "",
			}
		end
		if rowdata.isRoleInfo == 1 then
			exData[_tableName]["acct"] = {
				FieldType = "varchar(64)",
				FieldDes = "后台账号",
			}
			exData[_tableName]["urs"] = {
				FieldType = "varchar(64)",
				FieldDes = "账号urs",
			}
			exData[_tableName]["uid"] = {
				FieldType = "varchar(32)",
				FieldDes = "角色唯一id",
			}
			exData[_tableName]["name"] = {
				FieldType = "varchar(64)",
				FieldDes = "角色名字",
			}
			exData[_tableName]["grade"] = {
				FieldType = "int(11)",
				FieldDes = "角色等级",
			}
			exData[_tableName]["serverid"] = {
				FieldType = "int(11)",
				FieldDes = "角色区服",
			}
		end
	end
	local sortData = {}
	for _tableName, _data in pairs(exData) do
		local tData = {}
		sortData[_tableName] = tData
		for _fieldName, _fData in pairs(_data) do
			table.insert(tData, _fieldName)
		end
		table.sort(tData)
	end
	sharedata.update("SortLogData", sortData)
	sharedata.update("LogIndexsData", logIndexsData)
	sharedata.update("LogPartitionData", logPartitionData)
	return exData
end

-- 二次处理配置表
local EXCHANGE_SETTING = {
	RobotData           = _ExchangeRobotData,
	LogData				= _ExchangeLogData
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