local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
require "skynet.manager"
local Import = Import

CMD = {}

skynet.start(function ()
	-- 添加CMD指令能更新数据表格
	skynet.dispatch("lua", function (session, source, command, ...)
		local f = assert(CMD[command])
		if session == 0 then
			f(...)
		else
			skynet.retpack(f(...))
		end
	end)
	DATA_MGR = Import("service/loadxls/data_mgr.lua")
	DATA_MGR.LoadFile()
	DATA_MGR.LoadDatabase()
end)


