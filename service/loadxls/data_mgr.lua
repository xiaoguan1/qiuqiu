-- 注意：使用sharedata的时候只能在函数外部query，不然很容易忘记处理重入的问题，因为query里面内部是call

local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
local mysql = require "skynet.db.mysql"
local table = table
local assert = assert
local pairs = pairs
local pcall = pcall
local type = type
local string = string
local Import = Import
local cjson = require "cjson"

DB_OBJ = false
LOAD_FILEDATA = {}
EFUNC2FILE = {}

local check_setting_size = (skynet.getenv("check_setting_size") == "true") and true or false
local xls_setting_path = skynet.getenv("xls_setting") or "./setting"
local EXCHANGE_MOD = Import("service/loadxls/exchange.lua")
local CHECK_ALOAD = Import("service/loadxls/checkaload.lua")
local is_testserver = skynet.getenv("is_testserver") == "true" and true or false

local LOGDB_PROXY = nil
local LOGDB = skynet.getenv("logdb") == "true" and true or false
local logdb_infile = skynet.getenv("logdb_infile") == "true" and true or false
if LOGDB and logdb_infile then
	local PROXYSVR = Import("base/proxysvr")
	LOGDB_PROXY = PROXYSVR.GetProxyByServiceName("logdb")
end

local WARNING_LOADXLSFILE_MEM = 5	-- 加载配置报警内存界限 5m
local IGNORE_LOADXLSFILE = {
	["robot/robot_hero.lua"] = true,	-- 内存多 24m
}

local function _Dump_LoadXlsFileMemWarning(file, mem)
	local msgData = {
		"",
		"--------------------------------------------------------",
		"--------------------------------------------------------",
		"--------------------------------------------------------",
		"--------------------------------------------------------",
		"--------------------------------------------------------",
		"--------------------------------------------------------",
		"--------------------------------------------------------",
		"--------------------------------------------------------",
		"--------------------------------------------------------",
		"--------------------------------------------------------",
		string.format("load seeting file:%s mem:%s(m)", file, mem)
		"--------------------------------------------------------",
		"--------------------------------------------------------",
		"--------------------------------------------------------",
		"--------------------------------------------------------",
		"--------------------------------------------------------",
		"--------------------------------------------------------",
		"--------------------------------------------------------",
		"--------------------------------------------------------",
		"--------------------------------------------------------",
		"--------------------------------------------------------",
	}
	local msg = table.concat(msgData, "\n")
	skynet.error(msg)
end

local IGNORE_SETTING_CHECK = {
	["RobotHeroData"] = true,	-- 机器人属性
}


local SETTING_MAXSIZE = 9999
local function _CheckSettingSize(settingName, data)
	if not check_setting_size then return end
	if IGNORE_SETTING_CHECK[settingName] then return end	-- 非测试服不检验
	if table.size(data) > SETTING_MAXSIZE then
		error(string.format("_CheckSettingSize setting:%s size:%s > %s", settingName, table.size(data), SETTING_MAXSIZE))
	end
end

-- 加载数据
-- @param:filePath 文件路径
local function _LoadXlsData(filePath)
	if string.beginswith(filePath, "./") then
		filePath = string.sub(filePath, 3)
	end

	local f = io.open(filePath, 'rb')
	local fileStr
	if f then
		fileStr = f:read("*a")
		f:close()
	else
		error("read path error:" .. filePath)
	end
	local fileEnv = {}
	assert(load(fileStr, filePath, "bt", fileEnv))()

	local EXCHANGE_SETTING = EXCHANGE_MOD.GetExchangeSetting()
	for _name, _data in pairs(fileEnv) do
		if type(_data) == "table" then
			_data = EXCHANGE_SETTING[_name](_data)
		end
		assert(_data, "not data:" .. _name)
		EFUNC2FILE[_name] = filePath
		local ok, err = pcall(sharedata.new, _name, _data)
		if not ok then
			error(string.format("name:%s, file:%s load err:%s", _name, filePath, err))
		end
		_CheckSettingSize(_name, _data)
	end
	LOAD_FILEDATA[filePath] = true
end

-- 热更数据
-- @param:filePath 文件路径
local function _UpdateXlsData(filePath, notCheck)
	if string.beginswith(filePath, "./") then
		filePath = string.sub(filePath, 3)
	end

	local f = io.open(filePath, "rb")
	local fileStr
	if f then
		fileStr = f:read("*a")
		f:close()
	else
		error("read path error:" .. filePath)
	end
	local fileEnv = {}
	assert(load(fileStr, filePath, "bt", fileEnv))()

	local EXCHANGE_SETTING = EXCHANGE_MOD.GetExchangeSetting()
	for _name, _data in pairs(fileEnv) do
		if not notCheck and _name == "LogData" then
		else
			if type(_data) == "table" then
				if EXCHANGE_SETTING[_name] then
					_data = EXCHANGE_SETTING[_name](_data)
				end
				assert(_data, "not data:" .. _name)
				sharedata.update(_name, _data)
			end
		end
		EFUNC2FILE[_name] = filePath
	end
	LOAD_FILEDATA[filePath] = true
end

function UpdateSettingByKeyName(keyName)
	local filePath = EFUNC2FILE[keyName]
	if not filePath then return end

	skynet.error(string.format("update setting:%s by keyName:%s", filePath, keyName))
	_UpdateXlsData(filePath)
end

