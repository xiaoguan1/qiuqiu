----------------------------------------
-- 创建者：Ghost
-- 创建日期: 2019/08/02
-- 模块作用: activity服务对象临时变量
----------------------------------------

local string = string
local paris = paris

local TmpVars = {

role = {
	"Name",
	"Sex",

	"BoxofficeSave",
	"Maze",
	"ChampionData",
	"ArenaMaxIntegral",
	"ArenaAttTotalWinCnt",
	"BattleShareCnt",
	"BattleShareTime",
	"ShieldRedChannel",
},

}

-- 将生成的内容插入到 "autogen-begin" 和 "autogen-end" 之前
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
		assert(sub == 1, string.format("must insert into the file: %s once", filePath))
	else
		error("not file:" .. filePath)
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

local SAVE_PATTERN_FORMAT = [[
if SERVICE_NAME == "%s" then
	function %s:Get%s()
		return self.%s.%s
	end
	function %s:Set%s(%s)
		self.%s.%s = %s
	end
else
	function %s:Get%s()
		return self.%s.%s
	end
	function %s:Set%s(%s)
		self.%s.%s = %s
	end
end
]]

-- 生成文件绑定属性
function BindFuncFile(className, varList, saveVarList, filePath)
	local varListStr = ""
	for _, _varName in pairs(varList) do
		local saveStr = nil
		local saveServiceName = nil
		if saveVarList[_varName] then
			saveStr = "__data"
			saveServiceName = saveVarList[_varName]
		else
			saveStr = "__tmp"
		end

		if className == "clsRole" and saveStr == "__data" then
			varListStr = varListStr .. string.format(SAVE_PATTERN_FORMAT,
				saveServiceName,
				className, _varName, saveStr, _varName,
				className, _varName, _varName, saveStr, _varName, _varName,
				className, _varName, "__tmp", _varName,
				className, _varName, _varName, "__tmp", _varName, _varName
			) .. "\n"
		else
			varListStr = varListStr .. string.format(VAR_PATTERN_FORMAT,
				className, _varName, saveStr, _varName,
				className, _varName, _varName, saveStr, _varName, _varName
			) .. "\n"
		end
	end
	GenFile(filePath, "\n" .. varListStr .. "\n")
end

function gen()
	for _, _oneVar in pairs(TmpVars) do
		for _, _varName in pairs(_oneVar) do
			-- 存盘需要简单的命名方式，方便阅读与修改
			if not string.match(_varName, "^[%a_][%w_]*$") then
				error(string.format("%s is not var name", _varName))
			end
		end
	end

	dofile("charvar/activity/db.lua")
	-- 绑定属性文件
	local roleKeyData = GetSaveVars_All("role")
	BindFuncFile("clsRole", TmpVars.role, roleKeyData, "service/activity/char/role/role.lua")
end

gen()