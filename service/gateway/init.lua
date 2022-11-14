local skynet = require "skynet"
local s = require "service"
local socket = require "skynet.socket"
local runconfig = require "runconfig"
local msgpack = require "msg_pack"
local log = require "common_log"

conns = {}	-- { [fd] = conn, ... }
players = {}	-- { [playerId] = gateplayer, ...}

-- 连接类
function conn()
	local m = {
		fd = nil,
		playerid = nil,
	}
	return m
end

-- 玩家类
function gateplayer()
	local m = {
		playerid = nil,
		agent = nil,
		conn = nil,
	}
	return m
end

-- 登出
local disconnect = function(fd)
	local c = conns[fd]
	if not c then return end

	-- playerid不为空时代表处于登录中
	local playerid = c.playerid
	if not playerid then
		return
	else
		player[playerid] = nil
		local reason = "断线"
		skynet.call("agentmgr", "lua", "reqkick", playerid, reason)
	end
end


local process_msg = function(fd, msgstr)
	local cmd, msg = msgpack.str_unpack(msgstr)
	skynet.error("recv " .. fd .. " [" .. cmd .."] {" .. table.concat(msg, ",") .. "} ")

	local conn = conns[fd]
	local playerid = conn.playerid

	if not playerid then
		local node = skynet.getenv("node")
		local nodecfg = runconfig[node]
		local loginid = math.random(1, #nodecfg.login)
		local login = "login" .. loginid
		skynet.send(login, "lua", "client", fd, cmd, msg)
	else
		local gplayer = players[playerid]
		local agent = gplayer.agent
		skynet.send(agent, "lua", "client", cmd, msg)
	end
end

-- 消息队列处理
local process_buff = function (fd, readbuff)
	while true do
		local msgstr, rest = string.match(readbuff, "(.-)\r\n(.*)")
		if msgstr then
			readbuff = rest
			process_msg(fd, msgstr)
		else
			return readbuff
		end
	end
end

local recv_loop = function(fd)
	socket.start(fd)
	
	local readbuff = ""
	while true do
		local revstr = socket.read(fd)
		if revstr then
			readbuff = readbuff .. revstr
			readbuff = process_buff(fd, readbuff)
		else
			skynet.error("socket close "..fd)
			disconnect(fd)
			socket.close(fd)
			return
		end
	end
end

-- socket处理客户端连接的函数
local function connect(fd, addr)
	skynet.error("connect from " .. addr .. " " .. fd)
	local c = conn()
	conns[fd] = c
	c.fd = fd
	skynet.fork(recv_loop, fd)
end

-- 待优化，fd无论在哪个服务都可以发送，无须来到gateway服务
s.resp.send_by_fd = function(source, fd, msg)
	if not conns[fd] then return end

	local buff = msgpack.str_pack(msg[1], msg)
	skynet.error("send "..fd.." ["..msg[1].."] {"..table.concat(msg, ",").."}")
	socket.write(fd, buff)
end

s.resp.send = function(source, playerid, msg)
	local gplayer = players[playerid]
	if gplayer == nil then return end

	local c = gplayer.conn
	if c == nil then return end
	s.resp.send_by_fd(nil, c.fd, msg)
end

-- 登入处理
s.resp.sure_agent = function(source, fd, playerid, agent)
	local conn = conns[fd]

	-- 登陆过程中已经下线
	if not conn then
		skynet.call("agentmgr", "lua", "reqkick", playerid, "")
		return false
	end

	conn.playerid = playerid

	local gplayer = gateplayer()
	gplayer.playerid = playerid
	gplayer.agent = agent
	gplayer.conn = conn
	players[playerid] = gplayer

	return true
end

s.resp.kick = function(source, playerid)
	local gplayer = players[playerid]
	if not gplayer then return end

	local c = gplayer.conn
	players[playerid] = nil

	if not c then return end

	conns[c.fd] = nil
	disconnect(c.fd)
	socket.close(c.fd)
end

-- gateway服务的初始化
function s.init()
	local node = skynet.getenv("node")
	local nodecfg = runconfig[node]	

	-- 检查gateway的启动配置
	local cfg = nodecfg and nodecfg.gateway and s.id and nodecfg.gateway[tonumber(s.id)]
	if not cfg then error("gateway start not nodecfg") end
	
	local port = cfg.port
	local ip = "0.0.0.0"

	local listenfd = socket.listen(ip, port)
	skynet.error("Listen socket:", ip .. ":" .. port)
	socket.start(listenfd, connect)
end

-- 启动gateway服务
-- local function a111(a, b)
-- 	print("gate start type", a, b, type(a), type(b)) 
-- 	s.start(a, b)
-- end
-- a111(...)
s.start(...)