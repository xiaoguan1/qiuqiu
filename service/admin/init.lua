local skynet = require "skynet"
local service = require "service"
local socket = require "skynet.socket"
local runconfig = require "runconfig"
require "skynet.manager"

-- 给网关发送关服消息
function shutdown_gate()
	for note, _ in pairs(runconfig.cluster) do
		for i, v in pairs(runconfig.gateway or {}) do
			local name = "gateway" .. i
			service.call(node, name, "shutdown")
		end
	end
end

-- 给玩家发送关服消息
function shutdown_agent()
	local anode = runconfig.agentmgr.node
	local result = service.call(anode, "agentmgr", "shutdown")
	if not result then
		error("close server fail.")
	end
end

function stop()
    -- 关闭顺序不能改变
	shutdown_gate()
	shutdown_agent()

	-- 退出skynet进程
	skynet.abort()
end

function connect(fd, addr)
	socket.start(fd)
	socket.write(fd, "Please enter cmd\r\n")
	local cmd = socket.readline(fd, "\r\n")
	if cmd == "stop" then
        stop()
    else
        -- .....
    end
end

service.init = function()
    -- 开启一个监听,8888端口！！！
    local listenfd = socket.listen("127.0.0.1", 8888)
    socket.start(listenfd, connect)
end

service.start(...)