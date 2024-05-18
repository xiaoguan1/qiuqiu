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
local DBCACHE = Import("service/databasecell/dbcache.lua")

local CACHE_FRAME_SECTIME = 1		-- 1秒

local CACHE_FRAME_URS_SAVECNT = 1	-- 每次CACHE_FRAME_SECTIME秒存urs多少个（每次存盘会根据时间/个数决定）
local CACHE_FRAME_UID_SAVECNT = 1	-- 每次CACHE_FRAME_SECTIME秒存uid多少个（每次存盘会根据时间/个数决定）
local CACHE_FRAME_MOD_SAVECNT = 1	-- 每次CACHE_FRAME_SECTIME秒存mod多少个（每次存盘会根据时间/个数决定）
local THRESHOLD_FRAME_SAVECNT = 10
local CACHE_SAVE_SECTIME = 25 * 60 + math.random(10 * 60)	-- 25~35分钟 存盘一次
local DELAY_DELETE_FID_TIME = 30 * 20		-- 1分钟1次删除，2个缓存的

CacheSaveUrs = {}
CacheSaveUid = {}
CacheSaveMod = {}
DelCacheSaveUrs = {}
DelCacheSaveUid = {}
DelCacheSaveMod = {}

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

local THRESHOLD_DATALEN		= THRESHOLD_DATALEN		-- 4m的警报阈值
local E_THRESHOLD_DATALEN	= E_THRESHOLD_DATALEN	-- 8m的错误阈值

local _SAVE_LISTDB_DATA_FORMAT = {
	"update list set list_data='",
	"' where acct_id=%s;",
}

local _SAVE_ROLEDB_ACTDATA_FORMAT = {
	"update role_data set %s='",
	"' where uid='%s';"
}

local _SAVE_MODDB_DATA_FORMAT = {
	"update module set data='",
	"' where mod_name=%s;"
}

DelayDelFIdList_F = {}
DelayDelFIdList_S = {}

DelayDelRIdList_F = {}
DelayDelRIdList_S = {}
DELETE_BATTLERECORD_SLEEP = 20		-- 删除多少个战报睡眠1秒

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

function ACCEPT.battlerecord_delete(fId)
	if _GetDbInvalid() then
		return
	end
	tinsert(DelayDelFIdList_S, fId)
end
function ACCEPT.battlerecord_deletelist(fIdList)
	if _GetDbInvalid() then
		return
	end
	for _, _fId in pairs(fIdList) do
		tinsert(DelayDelFIdList_S, _fId)
	end
end

function ACCEPT.resultrecord_delete(rId)
	tinsert(DelayDelRIdList_S, rId)
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




