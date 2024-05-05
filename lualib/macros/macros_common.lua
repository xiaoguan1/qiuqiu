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