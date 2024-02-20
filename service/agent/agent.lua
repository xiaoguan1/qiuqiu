local skynet = require "skynet"

skynet.start(function ()
	dofile("./service/agent/scene.lua")
	dofile("./service/agent/init/loading.lua")

	local db = DATABASECOMMON.Getdb(DATABASE_NAME.MESSAGE_BOARD) -- 获取数据库句柄（这里是登录，不是创角）
    data = { coin = 100, hp = 200, }

	skynet.dispatch("lua", function (session, address, cmd, ...)
		local fun = PROTO_FUN[cmd]
		if not fun then
			-- 后续补上错误打印
			print(string.format("[%s] [session:%s], [cmd:%s] not find fun.", SERVICE_NAME, session, cmd))
			return
		end
		if session == 0 then
			xpcall(fun, traceback, address, ...)
		else
			local ret = table.pack(xpcall(fun, traceback, address, ...))
			local isOk = ret[1]
			if not isOk then
				skynet.ret()
				return
			end
			skynet.retpack(table.unpack(ret, 2))
		end
	end)
end)