local function _cs_list_setdata(urs, isdel_cache)
	-- 获取缓存里面的
	local data_ptr, sz, quotedsz = DBCACHE.GetCacheUrs(urs)
	if not data_ptr then
		local msg = string.format("not urs:%s data but save", urs) -- 可能会存在的，连续几次调用存盘(定时与关服等)
		LOG.LOG_EVENT(DATABASE_ERRFILE, msg)
		-- if is_testserver then
		-- 	LOG._WARN(msg)
		-- end
		return
	end
	if DBCACHE.IsSaveCacheUrs(urs) then
		if isdel_cache then
			-- 删除缓存里面的
			DBCACHE.DelCacheUrs(urs)
		end
		return
	end
	if sz > THRESHOLD_DATALEN then
		local msg = string.format("urs:%s data sz:%s >= threshold sz:%s", urs, sz, THRESHOLD_DATALEN)
		LOG._WARN(msg)
		if sz > E_THRESHOLD_DATALEN then
			local msg = string.format("urs:%s data sz:%s >= threshold sz:%s", urs, sz, E_THRESHOLD_DATALEN)
			LOG._ERROR(msg)
		end
	end

	local omd5 = DBCACHE.GetUrsMd5(urs)
	local nmd5 = UTIL.Sumhexa(data_ptr, sz)
	if omd5 and omd5 == nmd5 then		-- 数据一样则不存
		if isdel_cache then
			-- 删除缓存里面的
			DBCACHE.DelCacheUrs(urs)
		else
			DBCACHE.SetSaveCacheUrs(urs, true)
		end
		LOG.LOG_EVENT(DATABASE_FILE, "list(same save data)", urs, sz, quotedsz)
		return true
	end

	local isOk, res = pcall(DBObj.query_ptr_ex, DBObj,	-- 使用指针减少多次复制
		_SAVE_LISTDB_DATA_FORMAT[1],
		string.format(_SAVE_LISTDB_DATA_FORMAT[2], mysql.quote_sql_str(urs)),
		data_ptr, sz, quotedsz
	)
	if isOk and not res[ErrorStr] and res.affected_rows == 1 then
		if isdel_cache then
			-- 删除缓存里面的
			DBCACHE.DelCacheUrs(urs)
		else
			DBCACHE.SetSaveCacheUrs(urs, true)
		end
		DBCACHE.RefresUrsMd5(urs, nmd5)		-- 成功才记录md5
		LOG.LOG_EVENT(DATABASE_FILE, "list", urs, sz, quotedsz)
		return true
	end

	local msg = string.format("_cs_list_setdata error, urs:%s, res:%s", urs, dump(res))
	LOG.LOG_EVENT(DATABASE_ERRFILE, msg, skynet.tostring(data_ptr, sz))
	LOG._ERROR_A_ALARM(msg)
	error(msg)
end

function real_list_setdata_ptrq(urs, isdel_cache)
	if _GetDbInvalid() then
		return
	end
	local cs = _GetQueueByUrs(urs)
	local nowIndex = _GetReqIndex()

	ReqTbl[nowIndex] = true
	TryCall(cs, _cs_list_setdata, urs, isdel_cache)
	ReqTbl[nowIndex] = nil
end

local function _cs_role_setdata(uid, actName, isdel_cache)
	local data_ptr, sz, quotedsz, name = DBCACHE.GetCacheUid(uid)
	if not data_ptr then
		local msg = string.format("not uid:%s actName:%s data but save", uid, actName) -- 可能会存在的，连续几次调用存盘(定时与关服等)
		LOG.LOG_EVENT(DATABASE_ERRFILE, msg)
		-- if is_testserver then
		-- 	LOG._WARN(msg)
		-- end
		return
	end
	if DBCACHE.IsSaveCacheUid(uid, actName) then
		if isdel_cache then
			-- 删除缓存里面的
			DBCACHE.DelCacheUid(uid, actName)
		end
		return
	end
	if sz > THRESHOLD_DATALEN then
		local msg = string.format("uid:%s actName:%s data sz:%s >= threshold sz:%s", uid, actName, sz, THRESHOLD_DATALEN)
		LOG._WARN(msg)
		if sz > E_THRESHOLD_DATALEN then
			local msg = string.format("uid:%s actName:%s data sz:%s >= threshold sz:%s", uid, actName, sz, THRESHOLD_DATALEN)
			LOG._ERROR(msg)
		end
	end

	local omd5 = DBCACHE.GetUidMd5(uid, actName)
	local nmd5 = UTIL.Sumhexa(data_ptr, sz)
	if omd5 and omd5 == nmd5 then		-- 数据一样则不存
		if isdel_cache then
			-- 删除缓存里面的
			DBCACHE.DelCacheUid(uid, actName)
		else
			DBCACHE.SetSaveCacheUid(uid, actName, true)
		end
		LOG.LOG_EVENT(DATABASE_FILE, "role_data(same save data)", uid, actName, sz, quotedsz)
		return true
	end

	local isOk, res = pcall(DBObj.query_ptr_ex, DBObj,	-- 使用指针减少多次复制
		string.format(_SAVE_ROLEDB_ACTDATA_FORMAT[1], actName),
		string.format(_SAVE_ROLEDB_ACTDATA_FORMAT[2], uid),
		data_ptr, sz, quotedsz
	)
	if isOk and not res[ErrorStr] and res.affected_rows == 1 then
		if isdel_cache then
			-- 删除缓存里面的
			DBCACHE.DelCacheUid(uid, actName)
		else
			DBCACHE.SetSaveCacheUid(uid, actName, true)
		end
		DBCACHE.RefresUidMd5(uid, actName, nmd5)		-- 成功才记录md5
		LOG.LOG_EVENT(DATABASE_FILE, "role_data", uid, actName, sz, quotedsz)
		return true
	end

	local msg = string.format("_cs_role_setactdata error, uid:%s, actName:%s sz:%s res:%s", uid, actName, sz, dump(res))
	LOG.LOG_EVENT(DATABASE_ERRFILE, msg, skynet.tostring(data_ptr, sz))
	LOG._ERROR_A_ALARM(msg)
	error(msg)
