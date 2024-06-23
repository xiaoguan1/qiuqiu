local skynet = require "skynet"
local assert = assert
local DPCLUSTER_NODE = assert(load("return " .. skynet.getenv("DPCLUSTER_NODE"))())

skynet.register_protocol({
	name = "rpc",
	id = skynet.PTYPE_RPC,
})

CMD = {}
function CMD.req_heartbeat()
end
function CMD.req()
end
function CMD.push()
end
function CMD.push_notips()
end
function CMD.req_notips()
end
function CMD.write_proto()
end
function CMD.close_senderror()
end
function CMD.open_senderror()
end
function CMD.closeall()
end

skynet.start(function ()
	skynet.dispatch("lua", function (session, source, cmd, ...)
		local f = cmd and CMD[cmd]
		if not f then
			error(string.format("dpcluster cmd=%s not find func", cmd))
		end
		if session == 0 then
			f(...)
		else
			skynet.response(f(...))
		end
	end)
end)