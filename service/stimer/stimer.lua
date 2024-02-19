local skynet = require "skynet"
-- require "skynet.manager"
local mfloor = math.floor

ACCEPT = {}	-- 异步消息处理方法

-- 这里只负责到点发送消息给对应的服务，但不记录具体让服务做什么内容的记录【服务自己负责】

------------------------------ 定时器类型 ------------------------------
local NORMAL_TYPE = 1		-- 不精确的时间，例如玩家的心跳
local ACCURATE_TYPE = 2		-- 精确的时间，例如每天什么时候开启某个玩法，12点清0的一些回调

local ONE_DAY = 60 * 60 * 24	-- 一天的时间秒数

local CallOutTbl = {}	-- 目前定时器服务不支持热更，设置局部变量即可。

-- 间隔多久执行一次
function ACCEPT.call_multi(source, nodeName, index, timeout)
	if timeout <= 0 then error("error call_multi, timeout <= 0.") end

	-- 注意：这里的os.time() 会因为stimer服务的繁忙，导致不精准。
	local nextTime = mfloor(os.time() + timeout)

	if not CallOutTbl[nextTime] then CallOutTbl[nextTime] = {} end

	CallOutTbl[nextTime][index] = {
		source = source,
		nodeName = nodeName,
		refresh_time = timeout,
		nextType = NORMAL_TYPE
	}

	return index
end

-- 在某个时间点执行一次(仅仅一次)
function ACCEPT.call_once(source, nodeName, index, timeout)
	if timeout <= 0 then timeout = 1 end

	local nextTime = mfloor(os.time() + timeout)

	if not CallOutTbl[nextTime] then CallOutTbl[nextTime] = {} end

	CallOutTbl[nextTime][index] = {
		source = source,
		nodeName = nodeName,
	}

	return index
end

-- 一天执行一次
function ACCEPT.call_daily(source, nodeName, index, hour, min, sec)
	local checkHour = hour >= 0 and hour <= 23
	local checkMin = min >= 0 and min <= 60
	local checkSec = sec >= 0 and sec <= 60
	if not (checkHour and checkMin and checkSec) then
		error(string.format("error call_daily, hour:[%s] min:[%s] sec:[%s]", hour, min, sec))
	end

	local nowTime = os.time()
	local nowDateTbl = os.date("*t", nowTime)
	local nextTime = os.time({ year = nowDateTbl.year, month = nowDateTbl.month, day = nowDateTbl.day, hour = hour, min = min, sec = sec, })

	-- 时间点已经过了，设置成隔天。
	if nowTime > nextTime then nextTime = nextTime + ONE_DAY end

	if not CallOutTbl[nextTime] then CallOutTbl[nextTime] = {} end

	CallOutTbl[nextTime][index] = {
		source = source,
		nodeName = nodeName,
		refresh_time = ONE_DAY,		-- 循环时间间隔
		nextType = ACCURATE_TYPE,
	}

	return index
end

------------------------------ 定时器类型 ------------------------------

local function _DealWithOnce(nowTime, endTime)
	local temTbl = CallOutTbl[nowTime]
	if not temTbl then return end

	for index, tbl in pairs(temTbl) do
		skynet.send(tbl.source, "callout", index)
		local refresh_time = tbl.refresh_time
		local nextTime
		if refresh_time then
			if tbl.nextType == ACCURATE_TYPE then
				nextTime = nowTime + refresh_time
			else
				nextTime = endTime + refresh_time
			end

			-- 更新定时器数据内容
			if not CallOutTbl[nextTime][index] then CallOutTbl[nextTime][index] = {} end
			CallOutTbl[nextTime][index] = tbl
		end
	end
	CallOutTbl[nowTime] = nil	-- 清空，否则数据缓存会越来越大！
end

local START_TIME = os.time()
local LAST_TIME = START_TIME
local function _DealWithTimer()
	local first = true
	while true do
		skynet.sleep(100)	-- 每秒执行
		local nowTime = os.time()
		if first then
			first = nil
			for i = LAST_TIME, nowTime do
				_DealWithOnce(i, nowTime)
			end
		else
			for i = LAST_TIME + 1, nowTime do
				_DealWithOnce(i, nowTime)
			end
		end
		LAST_TIME = nowTime
	end
end

skynet.start(function()
	skynet.dispatch("timer_event", function(session, source, cmd, ...)
		assert(session == 0, source)
		local f = assert(ACCEPT[cmd])
		f(source, ...)
	end)


	skynet.timeout(0, _DealWithTimer)
end)