end

function real_role_setdata_ptrq(uid, actName, isdel_cache)
	if _GetDbInvalid() then
		return
	end
	local cs = _GetQueueByUid(uid)
	local nowIndex = _GetReqIndex()

	ReqTbl[nowIndex] = true
	TryCall(cs, _cs_role_setdata, uid, actName, isdel_cache)
	ReqTbl[nowIndex] = nil
end

local function _cs_mod_setdata(modname, isdel_cache)
	local data_ptr, sz, quotedsz = DBCACHE.GetCacheMod(modname)
	if not data_ptr then
		local msg = string.format("not mod:%s data but save", modname) -- 可能会存在的，连续几次调用存盘(定时与关服等)
		LOG.LOG_EVENT(DATABASE_ERRFILE, msg)
		-- if is_testserver then
		-- 	LOG._WARN(msg)
		-- end
		return
	end
	if DBCACHE.IsSaveCacheMod(modname) then
		if isdel_cache then
			-- 删除缓存里面的
			DBCACHE.DelCacheMod(modname)
		end
		return
	end
	if sz > THRESHOLD_DATALEN then
		local msg = string.format("modname:%s data sz:%s >= threshold sz:%s", modname, sz, THRESHOLD_DATALEN)
		LOG._WARN(msg)
		if sz > E_THRESHOLD_DATALEN then
			local msg = string.format("modname:%s data sz:%s >= threshold sz:%s", modname, sz, THRESHOLD_DATALEN)
			LOG._ERROR(msg)
		end
	end

	local omd5 = DBCACHE.GetModMd5(modname)
	local nmd5 = UTIL.Sumhexa(data_ptr, sz)
	if omd5 and omd5 == nmd5 then		-- 数据一样则不存
		if isdel_cache then
			-- 删除缓存里面的
			DBCACHE.DelCacheMod(modname)
		else
			DBCACHE.SetSaveCacheMod(modname, true)
		end
		LOG.LOG_EVENT(DATABASE_FILE, "modname(same save data)", modname, sz, quotedsz)
		return true
	end

	local isOk, res = pcall(DBObj.query_ptr_ex, DBObj,	-- 使用指针减少多次复制
		_SAVE_MODDB_DATA_FORMAT[1],
		string.format(_SAVE_MODDB_DATA_FORMAT[2], mysql.quote_sql_str(modname)),
		data_ptr, sz, quotedsz
	)
	if isOk and not res[ErrorStr] and res.affected_rows == 1 then
		if isdel_cache then
			-- 删除缓存里面的
			DBCACHE.DelCacheMod(modname)
		else
			DBCACHE.SetSaveCacheUid(modname, true)
		end
		DBCACHE.RefresModMd5(modname, nmd5)		-- 成功才记录md5
		LOG.LOG_EVENT(DATABASE_FILE, "module", modname, sz, quotedsz)
		return true
	end

	local msg = string.format("_cs_mod_setdata error, mod:%s, sz:%s res:%s", modname, sz, dump(res))
	LOG.LOG_EVENT(DATABASE_ERRFILE, msg, skynet.tostring(data_ptr, sz))
	LOG._ERROR_A_ALARM(msg)
	error(msg)
end

