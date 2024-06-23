local skynet = require "skynet"
skynet.register_protocol({
	name = "rpc",
	id = skynet.PTYPE_RPC,
})

skynet.start(function ()
	skynet.dispatch("lua", function (session, source, command, ...)
		
	end)
end)