function LoadFile()
	-- 收到加载文件
	local settingfiles = Import("service/loadxls/loadsetting_cfg.lua").GetLoadSettingFiles()
	local memory = require "skynet.memory"
	local preMem = 0
	for _, _file in pairs(settingfiles) do
		if string.beginswith(_file, "./") then
			_file = string.sub(_file, 3)
		end
		local lfile = xls_setting_path .. "/" .. _file
		_LoadXlsData(lfile)

		if is_testserver then
			local info = memory.info()
			local mem = (info[9]/1024/1024) - preMem
			preMem = (info[9]/1024/1024)
			if mem >= WARNING_LOADXLSFILE_MEM and not IGNORE_LOADXLSFILE[_file] then
				_Dump_LoadXlsFileMemWarning(_file, mem)
			end
		end
	end
	if is_testserver then
		skynet.error(string.format("load setting use mem:%s(m)"), preMem)
	end

	-- 加载客户端技能展示技能
	local BATTLECLIENT_RESOURCE_BASE_DIR = "gservice/svrbattle/client/resource/assets/fight/skillJson"
	local cmd = string.format([[find %s -type f -name '*.json' | xargs stat -c \"%%n\",]], BATTLECLIENT_RESOURCE_BASE_DIR)
	local pipeF = io.popen(cmd)
	local dataStr = pipeF:read("*all")
	pipeF:close()
	local data = assert(load("return {" .. dataStr .. "}"))()
	local ClientSkillShowConf = {}
	for _, _file in pairs(data) do
		local fh = io.open(_file, "r")
		local jdata = fh:read("*a")
		fh:close()
		local ldata = cjson.decode(jdata)
		local fList = string.split(_file, "/")
		local cfgName = string.split(fList[#fList], ".")[1]
		ClientSkillShowConf[cfgName] = ldata
	end
	sharedata.update("ClientSkillShowConf", ClientSkillShowConf)
	local fh = io.open("gservice/svrbattle/client/resource/assets/config/dbSke.json", "r")
	local jdata = fh:read("*a")
	fh:close()
	local ldata = cjson.decode(jdata)
	sharedata.update("ClientDragonBoneSke", ldata)

	if LOGDB and logdb_infile then
		LOGDB_PROXY.send.loadxls_finish()
	end
	-- 更新玩数据检测一遍
	CHECK_ALOAD.CheckAfterLoad()
	-- 检测是否删除了主键
	-- CHECK_ALOAD.CheckRemovePrimaryKey()
	collectgarbage("collect")
end

function LoadDatabase()
	-- local DATABASE_CFG = assert(load("return " .. skynet.getenv("database_info"))())
	-- local function on_connect(db)
	-- 	db:query("set charset utf8")
	-- end
	-- DB_OBJ = mysql.connect({
	-- 	host = DATABASE_CFG.dbhost,
	-- 	post = DATABASE_CFG.post,
	-- 	database = DATABASE_CFG.dbname,
	-- 	user = DATABASE_CFG.dbuser,
	-- 	password = DATABASE_CFG.dbpasswd,
	-- 	max_pack_size = 1024 * 1024 * 2^9 - 1,	-- longtext
	-- 	on_connect = on_connect,
	-- })
	-- -- 询问query的时候如果断开还是会继续连接，知道连上
	-- if not DB_OBJ then
	-- 	error("connect mysql error!")
	-- end

	-- local sql = "select name from setting;"
	-- local settingNames = DB_OBJ:query(sql)
	-- assert(not settingNames["badresult"])

	-- for _, _nData in pairs(settingNames) do
	-- 	-- 优化思路 这里可以使用mysql的预处理 因为变量只有一个 _nData.name!!!
	-- 	local sql = string.format("select data from setting where name = '%s';", _nData.name)
	-- 	local settingData = DB_OBJ:query(sql)
	-- 	assert(not settingData["badresult"])
	-- 	assert(#settingData == 1 and settingData[1].data)
	-- 	local data = load("return " .. settingData[1].data)()
	-- 	sharedata.new(_nData.name, data)
	-- end
end

function CMD.UpdateSetting_Database(dataKey)
	local sql = string.format("select data from setting where name = '%s';", dataKey)
	local settingData = DB_OBJ:query(sql)
	assert(not settingData["badresult"])
	assert(#settingData == 1 and settingData[1].data)
	local data = load("return " .. settingData[1].data)()
	sharedata.update(dataKey, data)
end

function CMD.UpdateFile(filePath, notCheck)
	-- 判断是否在loadsetting_cfg中
	local settingfilesMap = Import("service/loadxls/loadsetting_cfg.lua").GetLoadSettingFilesMap()
	local tFilePath = ""
	if string.beginswith(filePath, "./") then
		tFilePath = string.sub(filePath, 3)
	else
		tFilePath = "./" .. filePath
	end

	if settingfilesMap[tFilePath] or settingfilesMap[filePath] then
		local msg = string.format("auto update setting:%s", filePath)
		skynet.error(msg)
		_UpdateXlsData(filePath, notCheck)
	end
end


function GcPerForm()
	collectgarbage("step", GCPERFORM_STEP)
end

function __init__()
	skynet.fork(function ()
		assert(GCPERFORM_STEP)
		while true do
			skynet.sleep(100)
			if TryCall then
				TryCall(DATA_MGR.GcPerForm)	-- 一定要有DEADLOCK，这样可以达到热更GCCheck(这是使用skynet.fork的缺陷)
			else
				DATA_MGR.GcPerForm()
			end
		end
	end)
end
