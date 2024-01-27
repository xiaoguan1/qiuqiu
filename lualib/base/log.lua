-- 相关资料笔记 有道云搜索："控制台终端颜色输出（日志）"
local skynet = require "skynet"
local debug = debug
local table = table
local tconcat = table.concat
local os_date = os.date
local logStdin = skynet.getenv("log_stdin") == "true"
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
local SERVICE_INFO
if not INFO_M then
	INFO_M = HEADER ..  FONTCOLOUR.Black .. BACKGROUNDCOLOUR.Green .. "m"
end
if not WARN_M then
	WARN_M = HEADER ..  FONTCOLOUR.Black .. BACKGROUNDCOLOUR.Yellow .. "m"
end
if not ERROR_M then
	ERROR_M = HEADER ..  FONTCOLOUR.Black .. BACKGROUNDCOLOUR.Red .. "m"
end
if not SERVICE_INFO then
	SERVICE_INFO = string.format( "%s %0x ", SERVICE_NAME, skynet.self())
end

local _FILE_INFO_T = {
	"<",
	SERVICE_INFO,
	"nil",
	":",
	"nil",
	">",
}

local function FileInfo(deep)
	local debugInfo = debug.getinfo(deep or 3, "Sl")
	_FILE_INFO_T[3] = debugInfo.short_src
	_FILE_INFO_T[5] = debugInfo.currentline
	return tconcat(_FILE_INFO_T)
end


---- 外部接口 ------------------------------------------------------------------------

function _INFO(...)
	local context = string.format(INFO_M .. "[%s] [ERROR] %s %s" .. END_FORMAT, os_date("%Y-%m-%d %H:%M:%S"), FileInfo(), ... )
	if logStdin then
		print(context)
	end
	-- 输出到对应日期的日志文件上
end

function _WARN(...)
	local context = string.format(WARN_M .. "[%s] [ERROR] %s %s" .. END_FORMAT, os_date("%Y-%m-%d %H:%M:%S"), FileInfo(), ... )
	if logStdin then
		print(context)
	end
	-- 输出到对应日期的日志文件上
end

function _ERROR(...)
	local context = string.format(ERROR_M .. "[%s] [ERROR] %s %s" .. END_FORMAT, os_date("%Y-%m-%d %H:%M:%S"), FileInfo(), ... )
	if logStdin then
		print(context)
	end
	-- 输出到对应日期的日志文件上
end

_INFO("aaaaaa")
_WARN("qqqq")
_ERROR("wwww")
