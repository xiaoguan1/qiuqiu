local skynet = require "skynet"
local pcall = pcall
local error = error
local setmetatable = setmetatable
local rawset = rawset
local sformat = string.format
local skyerror = skynet.error
local loadfile = loadfile
local core = require "skynet.core"

local _SG = core.service_g() -- 当前服务的全局环境表 _G

if not _SG.Import then
	_SG.Import = function(filepath)
		if not filepath then
			error("Improt not filepath!!!")
		end

		local rltFilepath = "./" .. filepath
		local _fileG = {}

		setmetatable(_fileG, {
			__index = core.service_g(),
			__newindex = function(_fileG, key, value)
				rawset(_fileG, key, value)
			end
		})

		local filebody = loadfile(rltFilepath, "bt", _fileG)
		if not filebody then
			error(sformat("import filepath:%s error", filepath))
		end

		local isOk, err = pcall(filebody)
		if not isOk then
			skyerror(err)
			return
		end

		return _fileG
	end
end

-- __init__ 和 __startup__ 方法等