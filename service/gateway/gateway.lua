local skynet = require "skynet"
local socket = require "skynet.socket"
local SERVICE_NAME = SERVICE_NAME
local NODE_SERVER_INFO = NODE_SERVER_INFO
local Import = Import
local slave_cnt = tonumber(skynet.getenv("login_slavecnt")) or 8
local login_port = tonumber(skynet.getenv("login_port"))
local port_index = tonumber(...)
local is_son = ...


CMD = {}
WS_HANDLER = {}
SERVER = {
	port = login_port,
	multilogin = false,
	instance = slave_cnt,
}

skynet.start(function ()
	if is_son then
		
	else
		MASTERFUNC = Import("service/gateway/masterfunc.lua")
		skynet.dispatch("lua", function (_, source, command, ...)
			skynet.ret(skynet.pack())
			
		end)
		local GATEWAY_SON = Import("service/gateway/gateway_son.lua")
		skynet.fork(GATEWAY_SON.LaunchService, NODE_SERVER_INFO.gateway.son_num)
	end
end)




-- -- socket处理客户端连接的函数
-- local function connect(fd, addr)
-- 	if CLOSING then return end	-- 收到关服消息 拒绝玩家连接

-- 	_INFO_F("connect from %s %s", addr, fd)
-- 	local c = conn()
-- 	conns[fd] = c
-- 	c.fd = fd
-- 	skynet.fork(recv_loop, fd)
-- end

-- -- gateway服务的初始化
-- skynet.init(function()
-- 	local port = DPCLUSTER_NODE.gateway_posts[port_index]
-- 	local listenfd = socket.listen(DPCLUSTER_NODE.main_node_ip, port)
-- 	_INFO_F("Listen socket: %s:%s", DPCLUSTER_NODE.main_node_ip, port)
-- 	socket.start(listenfd, connect)
-- end)

-- skynet.start(function()
-- 	skynet.dispatch("lua", function (session, address, cmd, ...)
-- 		local fun = PROTO_FUN[cmd]
-- 		if not fun then
-- 			-- 后续补上错误打印
-- 			print(string.format("[%s] [session:%s], [cmd:%s] not find fun.", SERVICE_NAME, session, cmd))
-- 			return
-- 		end
-- 		if session == 0 then
-- 			xpcall(fun, traceback, address, ...)
-- 		else
-- 			local ret = table.pack(xpcall(fun, traceback, address, ...))
-- 			local isOk = ret[1]
-- 			if not isOk then
-- 				skynet.ret()
-- 				return
-- 			end
-- 			skynet.retpack(table.unpack(ret, 2))
-- 		end
-- 	end)

-- 	dofile("./service/gateway/handle.lua")
-- end)