if not _G then
	error("not find _G")
end

function _G.Import(filepath)
	if not filepath then
		error("Improt not filepath!!!")
	end

	local _fileG = {}
	local _fileMT = {
		__index = _G,
		__newindex = function(_fileG, key, value)
			rawset(_fileG, key, value)
		end	
	}
	setmetatable(_fileG, _fileMT)

	local filebody = loadfile(filepath, "bt", _fileG)
	if not filebody then
		error(string.format("import filepath:%s error", filepath))
	end

	filebody()

	return _fileG
end

-- __init__ 和 __startup__ 方法等