local skynet = require "skynet"
local string = string
local error = error
local assets = assert
local os = os
local io = io
local file = file
local is_filedb = (skynet.getenv("is_filedb") == "true" and true or false)
local not_loaderrdb = (skynet.getenv("load_errdb") == "false") and true or false
local DATABASE_COMMON = Import("lualib/database_common.lua")

local DATABASE_BASEDIR = DATABASE_BASEDIR
local LIST_BASEPATH = LIST_BASEPATH
local ROLE_BASEPATH = ROLE_BASEPATH
local MOD_BASEPATH = MOD_BASEPATH
local ROLEACT_BASEPATH = ROLEACT_BASEPATH

local function _RestoreDataFromFile(fileName)
	local fh, err = io.open(fileName)
	if not fh then
		error("not open file:" .. fileName)
	end
	local data = fh:read("*a")
	fh:close()
	return assets(load("return" .. data)())
end

local function _CheckPath(dname, path)
	if not file.detailed(path) then return end
	for file in posix.files(path) do
		if file ~= "." and file ~= ".." and file ~= ".svn" then
			local pathFile = path .. "/" ..file
			local fileType = posix.stat(pathFile).type

			if fileType == "dir" then
				_CheckPath(dname, pathFile)
			elseif fileType == "file" then
				if string.endswith(pathFile, ".dat") then
					if dname == "list" then
						local sp = string.split(pathFile, "/")
						local urs = string.split(sp[#sp], ".dat")[1]
						assets(urs)
						local data = _RestoreDataFromFile(pathFile)
						DATABASE_COMMON.Call_ListSave(urs, data)
						skynet.error(string.format("restore urs:%s file:%s to database", urs, pathFile))
					elseif dname == "role" then
						local sp = string.split(pathFile, "/")
						local uid = string.split(sp[#sp], ".dat")[1]
						assets(uid)
						local data = _RestoreDataFromFile(pathFile)
						DATABASE_COMMON.Call_RoleSave(uid, data)
						skynet.error(string.format("restore uid:%s file:%s to database", uid, pathFile))
					elseif dname == "roleact" then
						local sp = string.split(pathFile, "/roleact/")
						table.remove(sp, 1)
						sp = table.concat(sp, "/roleact/")
						local tmp = string.split(sp, "/")
						table.remove(tmp, 1)
						table.remove(tmp, 1)
						local uid = table.remove(tmp, 1)
						local actName = string.split(table.concat(tmp, "/"), ".dat")[1]
						assets(uid)
						assets(actName)
						local data = _RestoreDataFromFile(pathFile)
						DATABASE_COMMON.Call_RoleActSave(uid, data, actName)
						skynet.error(string.format("restore role:%s actName:%s file:%s to database", uid, actName, pathFile))
					elseif dname == "mod" then
						local sp = string.split(pathFile, "/dat/")
						table.remove(sp, 1)
						sp = table.concat(sp, "/dat/")
						local mod = string.split(sp, ".dat")[1]
						assets(mod)
						local data = _RestoreDataFromFile(pathFile)
						DATABASE_COMMON.Call_ModSave(mod, data)
						skynet.error(string.format("restore mod:%s file:%s to database", mod, pathFile))
					else
						error("not dname: " .. dname)
					end
					local ok, msg = os.remove(pathFile)
					if not ok then
						local msg = string.format("remove restore file:%s error:%s", pathFile, msg)
						error(msg)
					end
				else
					local msg = string.format("database check file:%s not .dat", pathFile)
					error(msg)
				end
			else
				local msg = string.format("database check file:%s, fileType:%s error", pathFile, fileType)
			end
		end
	end
end

function StartUpCheck()
	if not is_filedb and not not_loaderrdb then
		_CheckPath("list", LIST_BASEPATH)
		_CheckPath("role", ROLE_BASEPATH)
		_CheckPath("roleact", ROLEACT_BASEPATH)
		_CheckPath("mod", MOD_BASEPATH)
	end
end