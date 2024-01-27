-- 相关资料笔记 有道云搜索："控制台终端颜色输出（日志）"

local HEADER = "\27"
local END_FORMAT = "\27[0m"

-- 前景颜色(字体颜色)
local FONTCOLOUR = {
	Black	=	"[30",		-- 黑色
	Red		= 	"[31",		-- 红色
	Green	=	"[32",		-- 绿色
	Yellow	=	"[33",		-- 黄色
	Blue	=	"[34",		-- 蓝色
	Purple	=	"[35",		-- 紫色
	Cyan	=	"[36",		-- 青色
	White	=	"[37",		-- 白色
}

-- 背景颜色
local BACKGROUNDCOLOUR = {
	Black	=	";40",		-- 黑色
	Red		=	";41",		-- 红色
	Green	=	";42",		-- 绿色
	Yellow	=	";43",		-- 黄色
	Blue	=	";44",		-- 蓝色
	Purple	=	";45",		-- 紫色
	Cyan	=	";46",		-- 青色
	White	=	";47",		-- 白色
}

local INFO_M
local WARN_M
local ERROR_M

if not INFO_M then
	INFO_M = HEADER ..  FONTCOLOUR.Black .. BACKGROUNDCOLOUR.Green .. "m"
end
if not WARN_M then
	WARN_M = HEADER ..  FONTCOLOUR.Black .. BACKGROUNDCOLOUR.Yellow .. "m"
end
if not ERROR_M then
	ERROR_M = HEADER ..  FONTCOLOUR.Black .. BACKGROUNDCOLOUR.Red .. "m"
end

local a = os.date("%Y-%m-%d")
print(INFO_M .. a .. END_FORMAT)
print(WARN_M .. a .. END_FORMAT)
print(ERROR_M .. a .. END_FORMAT)


