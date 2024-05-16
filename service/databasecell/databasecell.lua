local skynet = require "skynet"
local PROFILE_CMD = Import("lualib/profile_cmd.lua")
local Import = Import

local parg = {...}
DB_MGRNO = tonumber(parg[1])
DB_NO = tonumber(parg[2])

ACCEPT, RESPONSE = {}, {}

skynet.start(function ()
	CALLOUT = Import("lualib/call_out.lua")
	DBSAVE = Import("service/databasecell/dbsave.lua")

	skynet.dispatch("lua", function (session, source, command, ...)
		local f
		local isRecord = PROFILE_CMD.CmdCal_S()
		if session == 0 then
			f = assert(ACCEPT[command])
			f(...)
		else
			f = assert(RESPONSE[command])	-- 不在本服务回复
			if command == "closedb" then
				if source ~= DB_MGRNO then	-- 不是mgr控制关闭的
					return
				end
				skynet.retpack(f(...))
			else
				skynet.retpack(f(...))
			end
		end
		DBSAVE.CheckEnd()
		if isRecord then
			PROFILE_CMD.CmdCal_S(command)
		end
	end)
	DBSAVE.StartDb()
end)
