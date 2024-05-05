local skynet = require "skynet"
local string = string
local error = error
local assets = assert
local os = os
local io = io
local is_filedb = (skynet.getenv("is_filedb") == "true" and true or false)
local not_loaderrdb = (skynet.getenv("load_errdb") == "false") and true or false
local DATABASE_COMMON = Import("global/database_common.lua")

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
	if not 
	
end