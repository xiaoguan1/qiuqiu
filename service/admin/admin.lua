-- 供外部调用
local skynet = require "skynet"
local socket = require "skynet.socket"
local runconfig = require "runconfig"
require "skynet.manager"
local sockethelper = require "http.sockethelper"
local httpd = require "http.httpd"
local urllib = require "http.url"
local sys = sys
local os = os

-- 内部调用 ------------------------------------------------------

local function response(fd, ...)
	local ok, err = httpd.write_response(sockethelper.writefunc(fd), ...)
	if not ok then
		-- if err == sockethelper.socket_error, that means socket closed.
		_ERROR_F("dealadmin response error fd = %s, %s", fd, err)
	end
end


-- 外部调用 ------------------------------------------------------

-- example:
--		wget -q -O - "http://127.0.0.1:8888/gmcode.lua?code=a"
--		wget -q -O - "http://127.0.0.1:8888/pings"
function connect(fd, addr)
	socket.start(fd)
	_INFO(string.format("connection successful fd:%s address:%s", fd, addr))
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

			local f = MANAGE_MGR[path:gsub("/", "")]
			if f then
				local ret = f(q)
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
			_ERROR("dealmcs socket closed")
		else
			_ERROR_F("dealmcs error:%s", url)
		end
	end
	socket.close(fd)
end

skynet.start(function (...)
	skynet.register(".admin")

	-- 开启一个监听,8888端口！！！
	local listenfd = socket.listen("127.0.0.1", 8888, 128)
	_INFO_F("admin Listen on 127.0.0.1:%d", 8888)
	socket.start(listenfd, connect)

	dofile("./service/admin/init/loading.lua")

	local launcher = PROXYSVR.GetProxy(".launcher")
	launcher.call.SERVICE_CPU_ON()
end)
