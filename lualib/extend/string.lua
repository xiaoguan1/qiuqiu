local string = string
local type = type

--作用：切割字符串
--参数: str:待切割的字符串，reps:以那个字符作为切割点，retIndex:指定坐标返回
--返回值：string or nil | table
function string.split(str, reps, retIndex)
	if type(str) ~= "string" then return end

	local retList = {}
	string.gsub( str, "[^".. reps .."]+", function(splitstr) retList[#retList + 1] = splitstr end )

	if retIndex then return retList[retIndex] end
	return retList
end

-- 判断一个字符串是否以 begins参数 开始
function string.beginswith(str, begins)
	local i, j = string.find(str, begins, 1, true)
	return i and (i == 1)
end