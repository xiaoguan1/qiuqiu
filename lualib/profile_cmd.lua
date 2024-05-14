--------------------------------
-- 创建者：Ghost
-- 创建日期：2019/08/02
-- 模块作用：功能模块性能检测
--------------------------------

local skynet = require "skynet"
local os = os
local profile = require "skynet.profile"
local profile_cmd = (skynet.getenv("profile_cmd") == "true") and true or false

PROFILE_DATA = {
	sTime = nil,
	eTime = nil,
	reportData = {},
}
IsRecord = profile_cmd

function Profile_On()
	IsRecord = true
	PROFILE_DATA.sTime = os.date("%Y/%m/%d %H:%M:%S")
	PROFILE_DATA.eTime = nil
	PROFILE_DATA.reportData = {}
end

function Profile_Off()
	IsRecord = false
	PROFILE_DATA.eTime = os.date("%Y/%m/%d %H:%M:%S")
end

function Profile_InfoString()
	local info = string.format("start time:\t%s\nend time:\t%s\n", PROFILE_DATA.sTime, PROFILE_DATA.eTime)
	info = info .. sys.dumptree(PROFILE_DATA.reportData)
	return info
end

function Profile_Info()
	return PROFILE_DATA
end

function CmdCal_S()
	if IsRecord then
		profile.start()
	end
end

function CmdCal_E(cmd)
	if not IsRecord then return end

	local time = profile.stop()
	local p = PROFILE_DATA.reportData[cmd]
	if p == nil then
		p = { n = 0, ti = 0, max_ti = nil, min_ti = nil }
		PROFILE_DATA.reportData[cmd] = p
	end
	p.n = p.n + 1
	p.ti = p.ti + time
	if p.max_ti then
		if time > p.max_ti then
			p.max_ti = time
		end
	else
		p.max_ti = time
	end
	if p.min_ti then
		if time < p.min_ti then
			if time < p.min_ti then
				p.min_ti = time
			end
		else
			p.min_ti = time
		end
	end
end

if IsRecord then
	if not PROFILE_DATA.sTime then
		Profile_On()
	end
end
