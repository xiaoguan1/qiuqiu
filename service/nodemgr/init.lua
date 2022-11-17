local skynet = require "skynet"
local s = require "service"

PROTO_FUN = {}

PROTO_FUN.newservice = function(source, name, ...)
    local srv = skynet.newservice(name, ...)
    return srv
end

s.start(...)
