local skynet = require "skynet"

PROTO_FUN = {}

PROTO_FUN.newservice = function(source, name, ...)
    local srv = skynet.newservice(name, ...)
    return srv
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local fun = PROTO_FUN[cmd]
        if not fun then
            -- 后续补上错误打印
            print(string.format("[%s] [session:%s], [cmd:%s] not find fun.", SERVICE_NAME, session, cmd))
            return
        end
        if session == 0 then
            xpcall(fun, traceback, address, ...)
        else
            local ret = table.pack(xpcall(fun, traceback, address, ...))
            local isOk = ret[1]
            if not isOk then
                skynet.ret()
                return
            end
            skynet.retpack(table.unpack(ret, 2))
        end
    end)
end)
