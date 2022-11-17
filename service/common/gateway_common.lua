local skynet = require "skynet"
local node = skynet.getenv("node")
local runconfig = require "runconfig"
local nodecfg = runconfig[node]

local M = {}

-- �ǳ�
M.disconnect = function(fd)
	local c = conns[fd]
	if not c then return end

	-- playerid��Ϊ��ʱ�����ڵ�¼��
	local playerid = c.playerid
    if not playerid then return end

    player[playerid] = nil
	local reason = "����"
	skynet.call("agentmgr", "lua", "reqkick", playerid, reason)
end

M.process_msg = function(fd, cmd, msg)
    local conn = conns[fd]
	local playerid = conn.playerid

    if not playerid then
		-- �漴ѡһ�����񣨲��Ͻ���û�кܺõĽ�����ؾ�������⣬��Ҫ����ص��㷨����ѡȡ��
		local loginid = math.random(1, #nodecfg.login)
		local login = "login" .. loginid

		skynet.send(login, "lua", "client", fd, cmd, msg)
	else
		if cmd ~= "create" then
			local gplayer = players[playerid]
			local agent = gplayer.agent
			skynet.send(agent, "lua", "client", cmd, msg)
		else
			PROTO_FUN.send_by_fd(nil, fd, {"create", 1, "�����˳���ǰ�ʺ��ٴ��ǣ�����"})
		end
	end
end

return M