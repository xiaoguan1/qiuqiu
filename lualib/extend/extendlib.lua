-- 目的：针对lua现有的库进行拓展、或新增库。
local skynet = require "skynet"

-- 加载文件路径(先加载不依赖外部数据的模块)
local LOAD_FILES = {
	-- 拓展
	"./lualib/extend/string.lua",
	"./lualib/extend/table.lua",
	"./lualib/extend/sys.lua",
	"./lualib/extend/stat.lua",
	"./lualib/extend/common.lua",
}

for _, filepath in pairs(LOAD_FILES) do
	dofile(filepath)
end

-- 不在loslib.c文件对os库进行拓展，是为了方便后续lua版本的升级。
os.realtime = skynet.time