function real_mod_setdata_ptrq(modname, isdel_cache)
	if _GetDbInvalid() then
		return
	end
	local cs = _GetQueueByMod(modname)
	local nowIndex = _GetReqIndex()

	ReqTbl[nowIndex] = true
	TryCall(cs, _cs_mod_setdata, modname, isdel_cache)
	ReqTbl[nowIndex] = nil
end

local function _PopCache(cache)
	for _k, _ in pairs(cache) do
		cache[_k] = nil
		return _k
	end
end

function CacheFrameTimer(isFull)
	if _GetDbInvalid() then
		return
	end
	if isFull then
		local tmpUrs = CacheSaveUrs
		local tmpUid = CacheSaveUid
		local tmpMod = CacheSaveMod
		CacheSaveUrs = {}
		CacheSaveUid = {}
		CacheSaveMod = {}

		for _urs, _ in pairs(tmpUrs) do
			real_list_setdata_ptrq(_urs, DelCacheSaveUrs[_urs])
		end
		for _uid, _ in pairs(tmpUid) do
			-- 获取该玩家的所有活动，然后再调用
			local alist = DBCACHE.GetCacheUidActList(_uid)
			if alist then
				for _, _actName in pairs(alist) do
					real_role_setdata_ptrq(_uid, _actName, DelCacheSaveUid[_uid])
				end
			end
		end
		for _mod, _ in pairs(tmpMod) do
			real_mod_setdata_ptrq(_mod, DelCacheSaveMod[_mod])
		end
	else
		for i = 1, CACHE_FRAME_URS_SAVECNT do
			local urs = _PopCache(CacheSaveUrs)
			if not urs then
				break
			end
			real_list_setdata_ptrq(urs, DelCacheSaveUrs[urs])
		end
		for i = 1, CACHE_FRAME_UID_SAVECNT do
			local uid = _PopCache(CacheSaveUid)
			if not uid then
				break
			end
			-- 获取该玩家的所有活动，然后再调用
			local alist = DBCACHE.GetCacheUidActList(uid)
			if alist then
				for _, _actName in pairs(alist) do
					real_role_setdata_ptrq(uid, _actName, DelCacheSaveUid[uid])
				end
			end
		end
		for i = 1, CACHE_FRAME_MOD_SAVECNT do
			local mod = _PopCache(CacheSaveUid)
			if not mod then
				break
			end
			real_mod_setdata_ptrq(mod, DelCacheSaveMod[mod])
		end
	end

end

-- 定时复制表，每秒定时存多少个，最后那一秒全部存，复制的时候知道有多少个，然后定制要删除多少个
function CacheSaveTimer()
	if _GetDbInvalid() then
		return
	end

	-- 把剩余缓存的全部存一次
	TryCall(CacheFrameTimer, true)

	-- 记录当前需要存的数据
	CacheSaveUrs, DelCacheSaveUrs, CACHE_FRAME_URS_SAVECNT = DBCACHE.GetAllCacheUrs()
	CacheSaveUid, DelCacheSaveUid, CACHE_FRAME_UID_SAVECNT = DBCACHE.GetAllCaCheUid()
	CacheSaveMod, DelCacheSaveMod, CACHE_FRAME_MOD_SAVECNT = DBCACHE.GetAllCaCheMod()
	local aUrsSaveCnt = CACHE_FRAME_URS_SAVECNT
	local aUidSaveCnt = CACHE_FRAME_UID_SAVECNT
	local aModSaveCnt = CACHE_FRAME_MOD_SAVECNT

	-- 计算每秒存多少个
	CACHE_FRAME_URS_SAVECNT = math.ceil(CACHE_FRAME_URS_SAVECNT / CACHE_SAVE_SECTIME)
	CACHE_FRAME_UID_SAVECNT = math.ceil(CACHE_FRAME_UID_SAVECNT / CACHE_SAVE_SECTIME)
	CACHE_FRAME_MOD_SAVECNT = math.ceil(CACHE_FRAME_MOD_SAVECNT / CACHE_SAVE_SECTIME)

	if CACHE_FRAME_URS_SAVECNT > THRESHOLD_FRAME_SAVECNT or
		CACHE_FRAME_UID_SAVECNT > THRESHOLD_FRAME_SAVECNT or
		CACHE_FRAME_MOD_SAVECNT > THRESHOLD_FRAME_SAVECNT
	then
		LOG._WARN_F("CacheSaveTimer urs_cnt[%s:%s] uid_cnt[%s:%s] mod_cnt[%s:%s]",
			aUrsSaveCnt, CACHE_FRAME_URS_SAVECNT,
			aUidSaveCnt, CACHE_FRAME_UID_SAVECNT,
			aModSaveCnt, CACHE_FRAME_MOD_SAVECNT
		)
	end
	LOG._INFO_F("CacheSaveTimer urs_cnt[%s:%s] uid_cnt[%s:%s] mod_cnt[%s:%s]",
		aUrsSaveCnt, CACHE_FRAME_URS_SAVECNT,
		aUidSaveCnt, CACHE_FRAME_UID_SAVECNT,
		aModSaveCnt, CACHE_FRAME_MOD_SAVECNT
	)
