local skynet = require "skynet"
local socket = require "skynet.socket"
local table = table
local msgpack = require "msg_pack"

-- ���Ż���fd�������ĸ����񶼿��Է��ͣ���������gateway����
PROTO_FUN.send_by_fd = function(source, fd, msg)
    if not conns[fd] then return end

	local buff = msgpack.str_pack(msg[1], msg)
	skynet.error("send "..fd.." ["..msg[1].."] {"..table.concat(msg, ",").."}")
	socket.write(fd, buff)
end

PROTO_FUN.send = function(source, playerid, msg)
    local gplayer = players[playerid]
	if gplayer == nil then return end

	local c = gplayer.conn
	if c == nil then return end
	PROTO_FUN.send_by_fd(nil, c.fd, msg)
end

PROTO_FUN.sure_agent = function(source, fd, playerid, agent)
    local conn = conns[fd]

	-- ��½�������Ѿ�����
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

PROTO_FUN.kick = function(source, playerid)
	local gplayer = players[playerid]
	if not gplayer then return end

	local c = gplayer.conn
	players[playerid] = nil

	if not c then return end

	conns[c.fd] = nil
	disconnect(c.fd)
	socket.close(c.fd)
end
