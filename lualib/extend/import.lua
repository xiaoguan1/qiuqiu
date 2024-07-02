local skynet = require "skynet"
local skyerror = skynet.error
local core = require "skynet.core"
local SERVICE_NAME = SERVICE_NAME

local _SOURCE_G = core.serviceG() -- 当前服务的全局环境表 _G
local pcall = _SOURCE_G.pcall
local error = _SOURCE_G.error
local setmetatable = _SOURCE_G.setmetatable
local rawset = _SOURCE_G.rawset
local sformat = _SOURCE_G.string.format
local loadfile = _SOURCE_G.loadfile
local type = _SOURCE_G.type

local LoadModule = {} -- 已加载的模块

function _SOURCE_G.Import(filepath)
	if not filepath then
		error("Import not filepath!!!")
	end

	if LoadModule[filepath] then
		return LoadModule[filepath]
	end

	local rltFilepath = "./" .. filepath
	local _fileG = {}

	setmetatable(_fileG, {
		__index = core.serviceG(),
		__newindex = function(_fileG, key, value)
			rawset(_fileG, key, value)
		end,
	})

	local filebody, err = loadfile(rltFilepath, "bt", _fileG)
	if not filebody then
		_ERROR(err)
		error(debug.traceback())
	end

	local isOk, err = pcall(filebody)
	if not isOk then
		skyerror(err)
		return
	end

	if _fileG.__init__ then
		if type(_fileG.__init__) ~= "function" then
			error("__init__ must is function")
		end
		_fileG.__init__()
	end

	LoadModule[filepath] = _fileG
	return _fileG
end

-- 成功起服后，统一跑__startup__方法
function Startup()
	for _, _fileG in pairs(LoadModule) do
		if _fileG.__startup__ then
			if type(_fileG.__startup__) ~= "function" then
				error("__startup__ must is function")
			end
			_fileG.__startup__()
		end
	end
end

-- __init__ 和 __startup__ 方法等