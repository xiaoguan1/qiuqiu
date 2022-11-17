local skynet = require "skynet"
local s = require "service"

PROTO_FUN = {}

STATUS = {
    LOGIN = 2,
    GAME = 3,
    LOGOUT = 4,        
}

-- 玩家列表
local players = {}

-- 玩家类
function mgrplayer()
    return {
        playerid = nil, -- 玩家id
        node = nil,     -- 该玩家对于的gateway和agent所在的节点
        agent = nil,    -- 该玩家对应agent服务的id
        status = nil,   -- 状态，例如：登陆中
        gate = nil,     -- 该玩家对应gateway的id
    }
end

-- 登入
PROTO_FUN.reqlogin = function(source, playerid, node, gate)
    local mplayer = players[playerid]

    -- 登陆过程禁止顶替
    if mplayer and mplayer.status == STATUS.LOGOUT then
        skynet.error("reqlogin fail, at status LOGOUT " .. playerid)
        return false
    end

    if mplayer and mplayer.status == STATUS.LOGIN then
        skynet.error("reqlogin fail, at status LOGIN " .. playerid)
        return false
    end

    -- 在线，顶替
    if mplayer then
        local pnode = mplayer.node
        local pagent = mplayer.agent
        local pgate = mplayer.gate
        mplayer.status = STATUS.LOGOUT
        s.call(pnode, pagent, "kick")
        s.send(pnode,  pagent, "exit")
        s.send(pnode,  pgate, "send", playerid, {"kick", "顶替下线"})
        s.call(pnode, pgate, "kick", playerid)
    end

    -- 上线
    local player = mgrplayer()
    player.playerid = playerid
    player.node = node
    player.gate = gate
    player.agent = nil
    player.status = STATUS.LOGIN
    players[playerid] = player

    -- 获取代理agent
    local agent = s.call(node, "nodemgr", "newservice", "agent", "agent", playerid)
	player.agent = agent
	player.status = STATUS.GAME
	return true, agent
end

PROTO_FUN.reqkick = function(source, playerid, reason)
    local mplayer = players[playerid]
    if not mplayer then return false end

    if mplayer.status ~= STATUS.GAME then
        return false
    end

    local pnode = mplayer.node
    local pagent = mplayer.agent
    local pgate = mplayer.gate
    mplayer.status = STATUS.LOGOUT

    s.call(pnode, pagent, "kick")
    s.send(pnode, pagent, "exit")
    s.send(pnode, pgate, "kick", playerid)
    players[playerid] = nil

    return true
end

s.start(...)