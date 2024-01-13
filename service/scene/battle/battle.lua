local BATTLE_COMMON = require "battle_common"


-- ����ս��ǰ�ж�
PROTO_FUN.enter = function(source, playerid, node, agent)
	if balls[playerid] then return false end

	local b = ball(playerid, node, agent)

	-- �㲥(�Ż���:�Ź���)
	local entermsg = {"enter", playerid, b.x, b.y, b.size}
	broadcast(entermsg)

	balls[playerid] = b

	-- ��Ӧ
	local ret_msg = {"enter", 0, "����ɹ�"}
	skynet.send(b.node, b.agent, "send", ret_msg)

	--������ս��
	skynet.send(b.node, b.agent, "send", BATTLE_COMMON.balllist_msg())
	skynet.send(b.node, b.agent, "send", BATTLE_COMMON.foodlist_msg())

	return true
end

-- �˳�
PROTO_FUN.leave = function(source, playerid)
	if not balls[playerid] then return false end

	balls[playerid] = nil

	local leavemsg = {"leave", playerid}
	broadcast(leavemsg)
end

-- �ı��ٶ�
PROTO_FUN.shift = function(source, playerid, x, y)
	local b = balls[playerid]
	if not b then return false end

	b.speedx = x
	b.speedy = y
end