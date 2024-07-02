------------------------------------------------------
-- 创作者：Ghost
-- 创建日期：2019/08/02
-- 模块作用：定时器，只支持精确度为1秒
------------------------------------------------------

local skynet = require "skynet"
local skytime = skynet.time
local SERVICE_NAME = SERVICE_NAME
local getfenv = getfenv
local assert = assert
local type = type
local table = table
local tpack = table.pack
local tunpack = table.unpack
local collectgarbage = collectgarbage
local _MEM_ALARM_F = _MEM_ALARM_F
local SNODE_NAME = DPCLUSTER_NODE.self
local sformat = string.format
MEM_ALARM_THRESHOLD = 5120				-- 超5m内存警报阈值
MEM_IGNORE_ALARM = {
	["CClubTimerFunc"] = true,			-- 创建机器人
	["GroupRiskTimerFunc"] = true,		-- 创建机器人
	["UpdateAreaRankData"] = true,		-- 竞技场欺负需要刷新排行榜
}
if not PROXYSVR then
	PROXYSVR = Import("lualib/base/proxysvr.lua")
end

local stimerld = EVERY_NODE_SERVER and EVERY_NODE_SERVER.stimer and EVERY_NODE_SERVER.stimer.named
if not stimerld then
	error("stimer service not localname")
end
local SCALLOUT_SVR = PROXYSVR.GetProxy(stimerld, SNODE_NAME, nil, "callout")

local CALLOUT_RT = 0.1					-- 定时器响应时间x秒以上则打印(精确度0.01)
local ALARM_CALLOUT_RT = 1.5			-- 定时器响应时间x秒以上则警报
local NORMAL = 0
local FREQUENCY = 1
callout_func = {}

local ALARM_HOURMIN_IGNORE = {	-- 警报忽略时间节点区间
	[21] = {min = {0, 30}, rt = 3},				-- 21点~21点30，3秒。争霸赛战斗计算耗时
	[12] = {min = {0, 30}, wday = 1, rt = 3},	-- 周日中午12点~12点30，3秒。跨服争霸赛计算耗时
	[0] = {min = {0, 2}, rt = 4},				-- 每天凌晨0点，4秒。主题活动
	[11] = {min = {0, 1}, rt = 4},				-- 11点，4秒。cadvarena
}

CallIndex = 0	-- 定时器的idx

-- 注册消息 ------------------------------------
skynet.dispatch("callout", function (session, _, callIdx)
	if not callout_func[callIdx] then return end

	local sTime = skytime()
	callout_func[callIdx]()
	if CALLOUT_RT then
		local sub = skytime() - sTime
		if sub >= CALLOUT_RT then
			_WARN(sformat("callIdx:%d use time:%s(s)", callIdx, sub))
		end
		if sub >= ALARM_CALLOUT_RT then
			-- 判断是否在时间中
			local nd = os.date("*t")
			local isAlarm = true
			local cHourData = ALARM_HOURMIN_IGNORE[nd.hour]
			if cHourData then
				if cHourData.min[1] <= nd.min and nd.min <= cHourData.min[2] then
					if cHourData.wday then
						if cHourData.wday == nd.wday then
							isAlarm = false
						end
					else
						isAlarm = false
					end
				end
				if not isAlarm and sub >= cHourData.rt then		-- 超出一定时间还是要的
					isAlarm = true
				end
			end
			if isAlarm then
				local msg = sformat("callIdx:%d use time:%s(s)", callIdx, sub)
				print(msg)
			end
		end
	end
end)

-- 内部方法 ------------------------------------

local function _GetIndex()		-- 特别注意，多服务中CallIndex不唯一。
	CallIndex = CallIndex + 1
	return CallIndex
end

local function _call_multi(t, func)
	assert(t >= 1)
	local idx = _GetIndex()
	SCALLOUT_SVR.send.call_multi(SNODE_NAME, idx, t)
	callout_func[idx] = func
	return idx
end

local function _call_once(t, func)
	local idx = _GetIndex()
	SCALLOUT_SVR.send.call_once(SNODE_NAME, idx, t)
	callout_func[idx] = func
	return idx
end

local function _call_daily(hour, min, sec, func)
	assert(0 <= hour and hour <= 23)
	local idx = _GetIndex()
	SCALLOUT_SVR.send.call_daily(SNODE_NAME, idx, hour, min, sec)
	callout_func[idx] = func
	return idx
end

local function _call_remove(idx)
	SCALLOUT_SVR.send.rm_call(idx)
	return true
end

