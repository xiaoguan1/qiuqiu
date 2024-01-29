-- 相关资料笔记 有道云搜索："控制台终端颜色输出（日志）"
local skynet = require "skynet"
local debug = debug
local table = table
local tconcat = table.concat
local os_date = os.date
local print = print
local sformat = string.format
local stat = stat
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
	SERVICE_INFO = sformat( "%s %0x ", SERVICE_NAME, skynet.self())
end


-- 被调用的函数信息
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


-- 输出格式以及颜色
local _LEVEL_COLOR = {
	[1] = INFO_M,
	[2] = WARN_M,
	[3] = ERROR_M
}

local _INFO_CONTEXT = {
	"nil",
	"[INFO]",
	"nil",
	"nil",
}
local _WARN_CONTEXT = {
	"nil",
	"[WARN]",
	"nil",
	"nil",
}
local _ERROR_CONTEXT = {
	"nil",
	"[ERROR]",
	"nil",
	"nil",
}
local function _info_context(fileInfo, msg)
	_INFO_CONTEXT[1] = os_date("%Y-%m-%d %H:%M:%S")
	_INFO_CONTEXT[3] = fileInfo
	_INFO_CONTEXT[4] = msg
	return tconcat( _INFO_CONTEXT, " ")
end
local function _warn_context(fileInfo, msg)
	_WARN_CONTEXT[1] = os_date("%Y-%m-%d %H:%M:%S")
	_WARN_CONTEXT[3] = fileInfo
	_WARN_CONTEXT[4] = msg
	return tconcat( _WARN_CONTEXT, " ")
end
local function _error_context(fileInfo, msg)
	_ERROR_CONTEXT[1] = os_date("%Y-%m-%d %H:%M:%S")
	_ERROR_CONTEXT[3] = fileInfo
	_ERROR_CONTEXT[4] = msg
	return tconcat(_ERROR_CONTEXT, " ")
end


-- 文件句柄信息
local LOG_FILE_OBJ, WARN_FILE_OBJ, ERROR_FILE_OBJ
local _INFO_LOG_PATH = {
	"./log/info/",
	"info_",
	"nil",
	".txt",
}
local _WARN_LOG_PATH = {
	"./log/warn/",
	"warn_",
	"nil",
	".txt",
}
local _ERROR_LOG_PATH = {
	"./log/error/",
	"error_",
	"nil",
	".txt",
}

-- 日志输出
local function _log_info(context)
	if not LOG_FILE_OBJ or not io.type(LOG_FILE_OBJ) then
		if not stat.is_dir(_INFO_LOG_PATH[1]) then
			os.execute("mkdir " .. _INFO_LOG_PATH[1])
		end
		_INFO_LOG_PATH[3] = os_date("%Y%m%d")
		LOG_FILE_OBJ = io.open(tconcat(_INFO_LOG_PATH), "a+")
	end
	LOG_FILE_OBJ:write(context, "\n")
end
local function _log_warn(context)
	if not WARN_FILE_OBJ or not io.type(WARN_FILE_OBJ) then
		if not stat.is_dir(_WARN_LOG_PATH[1]) then
			os.execute("mkdir " .. _WARN_LOG_PATH[1])
		end
		_WARN_LOG_PATH[3] = os_date("%Y%m%d")
		WARN_FILE_OBJ = io.open(tconcat(_WARN_LOG_PATH), "a+")
	end
	WARN_FILE_OBJ:write(context, "\n")
end
local function _log_error(context)
	if not ERROR_FILE_OBJ or not io.type(ERROR_FILE_OBJ) then
		if not stat.is_dir(_ERROR_LOG_PATH[1]) then
			os.execute("mkdir " .. _ERROR_LOG_PATH[1])
		end
		_ERROR_LOG_PATH[3] = os_date("%Y%m%d")
		ERROR_FILE_OBJ = io.open(tconcat(_ERROR_LOG_PATH), "a+")
	end
	ERROR_FILE_OBJ:write(context, "\n")
end

-- 控制台打印
local function _log_print(level, context)
	local color = level and _LEVEL_COLOR[level]
	assert(color, "level is error!")
	print(tconcat({ color, context, END_FORMAT, }))
end


---- 外部接口 ------------------------------------------------------------------------

function _INFO(...)
	local context = _info_context(FileInfo(), ...)
	if logStdin then
		_log_print(1, context)
	end
	_log_info( context)
end
function _INFO_F(fmt, ...)
	local context = _info_context(FileInfo(), string.format(fmt, ...))
	if logStdin then
		_log_print(1, context)
	end
	_log_info( context)
end


function _WARN(...)
	local context = _warn_context(FileInfo(), ...)
	if logStdin then
		_log_print(2, context)
	end
	_log_warn(context)
end
function _WARN_F(fmt, ...)
	local context = _warn_context(FileInfo(), string.format(fmt, ...))
	if logStdin then
		_log_print(2, context)
	end
	_log_warn(context)
end


function _ERROR(...)
	local context = _error_context(FileInfo(), ...)
	if logStdin then
		_log_print(3, context)
	end
	_log_error(context)
end
function _ERROR_F(fmt, ...)
	local context = _error_context(FileInfo(), string.format(fmt, ...))
	if logStdin then
		_log_print(3, context)
	end
	_log_error(context)
end


-- 缺一个定时器，时间去到第二天的时候更换日志文件