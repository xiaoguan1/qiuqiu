-- 命名规则 DATABASE_表名_字段名

local ROLES = {}

ROLES.DATABASE_ROLES_DATA = {
    "playerid",                     -- 玩家id
    "coin",                         -- 金币
    "name",                         -- 名字
    "level",                        -- 等级
    "last_login_time",              -- 最近一次登录的时间
}

function GetSaveVars(tableName)
    return ROLES[tableName]
end