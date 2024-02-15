local skynet = require "skynet"
local os = os
local table = table
local _ERROR = _ERROR

-- 2024-02-16 04:41:59
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

