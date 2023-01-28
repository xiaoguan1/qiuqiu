local skynet = require "skynet"

-- 加载文件路径(先加载不依赖外部数据的模块)
local LOAD_FILES = {
    -- 常量（不依赖其他模块的变量）
    "./lualib/base/database_macro.lua",

    -- 协议
    "./protobuf/protoload/loadproto.lua",

    -- 拓展
    "./lualib/extend/string.lua",
    "./lualib/extend/table.lua",
}

for _, filepath in pairs(LOAD_FILES) do
    dofile(filepath)
end

-- 注册的协议
skynet.register_protocol({
    name = "timer_event",
    id = skynet.PTYPE_TIMER_EVENT,
    unpack = skynet.unpack,
    pack = skynet.pack,
})

if not setfenv then
    -- base on http://lua-users.org/lists/lua-l/2010-06/msg00314.html
    -- this assumes f is a function
    local function findenv(f)
        local level = 1
        repeat
            local name, value = debug.getupvalue(f, level)
            if name == '_ENV' then
                return level, value
            end
            level = level + 1
        until name == nil
        return nil
    end

    getfenv =  function (f)
        if type(f) == "number" then
            f = debug.getinfo(f + 1, 'f').func
        end
        if f then
            return select(2, findenv(f))
        else
            return _G
        end
    end

    setfenv = function (f, t)
        local level = findenv(f)
        if level then debug.setupvalue(f, level, t) end
        return f
    end
end