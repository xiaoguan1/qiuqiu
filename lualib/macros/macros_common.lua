local skynet = require "skynet"

ONE_DAY_SEC = 86400		-- 一天的时间秒数
ONE_WEEK_SEC = 604800 	-- 一周的时间秒数

-- 节点类型
GAME_NODE_TYPE = "game_node"	-- 普通游戏服节点
CROSS_NODE_TYPE = "cross_node"	-- 普通跨服节点

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
	DATABASE_BASEDIR = "../data/unknow/"
	ROOT_DATABASE_BASEDIR = "data/unknow/"
end

THRESHOLD_DATALEN = 4 * 1024 * 1024			-- 数据库存盘，4m的警报阈值
E_THRESHOLD_DATALEN = 16 * 1024 * 1024		-- 数据库存盘，16m的错误阈值
SAVE_SPLIT_MAXCNT = 2048					-- 拆分存盘最大数量

LIST_BASEPATH = DATABASE_BASEDIR .. "list"
ROLE_BASEPATH = DATABASE_BASEDIR .. "role"
MOD_BASEPATH = DATABASE_BASEDIR .. "dat"
ROLEACT_BASEPATH = DATABASE_BASEDIR .. "roleact"
RECORD_BASEPATH = DATABASE_BASEDIR .."record"
CHEATRECORD_BASEPATH = DATABASE_BASEDIR .. "cheatrecord"
SVRBATTLE_TMPBASEDIR = DATABASE_BASEDIR .. "tmprecord"
RESULTRECORD_BASEPATH = DATABASE_BASEDIR .. "resultrecord"
ROOT_CHEATRECORD_BASEPATH = DATABASE_BASEDIR .. "cheatrecord"
