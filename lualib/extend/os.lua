local skynet = require "skynet"
local skytime = skynet.time
local mfloor = math.floor
local os = os
local table = table
local _ERROR = _ERROR

local original_ostime = os.time
local function fsntime(...)
	local agrcount = select("#", ...)
	if agrcount > 0 then
		return original_ostime(...)
	else
		return mfloor(skytime())
	end
end
os.time = fsntime

-- sDateTime的格式示例：2024-02-16 04:41:59
function os.Sec2DateStr(sDateTime)
	if type(sDateTime) ~= "string" or
		string.match(sDateTime, "%d+%-%d+%-%d+ %d+%:%d+%:%d+") == nil
	then
		if _ERROR then
			_ERROR("os Sec2DateStr args error!")
		else
			skynet.error("os Sec2DateStr args error!")	
		end
		return
	end

	local result = {}
	for k in string.gmatch(sDateTime, "%d+") do
		table.insert(result, k)
	end

	return os.time({
		year = result[1],
		month = result[2],
		day = result[3],
		hour = result[4],
		min = result[5],
		sec = result[6],
	})
end

