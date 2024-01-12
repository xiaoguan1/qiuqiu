-- local skynet = require "skynet"
-- local socketdriver = require "skynet.socketdriver"
-- local netpack = require "skynet.netpack"

-- local queue

-- -- 参数fd是新连接的标识，
-- -- 参数fd需要调用socketdriver.start才可以接收数据（才是真正意义上的socket）
-- -- addr代表客户端IP和端口
-- function process_connect(fd, addr)
--     skynet.error("new conn fd:".. fd .." addr:" .. addr)
--     socketdriver.start(fd)
-- end

-- -- 关闭socket时的回调
-- function process_close(fd)
--     -- 清空队列queue 释放缓存
--     netpack.clear(queue)    -- 其实不严谨，有可能会处理掉还没有处理的消息
--     skynet.error("close fd：" .. fd)
-- end

-- -- error代表错误的原因
-- function process_error(fd, error)
--     skynet.error("error fd:".. fd .. " error:".. error)
-- end

-- -- size代表缓冲区的长度
-- function process_warning(fd, size)
--     skynet.error("warning fd:".. fd .. "size:" .. size)
-- end

-- function process_msg(fd, msg, sz)
--     local str = netpack.tostring(msg, sz)
--     skynet.error("recv from fd:" .. fd .. " str:".. str)

--     skynet.sleep(100)
--     skynet.error("finish fd: " .. fd .. " " .. str)
-- end

-- function process_more()
--     for fd, msg, sz in netpack.pop, queue do
--         -- skynet.fork创建协程，是为了保障阻塞消息处理方法(process_msg)的时序一致性
--         skynet.fork(process_msg, fd, msg, sz)
--     end
-- end

-- function socket_unpack(msg, sz)
--     return netpack.filter(queue, msg, sz)
-- end

-- function socket_dispath(_a, _b, q, type, ...)
--     skynet.error(SERVICE_NAME .. " socket_dispath type:" .. (type or nil))
--     queue = q
--     if type == "open" then          -- 新的连接
--         process_connect(...)
--     elseif type == "init" then       -- 对新的连接进行初始化（先open在init）

--     elseif type == "data" then      -- 处理消息
--         -- 这里可以使用协程，让socket_dispath方法处理协议更快些
--         process_msg(...)
--     elseif type == "more" then      -- 收到多于1条消息时
--         process_more(...)
--     elseif type == "close" then     -- 关闭连接
--         process_close(...)
--     elseif type == "error" then     -- 发生错误
--         process_error(...)
--     elseif type == "warning" then   -- 发生警告
--         process_warning(...)
--     end
-- end

-- skynet.start(function()
--     skynet.register_protocol({
--         name = "socket",
--         id = skynet.PTYPE_SOCKET,
--         unpack = socket_unpack,
--         dispatch = socket_dispath,
--     })

--     local listenfd = socketdriver.listen("0.0.0.0", 8888)
--     local relust = socketdriver.start(listenfd)
-- end)

local skynet = require "skynet"
local cjson = require "cjson"
local pb = require "protobuf"

-- 编码Json协议
-- cmd:协议名、msg:协议对象
local function json_pack(cmd, msg)
    msg._cmd = cmd -- 目的: 给客户端的网络模块带来些许便利(不是必须的)

    local body = cjson.encode(msg)      -- 协议体字节流
    local namelen = string.len(cmd)     -- 协议名长度
    local bodylen = string.len(body)    -- 协议体长度
    local len = namelen + bodylen + 2   -- 协议体总长度

    local format = string.format("> i2 i2 c%d c%d", namelen, bodylen)
    local buff = string.pack(format, len, namelen, cmd, body)

    return buff
end

-- 解码Json协议
local function json_unpack(buff)
    -- len长度包含 消息体长度
    local len = string.len(buff)
    local namelen_format = string.format("> i2 c%d", len-2)
    print(namelen_format)
    local namelen, other = string.unpack(namelen_format, buff)
    local bodylen = len - 2 - namelen
    local format = string.format("> c%d c%d", namelen, bodylen)
    local cmd, bodybuff = string.unpack(format, other)

    local isok, msg = pcall(cjson.decode, bodybuff)
    if not isok or not msg or not msg._cmd or not cmd == msg._cmd then
        print("error",not isok, not msg, not msg._cmd, cmd)
        return
    end

    return cmd, msg
end


skynet.start(function()
    local msg = {
        _cmd = "playerinfo",
        coin = 100,
        bag = {
            [1] = {1001,1}, --倚天剑*1 
            [2] = {1005,5} --草药*5
        },
    }
    --编码
    local buff_with_len = json_pack("playerinfo", msg)
    local len = string.len(buff_with_len)
    print("len:"..len)
    print(buff_with_len)
    --解码
    local format = string.format(">i2 c%d", len-2)
    local _, buff = string.unpack(format, buff_with_len)
    local cmd, umsg = json_unpack(buff)
    print("cmd:"..cmd)
    print("coin:"..umsg.coin)
    print("sword:"..umsg.bag[1][2])

end)