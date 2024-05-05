local skynet = require "skynet"

ONE_DAY_SEC = 86400		-- 一天的时间秒数
ONE_WEEK_SEC = 604800 	-- 一周的时间秒数


GCPERFORM_STEP = 64

MYSQL_FIELDTYPE_MAP = {
	["int(11)"] 		= "number",
	["double(16,2)"] 	= "number",
	["bigint(20)"] 		= "number",
	["varchar(32)"] 	= "string",
	["varchar(64)"] 	= "string",
	["varchar(128)"] 	= "string",
	["varchar(256)"] 	= "string",
	["text"] 			= "string", -- 64K
}

LOG_MODIFY_COLUMN = {					-- 日志修改列
	heroexp_change = {
		["old_heroexp"] = "int(11)",
		["new_heroexp"] = "int(11)",
		["amount"] = "int(11)",
	},
	reward_cash = {
		["cash"] = "int(11)",
	},
	["*"] = {
		["timestamp"] = "timestamp", 	-- 时间戳 timestamp 为旧的类型
	}
}

local DATA_DIRNAME = skynet.getenv("data_dirname") or skynet.getenv("node")
assert(DATA_DIRNAME)
DATABASE_BASEDIR = nil
ROOT_DATABASE_BASEDIR = nil
if DATABASE_BASEDIR then
	DATABASE_BASEDIR = "../data/" .. DATA_DIRNAME .. "/"
	ROOT_DATABASE_BASEDIR = "data/" .. DATA_DIRNAME .. "/"
else
	DATABASE_BASEDIR = "../data/unknow"
	ROOT_DATABASE_BASEDIR = "data/unknow"
end

LIST_BASEPATH = DATABASE_BASEDIR .. "list"
ROLE_BASEPATH = DATABASE_BASEDIR .. "role"
MOD_BASEPATH = DATABASE_BASEDIR .. "dat"
ROLEACT_BASEPATH = DATABASE_BASEDIR .. "roleact"
RECORD_BASEPATH = DATABASE_BASEDIR .."record"
CHEATRECORD_BASEPATH = DATABASE_BASEDIR .. "cheatrecord"
SVRBATTLE_TMPBASEDIR = DATABASE_BASEDIR .. "tmprecord"
RESULTRECORD_BASEPATH = DATABASE_BASEDIR .. "resultrecord"
ROOT_CHEATRECORD_BASEPATH = DATABASE_BASEDIR .. "cheatrecord"

