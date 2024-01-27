-- 供外部调用
local skynet = require "skynet"
local socket = require "skynet.socket"
local runconfig = require "runconfig"
require "skynet.manager"
local sockethelper = require "http.sockethelper"
local httpd = require "http.httpd"
local urllib = require "http.url"
local sys = sys

-- 内部方法 ------------------------------------------------------

local function _SHUTDOWN()
	-- 关闭顺序不能改变

	-- 给网关发送关服消息
	for note, _ in pairs(runconfig.cluster) do
		for i, v in pairs(runconfig.gateway or {}) do
			local name = "gateway" .. i
			service.call(node, name, "shutdown")
		end
	end

	-- 给玩家发送关服消息
	local anode = runconfig.agentmgr.node
	local result = service.call(anode, "agentmgr", "shutdown")
	if not result then
		error("close server fail.")
	end
	
	-- 退出skynet进程
	skynet.abort()
end

local function _PING()
	print("eeeeeqqq", skynet.localname(".launcher"))
	return skynet.ret()
end

local function _MEM()
	local proxy = GetProxy(".launcher")
	local ret = proxy.call.MEM()
	return sys.dump(ret)
end

local function _RT()
	local proxy = GetProxy(".launcher")
	local ret = proxy.call.SERVICE_RT()
	return sys.dump(ret)
end

local function _STAT()
	local proxy = GetProxy(".launcher")
	local ret = proxy.call.SERVICE_STAT()
	return sys.dump(ret)
end

-- 外部调用 ------------------------------------------------------
CMD = {
	["/shutdown"] = _SHUTDOWN,	-- 关服
	["/ping"] = _PING,			-- ping所有服务
	["/mem"] = _MEM,
	["/rt"] = _RT,				-- "ping一下所有服务，并获取相应时间差"
	["/stat"] = _STAT,
}


local function response(fd, ...)
	local ok, err = httpd.write_response(sockethelper.writefunc(fd), ...)
	if not ok then
		-- if err == sockethelper.socket_error, that means socket closed.
		skynet.error(string.format("dealadmin response error fd = %s, %s", fd, err))
	end
end

-- example:
--		wget -q -O - "http://127.0.0.1:8888/gmcode.lua?code=a"
--		wget -q -O - "http://127.0.0.1:8888/pings"
function connect(fd, addr)
	socket.start(fd)
	skynet.error(string.format("connection successful fd:%s address:%s", fd, addr))
	local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(fd), 8192)
	if code then
		if code ~= 200 then
			response(fd, code)
		else
			local path, query= urllib.parse(url)
			local q
			if query then
				q = urllib.parse_query(query)
			end

			local f = CMD[path]
			if f then
				local ret = f()
				response(fd, 200, ret)
			else
				local filename
				if string.sub(path, 1, 1) ~= "/" then
					filename = "admin/" .. path
				else
					filename = "admin" .. path
				end
				for k, v in pairs(q) do
					print(k, v)
				end
				-- loadfile(filename)
				print("filename ", filename)
				response(fd, 404, "not find action, error!")
			end
		end
	else
		if url == sockethelper.socket_error then
			skynet.error("dealmcs socket closed")
		else
			skynet.error("dealmcs error:", url)
		end
	end
	socket.close(fd)
end

skynet.start(function (...)
	skynet.register(".admin")

	-- 开启一个监听,8888端口！！！
	local listenfd = socket.listen("127.0.0.1", 8888, 128)
	skynet.error(string.format("admin Listen on 127.0.0.1:%d", 8888))
	socket.start(listenfd, connect)
end)
