local skynet = require "skynet"
local xls_setting_path = skynet.getenv("xls_setting") or "./setting"
local LOADFILE_CFG = {

-- 需要加载的文件(setting目录下的)
"robot/robot.lua",
"log/log_data.lua",
"sync/sync_data.lua",
}

local LOADFILE_CFG_MAP = {}
for _, _file in pairs(LOADFILE_CFG) do
	if string.beginswith(_file, "./") then
		_file = string.sub(_file, 3)
	end
	local tFile = xls_setting_path .. "/" .. _file
	LOADFILE_CFG_MAP[tFile] = true
end

OLD_LOADFILE_CFG_MAP = {}
for _file, _ in pairs(LOADFILE_CFG_MAP) do
	OLD_LOADFILE_CFG_MAP[_file] = true
end

function GetLoadSettingFilesMap()
	return LOADFILE_CFG_MAP
end

function GetLoadSettingFiles()
	return LOADFILE_CFG
end

-- 热更
function __update__()
	for _file, _ in pairs(LOADFILE_CFG_MAP) do
		if not OLD_LOADFILE_CFG_MAP[_file] then
			OLD_LOADFILE_CFG_MAP[_file] = true
			-- 新旧对比，如果少了的则加载
			CMD.UpdateFile(_file)
		end
	end
end