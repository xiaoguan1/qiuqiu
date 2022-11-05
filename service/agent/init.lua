local skynet = require "skynet"
local s = require "service"

s.client = {}
s.gate = nil

s.resp.client = function(source, cmd, msg)
    s.gate = source
    if s.client[cmd] then
        local ret_msg = s.client[cmd](msg, source)
        print("agent agent ", s.id)
        if ret_msg then
            skynet.send(source, "lua", "send", tonumber(s.id), ret_msg)
        end
    else
        skynet.error("s.resp.client fail ", cmd)
    end
end

s.init = function()
    -- 读取数据库，获得玩家数据
    skynet.sleep(200)

    s.data = {
        coin = 100,
        hp = 200,
    }
end

s.resp.kick = function(source)
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

s.start(...)