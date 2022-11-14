local skynet = require "skynet"
local s = require "service"
local P = require "common_log"
require "scene"
P.PRINT("111111111", s)
s.client = {}
s.gate = nil

s.init = function()
    -- 读取数据库，获得玩家数据
    skynet.sleep(200)

    s.data = {
        coin = 100,
        hp = 200,
    }
end

s.start(...)

s.resp.client = function(source, cmd, msg)
    print("FFFFFFF ", source, cmd, msg)
    s.gate = source
    if s.client[cmd] then
        local ret_msg = s.client[cmd](msg, source)
        if ret_msg then
            skynet.send(source, "lua", "send", tonumber(s.id), ret_msg)
        end
    else
        skynet.error("s.resp.client fail ", cmd)
    end
end

s.resp.kick = function(source)
    s.leave_scene()
    -- 玩家登出，保存角色数据
    skynet.sleep(200) -- 后续完善 db 层内容。
end

s.resp.exit = function(source)
    skynet.exit()
end

-- 返回玩家最新的金币数量
s.client.work = function(msg)
    s.data.coin = s.data.coin + 1
    return {"work", s.data.coin}
end

s.resp.send = function(source, msg)
    skynet.send(s.gate, "lua", "send", s.id, msg)
end

s.client.shift = function(msg)
    if not s.sname then return end
    local x = msg[2] or 0
    local y = msg[3] or 0

    -- 有待商榷，可以用异步。如果出现卡顿　那说明服务器处于过载的情况
    s.call(s.snode, s.sname, "shift", s.id, x, y)
end