end

local function GetRecordSavePath(fId)
	return string.format("%s/%s/%s/%s.dat", RECORD_BASEPATH, string.sub(fId, 1, 2), string.sub(fId, 3, 11), fId)
end

local function GetResultRecordSavePath(rId)
	return string.format("%s/%s/%s/%s.dat", RESULTRECORD_BASEPATH, string.sub(rId, 1, 2), string.sub(rId, 3, 11), rId)
end

function CheckDelayDelBattleRecord()
	if _GetDbInvalid() then
		return
	end
	local needDeleteData = DelayDelFIdList_F
	DelayDelFIdList_F = DelayDelFIdList_S
	DelayDelFIdList_S = {}

	if #needDeleteData > 0 then
		skynet.fork(function ()
			local dcnt = 0
			for _, _fId in pairs(needDeleteData) do
				dcnt = dcnt + 1
				if dcnt % DELETE_BATTLERECORD_SLEEP == 0 then
					skynet.sleep(100)
				end
				local fileName = GetRecordSavePath(_fId)
				local ok, err = os.remove(fileName)
				if not ok then
					local msg = string.format("CheckDelayDelBattleRecord fid:%s err:%s", _fId, err)
					LOG._ERROR(msg)
				end
			end
			LOG.LOG_EVENT(DATABASE_FILE, "result_removelist", lserialize.lua_seri_str(needDeleteData))
		end)
	end
end

function CheckDelayDelResultRecord()
	if _GetDbInvalid() then
		return
	end
	local needDeleteData = DelayDelRIdList_F
	DelayDelRIdList_F = DelayDelRIdList_S
	DelayDelRIdList_S = {}

	if #needDeleteData > 0 then
		skynet.fork(function ()
			local dcnt = 0
			for _, _rId in pairs(needDeleteData) do
				dcnt = dcnt + 1
				if dcnt % DELETE_BATTLERECORD_SLEEP == 0 then
					skynet.sleep(100)
				end
				local fileName = GetResultRecordSavePath(_rId)
				local ok, err = os.remove(fileName)
				if not ok then
					local msg = string.format("CheckDelayDelResultRecord fid:%s err:%s", _rId, err)
					LOG._ERROR(msg)
				end
			end
			LOG.LOG_EVENT(DATABASE_FILE, "result_removelist", lserialize.lua_seri_str(needDeleteData))
		end)
	end
end

function StartDb()
	_ConnectDatabase()
	skynet.timeout(0, DealwishTimer)	-- 使用skynet的定时器会好一些，因为里面也有重入的
	skynet.timeout(0, GcPerform)

	CALLOUT.CallFre("CacheSaveTimer", CACHE_SAVE_SECTIME)
	CALLOUT.CallFre("CacheFrameTimer", CACHE_FRAME_SECTIME)
	CALLOUT.CallFre("CheckDelayDelBattleRecord", DELAY_DELETE_FID_TIME)
	CALLOUT.CallFre("CheckDelayDelResultRecord", DELAY_DELETE_FID_TIME)
end