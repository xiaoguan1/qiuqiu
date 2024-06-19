-------------------------------
-- 创建者：Ghost
-- 创建日期：2019/08/02
-- 模块作用：模块存盘接口
-------------------------------

local skynet = require "skynet"
local string = string
local table = table
local pairs = pairs
local ipairs = ipairs
local traceback = debug.traceback
local assert = assert
local xpcall = xpcall
local type = type

assert(CALLOUT)
local PROXYSVR = Import("base/proxysvr.lua")
local SHUTDOWN_SVR = PROXYSVR.GetProxyByServiceName("shutdown")
local MERGE_SVR = PROXYSVR.GetProxyByServiceName("merge")
assert(MERGE_SVR)
local SELF_ADDR = skynet.self()
local SNODE_NAME = DPCLUSTER_NODE.self
local DATABASE_COMMON = Import("global/database_common.lua")
local LOG = Import("base/log.lua")

-- 注意：
-- 1.服务关闭的需要调用一下来存储
-- 2.恢复文件数据是可能会有重入的，所以一般尽量保证启动service就加载了所以模块，如果不能保证就要自己处理重入的问题
-- 3.每个模块的存储数据都应该为，
-- 		(1).设置__SAVE_NAME = "xxx/xxx"，例如 __SAVE_NAME = "login/login"下
--		(2).在__init__函数中MOUDLE_DB.Register("需要保存的table或者全局变量","需要保存的table或者全局变量", 等等)

local RESPONSE = RESPONSE or CMD
assert(RESPONSE)
if not RESPONSE.shutdown_savemodule then
	function RESPONSE.shutdown_savemodule()
		Shutdown_SaveModule()
	end
else
	LOG._WARN("has RESPONSE.shutdown_savemodule")
end

local SAVE_TIME = 8 * 60							-- 8分钟一次数据存盘
local SAVE_TIME_F = math.abs(skynet.self() + 5) 	-- 第一次存盘的时间，因为每个service时间不一样，这样就能防止扎堆
local SAVE_NORMALCNT = 5							-- 每SAVE_MODULETIME存储的个数
local SAVE_MODULETIME = 1							-- 模块数据分时存储 1秒存SAVE_NORMALCNT个模块

IS_SHUTDOWN = false
SaveRegTbl = {}
ModuleCache = {}

local mt = {__mode = "k"}
setmetatable(SaveRegTbl, mt)

local function _DumpWarn(fmt, ...)
	if _WARN_F then
		_WARN_F(fmt, ...)
	else
		local msg = string.format(fmt, ...)
		skynet.error(msg)
	end
end

-- 注册检测
local function _RegisterCheck(saveName, data)
end

local function _RestoreModuleFormDb(saveName)
	local ok, ret, data = pcall(DATABASE_COMMON.Call_ModGetData, saveName)
	if ok and ret and data then
		_RegisterCheck(saveName, data)
		return assert(load("return " .. data, "unserialize module error"))(), #data
	else
		error("restore module error:" .. saveName)
	end
end

local function _ModuleRestore(module)
	local saveName = module.__SAVE_NAME
	-- 已经注册的module，不覆盖数据
	if SaveRegTbl[module] then return end

	-- 在数据库中创建，判断是否有这个数据，没有就insert into
	DATABASE_COMMON.Send_ModCreateNexist(saveName)

	local tblData, sz = _RestoreModuleFormDb(saveName)
	if not tblData then
		return
	else
		for k, v in pairs(tblData) do
			module[k] = v
		end
		return sz
	end
end

-- 注册关闭服务事件
local function _RegisterShutdownEvent(saveName)
	SHUTDOWN_SVR.send.register_moudle_sdevent(saveName, SELF_ADDR, SNODE_NAME)	-- 使用call比较容易出错，send在写代码如果有重复应该就知道了
end

-- 注册module的变量名以供存储
function RegisterByEnv(module, ...)
	local sz = _ModuleRestore(module) or 0
	if not SaveRegTbl[module] then
		_RegisterShutdownEvent(module.__SAVE_NAME)
	end

	local arg = table.pack(...)
	arg.n = nil	-- 去掉n的大小
	for _, v in pairs(arg) do
		assert(type(v) == "string", string.format("module %s register var key is not string", module.__SAVE_NAME))
		if module[v] == nil then
			local fmt = [[
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
module:%s key:%s save data is nil
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
------------------------------------------------------------------------
			]]
			_DumpWarn(fmt, module.__SAVE_NAME, v)
		end
	end

	SaveRegTbl[module] = arg
	return sz
end

-- 注册module的变量名以供存储
function Register(...)
	local module = getfenv(2)
	return RegisterByEnv(module, ...)
end

function SaveModuleOnFrame(isFull)
	if not IS_SHUTDOWN then			-- 没有停服
		local cnt = 0
		for _module, _data in pairs(ModuleCache) do
			if not isFull then
				cnt = cnt + 1
				if cnt > SAVE_NORMALCNT then break end
			end
			SaveOneModule(_module)
		end
	end
end

function FlushCache()
	SaveModuleOnFrame(true)
end

function SaveOneModule(module, isTmm)
	if ModuleCache[module] then
		ModuleCache[module] = nil
	end

	if SaveRegTbl[module] then
		local varList = SaveRegTbl[module]
		local function _DoModuleRegTblSave()
			local tmp = {}
			for _, _var in ipairs(varList) do
				tmp[_var] = module[_var]
			end
			local save_name = module.__SAVE_NAME
			DATABASE_COMMON.Send_ModSave(save_name, tmp, isTmm)
			LOG.LOG_EVENT("module2dbsave.log", save_name, IS_SHUTDOWN)
		end
		local ok, err = xpcall(_DoModuleRegTblSave, traceback)
		if not ok then
			skynet.error("_DoModuleRegTblSave error:", module.__SAVE_NAME, err)
			local tmp = {}
			for _, _var in ipairs(varList) do
				tmp[_var] = module[_var]
			end
			skynet.error("_DoModuleRegTblSave error varList:", module.__SAVE_NAME, sys.dumptree(tmp))
		end
	end
end

function SaveAllModule()
	-- 模块注册变量存盘
	local cnt = 0
	for _module, _data in pairs(SaveRegTbl) do
		ModuleCache[_module] = _data
		cnt = cnt + 1
	end
	SAVE_NORMALCNT = math.ceil(cnt / SAVE_TIME)
end

function SaveAll()
	FlushCache()		-- Cache里面可能有数据，所以要先FlushCache
	SaveAllModule()		-- 模块存盘
end

function Shutdown_SaveModule()
	IS_SHUTDOWN = true
	SaveAllModule()

	local tM = {}
	for _k, _v in pairs(ModuleCache) do
		tM[_k] = _v
	end

	for _module, _data in pairs(tM) do	-- 用tM防止因为最后的call保存导致中间停止了
		SaveOneModule(_module)
	end
end

function FirstSaveAll()
	CALLOUT.CallFre("SaveAll", SAVE_TIME)
	SaveAll()
end

function __init__()
	CALLOUT.CallOut("FirstSaveAll", SAVE_TIME_F)
	CALLOUT.CallOut("SaveModuleOnFrame", SAVE_MODULETIME)
end
