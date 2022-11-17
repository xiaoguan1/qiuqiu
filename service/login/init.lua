local skynet = require "skynet"
local s = require "service"
local CommonDB = require "common_db"
local log = require "common_log"
local node = skynet.getenv("node")

s.client = {}

PROTO_FUN = {}

s.after = function()
	-- 主要处理协议加载
	-- dofile("./service/login/aa.lua")
end

s.start(...)

-- 创角
PROTO_FUN.client = function (source, fd, cmd, msg)
	if PROTO_FUN[cmd] then
		local ret_msg = PROTO_FUN[cmd](fd, msg, source)
		skynet.send(source, "lua", "send_by_fd", fd, ret_msg)
	else
		skynet.error("s.resp.client fail", cmd, msg)
	end
end

-- 协议处理
PROTO_FUN.login = function(fd, msg, source)
	-- 账号和密码默认为字符串类型
	local account, passwd = tostring(msg[2]), tostring(msg[3])
	local gate = source

	-- 获取数据库句柄（这里是登录，不是创角）
	local db = CommonDB.Getdb()
	if not db then return {"login", 1, "登录失败！！！"} end

	local result = CommonDB.check_account(account, passwd, db)
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

	skynet.error("login succ " .. account)
	return {"login", 0, "登录成功"}
end

-- 创角
PROTO_FUN.create = function(fd, msg, source)
	-- 账号和密码默认为字符串类型
	local account, passwd = tostring(msg[2]), tostring(msg[3])
	local gate = source

	-- 获取数据库句柄（创角）
	local db = CommonDB.Getdb()
	if not db then return {"create", 1, "创角失败！！！"} end

	local result = CommonDB.isHas(account, passwd, db)
	if result then return {"create", 1, "帐号已存在！！！"} end

	result = CommonDB.insert(account, passwd, db)
	if result then return {"create", 1, "创角成功！！！"} end
end