local skynet = require "skynet"
local Import = Import

local EVERY_NODE_SERVER = EVERY_NODE_SERVER
local _localname = EVERY_NODE_SERVER and EVERY_NODE_SERVER.database and EVERY_NODE_SERVER.database.named
if not _localname then
	error("database service not localname")
end

local parg = { ... }
if skynet.localname(_localname) then
	DB_MGRNO = tonumber(parg[1])
	DB_NO = tonumber(parg[2])
	Import("service/database/database_s.lua")
else
	Import("service/database/database_f.lua")
end