-- 用函数的upvalue来记录相关信息
-- 返回timer的自增索引，二不是timer本身，可以防止同一个object内部重复删除/添加timer时可能造成的丢失情况。
local function CallOutByType(Env, func, timeOut, callType, ...)
	local fType = type(func)
	if fType == "string" then
		if not Env[func] then
			error(sformat("not string func:%s", func))
		end
	else
		if fType ~= "function" then
			error(sformat("not function type:%s", fType))
		end
	end

	local arg = tpack(...)
	Env.__AllTimers = Env.__AllTimers or {}
	local idx = nil
	local function _RealFunc()
		local sMem = collectgarbage("count")
		if callType ~= FREQUENCY then
			Env.__AllTimers[idx] = nil	-- remove
			callout_func[idx] = nil
		end
		if type(func) == "string" then
			Env[func](tunpack(arg, 1, arg.n))
		else
			func(tunpack(arg, 1, arg.n))
		end
		local eMem = collectgarbage("count")
		if not MEM_IGNORE_ALARM[func] and (eMem - sMem) > MEM_ALARM_THRESHOLD then
			_MEM_ALARM_F("callout idx:%s env:%s func:%s timeOut:%s use_mem:%.2f-%.2f=%.2f(Mb)!!!",
				idx, Env, func, timeOut, eMem/1024, sMem/1024, (eMem - sMem)/1024
			)
		end
	end
	if callType == FREQUENCY then
		idx = _call_multi(timeOut, _RealFunc)
	else
		idx = _call_once(timeOut, _RealFunc)
	end

	Env.__AllTimers[idx] = true
	if CALLOUT_RT then
		local msg = nil
		if callType == FREQUENCY then
			msg = sformat("CallFre callIdx:%d funcName:%s timeOut:%s", idx, func, timeOut)
		else
			msg = sformat("CallOut callIdx:%d funcName:%s timeOut:%s", idx, func, timeOut)
		end
		_INFO(msg)
	end
	return idx
end

local function CallOutByDaily(Env, func, hour, min, sec, ...)
	if type(func) == "string" then
		if not Env[func] then
			error(sformat("not func:%s", func))
		end
	end

	local arg = tpack(...)
	Env.__AllTimers = Env.__AllTimers or {}

	local idx = nil
	local function _RealFunc()
		local sMem = collectgarbage("count")
		if type(func) == "string" then
			Env[func](tunpack(arg, 1, arg.n))
		else
			func(tunpack(arg, 1, arg.n))
		end
		local eMem = collectgarbage("count")
		if not MEM_IGNORE_ALARM[func] and (eMem - sMem) > MEM_ALARM_THRESHOLD then
			_MEM_ALARM_F("callout daily idx:%s env:%s func:%s hour:%s min:%s sec:%s use_mem:%.2f-%.2f=%.2f(Mb)!!!",
			idx, Env, func, hour, min, sec, eMem/1024, sMem/1024, (eMem - sMem)/1024
		)
		end
	end
	idx = _call_daily(hour, min, sec, _RealFunc)

	Env.__AllTimers[idx] = true
	if CALLOUT_RT then
		local msg = sformat("CallDaily callIdx:%d funcName:%s hour:%s min:%s sec:%s", idx, func, hour, min, sec)
		print(msg) -- 缺一个运行定时器的日志打印
	end
	return idx
end


-- 外部方法 ------------------------------------

-- 以某频率(second)定时运行
function CallFre(func, freqency, ...)
	local Env = getfenv(2)
	assert(type(Env) == "table")
	assert(type(func) == "string")
	local idx = CallOutByType(Env, func, freqency, FREQUENCY, ...)
	return idx
end

function CallOut(func, timeOut, ...)
	local Env = getfenv(2)
	assert(type(Env) == "table")
	assert(type(func) == "string")
	local idx = CallOutByType(Env, func, timeOut, NORMAL, ...)
	return idx
end

-- 每一天的某个时刻执行
function Daily(hour, min, sec, func, ...)
	local Env = getfenv(2)
	assert(type(Env) == "table")
	assert(type(func) == "string")
	local idx = CallOutByDaily(Env, func, hour, min, sec, ...)
	return idx
end

-- 删除指定timer
function RemoveCallOut(Env, idx)
	assert(Env and idx)
	Env.__AllTimers = Env.__AllTimers or {}

	local tOk = Env.__AllTimers[idx]
	Env.__AllTimers[idx] = nil
	callout_func[idx] = nil

	if tOk then
		if CALLOUT_RT then
			local msg = sformat("RemoveCallOut callIdx:%d", idx)
			print(msg)
		end
		return _call_remove(idx)
	else
		if CALLOUT_RT then
			_ERROR(sformat("RemoveCallOut but not callIdx:%d", idx, debug.traceback()))
		end
		return true
	end
end


-- 缺少 定时器相关的打印日志、定时器的唯一idx  和 定时器服务