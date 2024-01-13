local BATTLE_COMMON = require "battle_common"


-- 进入战斗前判断
PROTO_FUN.enter = function(source, playerid, node, agent)
	if balls[playerid] then return false end

	local b = ball(playerid, node, agent)

	-- 广播(优化点:九宫格)
	local entermsg = {"enter", playerid, b.x, b.y, b.size}
	broadcast(entermsg)

	balls[playerid] = b

	-- 回应
	local ret_msg = {"enter", 0, "进入成功"}
	skynet.send(b.node, b.agent, "send", ret_msg)

	--　发送战场
	skynet.send(b.node, b.agent, "send", BATTLE_COMMON.balllist_msg())
	skynet.send(b.node, b.agent, "send", BATTLE_COMMON.foodlist_msg())

	return true
end

-- 退出
PROTO_FUN.leave = function(source, playerid)
	if not balls[playerid] then return false end

	balls[playerid] = nil

	local leavemsg = {"leave", playerid}
	broadcast(leavemsg)
end

-- 改变速度
PROTO_FUN.shift = function(source, playerid, x, y)
	local b = balls[playerid]
	if not b then return false end

	b.speedx = x
	b.speedy = y
end