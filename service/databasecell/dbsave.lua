local skynet = require "skynet"
local queue = require "skynet.queue"
local mysql = require "skynet.db.mysql"
local table = table
local file = file
local tinsert = table.insert
local tconcat = table.concat
local string = string
local stringrep = string.rep
local stringgub = string.gsub
local EMPTY_TABLE_PACK = "{}"
local DATABASE_CFG = assert(load("return " .. skynet.getenv("database_info"))())
local LOG = Import("lualib/base/log.lua")

DBObj = false
Invalid = false
urs_cs_map = {}		-- {[urs] = cs, ...}
uid_cs_map = {}		-- {[uid] = cs, ...}
mod_cs_map = {}		-- {[mod] = cs, ...}

local ErrorStr = "badresult"
local DATABASE_ERRFILE = "database_err.log"
local DATABASE_FILE = "database.log"

HEARTBEAT_NOWTIME = false
local GCPERFORM_FTIME = 100				-- gc处理时间间隔1秒
local DATABASE_HEATBEAT_FTIME = 6000	-- 1分钟
HEARTBEAT_OVERTIME = 10 * 60			-- 10分钟超时时间
HEARTBEAT_CHECKTIME = 5					-- 5秒检测时间

local CACHE_SAVE_SECTIME = 25 * 60 + math.random(10 * 60)

-- 当closedb的时候要看ReqTbl是否处理完，处理外才能关闭db连接
ReqTbl = {}
ReqIndex = 0			-- 不能程序改变
MaxIndex = 10000000		-- 不能程序改变

local function _GetDbInvalid()
	return Invalid
end

local function _SetDbInvalid(inv)
	Invalid = inv
end

local function _GetQueueByUrs(urs)
	local cs = urs_cs_map[urs]
	if not cs then
		cs = queue()
		urs_cs_map[urs] = cs
	end
	return cs
end
local function _GetQueueByUid(uid)
	local cs = uid_cs_map[uid]
	if not cs then
		cs = queue()
		uid_cs_map[uid] = cs
	end
	return cs
end
local function _GetQueueByMod(mod)
	local cs = mod_cs_map[mod]
	if not cs then
		cs = queue()
		mod_cs_map[mod] = cs
	end
	return cs
end

-- 返回这个index后必须立即用，不能交出主权，如果交出回来后可能已经不能用了
local function _GetReqIndex()
	local nowTest = 0
	while true do
		local nextIndex = ReqIndex % MaxIndex + 1
		nowTest = nowTest + 1
		if not ReqTbl[nextIndex] then
			ReqIndex = nextIndex
			return nextIndex
		end
		ReqIndex = nextIndex
		if nowTest >= MaxIndex then
			ReqIndex = MaxIndex + 1
			MaxIndex = MaxIndex * 2
			return ReqIndex
		end
	end
end

local function _ConnectDatabase()
	local function on_connect(db)
		db:query("set charset utf8")
	end

	DBObj = mysql.connect({
		host = DATABASE_CFG.dbhost,
		port = DATABASE_CFG.dbport,
		database = DATABASE_CFG.dbname,
		user = DATABASE_CFG.dbuser,
		password = DATABASE_CFG.dbpasswd,
		max_packet_size = 1024 * 1024 * 2^ 9 -1,
		on_connect = on_connect,
	})
	-- 询问query的时候如果是断开还是继续连接，直到连接上
	if not DBObj then
		error("connect mysql error!")
	end
end

local function _cs_list_createnexist(urs)
	-- local quote_urs = mysql.quote_sql_str(urs)
	local quote_urs = urs
	local reqstr = string.format(
		"insert into list(acct_id, list_data) select %s, '%s' from dual where not exists (select * from list where acct_id = %s)",
		quote_urs, EMPTY_TABLE_PACK, quote_urs
	)
	return DBObj:query(reqstr)
end

local function dump(obj)
	local getIndent, quoteStr, wrapKey, wrapVal, dumpObj
	getIndent = function (level)
		return stringrep("\t", level)
	end
	quoteStr = function (str)
		return '"' .. stringgub(str, '"', '\\"') .. '"'
	end
	wrapKey = function (val)
		if type(val) == "number" then
			return "[" .. val .. "]"
		elseif type(val) == "string" then
			return "[" .. quoteStr(val) .. "]"
		else
			return "[" .. tostring(val) .. "]"
		end
	end
	wrapVal = function (val, level)
		if type(val) == "table" then
			return dumpObj(val, level)
		elseif type(val) == "number" then
			return val
		elseif type(val) == "string" then
			return	quoteStr(val)
		else
			return	tostring(val)
		end
	end
	dumpObj = function (obj, level)
		if type(obj) ~= "table" then
			return wrapVal(obj)
		end
		level = level + 1
		local tokens = {}
		tokens[#tokens + 1] = "{"
		for k, v in pairs(obj) do
			tokens[#tokens + 1] = getIndent(level) .. wrapKey(k) .. " = " .. wrapVal(v, level) .. ","
		end
		tokens[#tokens + 1] = getIndent(level - 1) .. "}"
		return tconcat(tokens, "\n")
	end
	return dumpObj(obj, 0)
end

function ACCEPT.list_createnexist(urs)
	if _GetDbInvalid() then
		return
	end

	local cs = _GetQueueByUrs(urs)
	local nowIndex = _GetReqIndex()

	ReqTbl[nowIndex] = true
	local isOk, res = pcall(cs, _cs_list_createnexist, urs)
	ReqTbl[nowIndex] = nil

	if isOk then
		if not res[ErrorStr] and res.affected_rows == 1 then
			LOG._LOG("create_list", {urs = urs})
		end
	else
		local msg = string.format("list_createnexist error, urs:%s, res:%s", urs, dump(res))
		LOG.LOG_EVENT(DATABASE_ERRFILE, msg)
		LOG._ERROR_A_ALARM(msg)
	end
end


function HeatBeatCheck()
	if DBObj and not _GetDbInvalid() then
		HEARTBEAT_NOWTIME = os.time()
		pcall(DBObj.query, DBObj, "desc module;")
		HEARTBEAT_NOWTIME = false
	end
end


function TimeOutCheck()
	if not HEARTBEAT_NOWTIME then
		return
	end

	if DBObj and not _GetDbInvalid() then
		local nTime = os.time()
		if nTime >= HEARTBEAT_NOWTIME + HEARTBEAT_OVERTIME then
			LOG._ERROR_A_ALARM(string.format("dbsave socket timeout, nowTime:%s >= HEARTBEAT_NOWTIME:%s + HEARTBEAT_OVERTIME:%s, start close socket",
				nTime, HEARTBEAT_NOWTIME, HEARTBEAT_OVERTIME
			))
			HEARTBEAT_NOWTIME = nTime	-- 为了socket断开后继续阻塞无反应做下次检测
			mysql.disconnect(DBObj)
			_ConnectDatabase()
		end
	end
end

local function DealwishTimer()
	while true do
		skynet.sleep(DATABASE_HEATBEAT_FTIME)
		TryCall(DBSAVE.HeatBeatCheck)
	end
end

local function GcPerform()
	while true do
		skynet.sleep(GCPERFORM_FTIME)
		collectgarbage("step", 512)
		-- collectgarbage("collect")
	end
end

function StartDb()
	_ConnectDatabase()
	skynet.timeout(0, DealwishTimer)	-- 使用skynet的定时器会好一些，因为里面也有重入的
	skynet.timeout(0, GcPerform)

	-- CALLOUT.CallFre("CacheSaveTimer", CACHE_SAVE_SECTIME)
end