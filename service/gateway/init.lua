local skynet = require "skynet"
local s = require "service"
local socket = require "skynet.socket"
local runconfig = require "runconfig"
local msgpack = require "msg_pack"
local log = require "common_log"
local GATEWAY_COMMON = require "gateway_common"

conns = {}	-- { [fd] = conn, ... }
players = {}	-- { [playerId] = gateplayer, ...}

PROTO_FUN = {}

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

local process_msg = function(fd, msgstr)
	local cmd, msg = msgpack.str_unpack(msgstr)
	skynet.error("recv " .. fd .. " [" .. cmd .."] {" .. table.concat(msg, ",") .. "} ")

	GATEWAY_COMMON.process_msg(fd, cmd, msg)
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
			skynet.error("socket close " .. fd)
			GATEWAY_COMMON.disconnect(fd)
			socket.close(fd)
			return
		end
	end
end

-- socket处理客户端连接的函数
local function connect(fd, addr)
	if CLOSING then return end	-- 收到关服消息 拒绝玩家连接

	skynet.error("connect from " .. addr .. " " .. fd)
	local c = conn()
	conns[fd] = c
	c.fd = fd
	skynet.fork(recv_loop, fd)
end

-- gateway服务的初始化
function s.init()	
	local port = assert(tonumber(skynet.getenv("gateway_post")))
	local ip = "0.0.0.0"

	local listenfd = socket.listen(ip, port)
	skynet.error("Listen socket:", ip .. ":" .. port)
	socket.start(listenfd, connect)
end

function s.after()
	dofile("./service/gateway/handle.lua")
end

s.start(...)