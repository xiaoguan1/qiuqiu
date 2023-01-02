local skynet = require "skynet"
local node = skynet.getenv("node")
local runconfig = require "runconfig"
local nodecfg = runconfig[node]

local M = {}

-- 登出
M.disconnect = function(fd)
	local c = conns[fd]
	if not c then return end

	-- playerid不为空时代表处于登录中
	local playerid = c.playerid
    if not playerid then return end

    player[playerid] = nil
	local reason = "断线"
	skynet.call("agentmgr", "lua", "reqkick", playerid, reason)
end

M.process_msg = function(fd, cmd, msg)
    local conn = conns[fd]
	local playerid = conn.playerid

    if not playerid then
		-- 随即选一个服务（不严谨，没有很好的解决负载均衡的问题，需要加相关的算法辅助选取）
		local loginid = math.random(1, #nodecfg.login)
		local login = "login" .. loginid

		skynet.send(login, "lua", "client", fd, cmd, msg)
	else
		if cmd ~= "create" then
			local gplayer = players[playerid]
			local agent = gplayer.agent
			skynet.send(agent, "lua", "client", cmd, msg)
		else
			PROTO_FUN.send_by_fd(nil, fd, {"create", 1, "请先退出当前帐号再创角！！！"})
		end
	end
end

return M