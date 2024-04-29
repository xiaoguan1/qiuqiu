local skynet = require "skynet"
local node = skynet.getenv("node")

client = {}

PROTO_FUN = {}

skynet.start(function(...)
	dofile("./service/login/init/loading.lua")

	skynet.dispatch("lua", function(session, address, cmd, ...)
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


-- 创角
PROTO_FUN.client = function (source, fd, cmd, msg)
	if PROTO_FUN[cmd] then
		local ret_msg = PROTO_FUN[cmd](fd, msg, source)
		skynet.send(source, "lua", "send_by_fd", fd, ret_msg)
	else
		_INFO_F("s.resp.client fail, cmd:%s msg:%s", cmd, msg)
	end
end

-- 协议处理
PROTO_FUN.login = function(fd, msg, source)
	local databasesvr = PROXYSVR.GetProxy(".database", "dboperate")
	if not databasesvr then
		return {"login", 1, "数据库错误"}
	end

	-- 账号和密码默认为字符串类型
	local account, passwd = tostring(msg[2]), tostring(msg[3])
	local gate = source

	local result = databasesvr.call.CheckAccount(account, passwd)
	if not result then return {"login", 1, "帐号或密码错误！！！"} end

	-- 发消息给agentmgr
	local isOk, agent = skynet.call("agentmgr", "lua", "reqlogin", account, node, gate)
	if not isOk then return {"login", 1, "请求mgr失败"} end

	-- 回应gateway
	local isOk = skynet.call(gate, "lua", "sure_agent", fd, account, agent)
	if not isOk then
		--skynet.send("agentmgr", "lua", "reqkick", source, playerid, reason)
		return {"login", 1, "gate注册失败"}
	end

	_INFO_F("login succ %s", account)
	return {"login", 0, "登录成功"}
end

-- 创角
PROTO_FUN.create = function(fd, msg, source)
	local databasesvr = PROXYSVR.GetProxy(".database", "dboperate")
	if not databasesvr then
		return {"login", 1, "数据库错误"}
	end

	-- 账号和密码默认为字符串类型
	local playerId, passwd = tostring(msg[2]), tostring(msg[3])

	local result = databasesvr.call.IsHasPlayer(playerId)
	if result then return {"create", 1, "帐号已存在！！！"} end

	local result = databasesvr.call.AddRoles(playerId, passwd)
	if result then return {"create", 1, "创角成功！！！"} end
end