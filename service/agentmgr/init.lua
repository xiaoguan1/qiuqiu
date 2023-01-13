local skynet = require "skynet"
local s = require "service"
local table = table
local queue = require "skynet.queue"
local CS = queue()

PROTO_FUN = {}

STATUS = {
    LOGIN = 2,      -- 登入状态
    GAME = 3,       -- 游戏中
    LOGOUT = 4,     -- 登出状态
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

-- 玩家在线人数
function get_player_online_count()
    return table.size(players)
end

-- 登入
PROTO_FUN.reqlogin = function(source, playerid, node, gate)
    local mplayer = players[playerid]

    -- 登出过程禁止顶替
    if mplayer and mplayer.status == STATUS.LOGOUT then
        skynet.error("reqlogin fail, at status LOGOUT " .. playerid)
        return false
    end

    -- 登入过程禁止顶替
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

-- 登出
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


local QUIT_PLAYER_COUNT = 10 -- 同时下线人数
-- 策略1：缓缓的让玩家下线【降低关服时数据库瞬时压力】
function shutdown_quit_player_1()
    local playerCount = get_player_online_count()
    local n = 0
    for playerid, player in pairs(players) do
        skynet.fork(PROTO_FUN.reqkick, nil, playerid, "close server")
        n = n + 1
        if n > QUIT_PLAYER_COUNT then break end
    end

    while true do
        skynet.sleep(200)
        local new_count = get_player_online_count()
        skynet.error("shutdown online:" .. new_count)
        if new_count <= 0 or new_count <= (playerCount - QUIT_PLAYER_COUNT) then
            return new_count
        end
    end
end

-- 策略2：玩家全部同时下线【玩家人数较少时或者数据库压力不大时可选择】
function shutdown_quit_player_2()
    -- 踢下线
    for playerid, player in pairs(players) do
        PROTO_FUN.reqkick(nil, playerid, "close server")
    end
end

-- 关服强制玩家下线
PROTO_FUN.shutdown = function(source)
    -- 在线人数
    local playerCount = get_player_online_count()

    -- 在线人数大于100阈值采用策略1，否则采用策略2。
    if playerCount > 100 then
        while playerCount > 0 do
            playerCount = shutdown_quit_player_1()
        end
    else
        shutdown_quit_player_2()
    end
    return true
end

s.start(...)