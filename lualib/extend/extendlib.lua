-- 目的：针对lua现有的库进行拓展、或新增库。

-- 加载文件路径(先加载不依赖外部数据的模块)
local LOAD_FILES = {
    -- 拓展
    "./lualib/extend/string.lua",
    "./lualib/extend/table.lua",
}

for _, filepath in pairs(LOAD_FILES) do
    dofile(filepath)
end