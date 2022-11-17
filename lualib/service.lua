local skynet = require "skynet"
local cluster = require "skynet.cluster"
local mynode = skynet.getenv("node")

local M = {
	name = "",
	id = 0,	
	init = nil,	-- 回调初始化函数
	after = nil, -- 服务启动之后的调用函数
	exit = nil,	-- 回调退出函数
}

local function dispatch(session, address, cmd, ...)
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
end

function init(name, id, ...)
	skynet.dispatch("lua", dispatch)
	if M.init then M.init() end
end

function after()
	if M.after then M.after() end
end

function M.start(name, id, ...)
	M.name = name
	M.id = id
	skynet.start(init, name, id, ...)
	after()
end

function traceback(err)
	skynet.error(tostring(err))
	skynet.error(debug.traceback())
end

-- 封装call发送消息
function M.call(node, srv, ...)
	if node == mynode then
		return skynet.call(srv, "lua", ...)
	else
		return cluster.call(node, srv, ...)
	end
end

-- 封装send发送消息
function M.send(node, srv, ...)
	if node == mynode then
		return skynet.send(srv, "lua", ...)
	else
		return cluster.send(node, srv, ...)
	end
end

return M
