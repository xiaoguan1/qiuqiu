---------------------
-- 创建日期：2023.1.8
-- 模块作用：agent服务对象临时数据
---------------------

local string = string
local pairs = pairs

local TmpVars = {}

TmpVars.role = {
    "playerid",                     -- 玩家id
    "coin",                         -- 金币
    "name",                         -- 名字
    "level",                        -- 等级
    "last_login_time",              -- 最近一次登录的时间
}


function GenFile(filePath, data)
    local path = string.match(filePath, ".+%.lua")
    if not path then return end

    local content
    local rf = io.open(filePath, "r")
    if rf then 
        content = rf:read("*a")
        rf:close()
    end

    if content then
        local sub
        data, sub = string.gsub(content, "(%-%-autogen%-begin).-(%-%-autogen%-end)", "%1" .. data .. "%2")
        assert(sub == 1, string.format("must insert into file: %s once", filePath))
    else
        error("not file: " .. filePath)
    end

    local fd = assert(io.open(filePath, "w"))
    fd:write(data)
    fd:flush()
    fd:close()
end

local VAR_PATTERN_FORMAT = [[
function %s:Get%s()
    return self.%s.%s
end
function %s:Set%s(%s)
    self.%s.%s = %s
end
]]


function table_member_key(Table, Value)
    for k, v in pairs(Table) do
        if v == Value then return k end
    end
end

-- 生成文件绑定属性
function BindFuncFile(className, varList, saveVarList, filePath)
    local varListStr = ""
    for _, _varName in pairs(varList) do
        local saveStr = table_member_key(saveVarList, _varName) and "__data" or "__tmp"

        varListStr = varListStr .. string.format(VAR_PATTERN_FORMAT,
            className, _varName, saveStr, _varName,
            className, _varName, _varName, saveStr, _varName, _varName
        )
    end

    GenFile(filePath, "\n" .. varListStr .. "\n")
end

function gen()
    for _, _oneVar in pairs(TmpVars) do
        for _, _varName in pairs(_oneVar) do
            -- 存盘需要简单的命名方式，方便阅读与修改
            if not string.match(_varName, "^[%a_][%w_]*$") then
                error(string.format("%s is not valid var name", _varName))
            end
        end
    end

    dofile("charvar/agent/db.lua")

    -- 绑定属性文件
    BindFuncFile("clsRole", TmpVars.role, assert(GetSaveVars("role")), "service/agent/char/role/role.lua")
end

gen()   -- 直接生成