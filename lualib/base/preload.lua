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