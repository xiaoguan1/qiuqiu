local skynet = require "skynet"
local sc = require "skynet.socketchannel"
local socket = require "skynet.socket"
local cluster = require "skynet.cluster.core"

local channel
local session = 1
local node, nodename, init_host, init_port = ...
local LOOP_TIME = 1000	-- 时间轮训的刻度为10秒
local string = string
local pack = skynet.pack
local unpack = skynet.unpack

local dpclusterd_cfg = EVERY_NODE_SERVER and EVERY_NODE_SERVER.dpclusterd
assert(dpclusterd_cfg)
local pcall = pcall

local command = {}

local function send_request(addr, msg, sz)
	-- msg is a local pointer, cluster.packrequest will free it
	local current_session = session
	local request, new_session, padding = cluster.packrequest(addr, session, msg, sz)
	session = new_session

	local tracetag = skynet.tracetag()
	if tracetag then
		if tracetag:sub(1,1) ~= "(" then
			-- add nodename
			local newtag = string.format("(%s-%s-%d)%s", nodename, node, session, tracetag)
			skynet.tracelog(tracetag, string.format("session %s", newtag))
			tracetag = newtag
		end
		skynet.tracelog(tracetag, string.format("cluster %s", node))
		channel:request(cluster.packtrace(tracetag))
	end
	return channel:request(request, current_session, padding)
end

function command.req(...)
	local ok, msg = pcall(send_request, ...)
	if ok then
		if type(msg) == "table" then
			skynet.ret(cluster.concat(msg))
		else
			skynet.ret(msg)
		end
	else
		skynet.error(msg)
		skynet.response()(false)
	end
end

function command.push(addr, msg, sz)
	local request, new_session, padding = cluster.packpush(addr, session, msg, sz)
	if padding then	-- is multi push
		session = new_session
	end

	channel:request(request, nil, padding)
end

local function read_response(sock)
	local sz = socket.header(sock:read(2))
	local msg = sock:read(sz)
	return cluster.unpackresponse(msg)	-- session, ok, data, padding
end

function command.changenode(host, port)
	if not host then
		skynet.error(string.format("Close cluster sender %s:%d", channel.__host, channel.__port))
		channel:close()
	else
		channel:changehost(host, tonumber(port))
		channel:connect(true, skynet.self())
	end
	skynet.ret(pack(nil))
end

function command.interrupt()
	skynet.error(string.format("interrupt cluster sender %s:%d", channel.__host, channel.__port))
	channel:close()
	channel.__interrupt = true
	local named = skynet.localname(dpclusterd_cfg.named)
	if named then
		pcall(skynet.send, named, "lua", "interrupt", node)
	end
end

-- create by guanguowei
function loop()
	while true do
		skynet.sleep(LOOP_TIME)

		if (channel.__interrupt and channel.__host and channel.__port)	-- 中途断线
		or (channel.__service and channel.__host and channel.__port and not channel.__sock) -- 服务启动时就已经连接失败
		then
			local isOk, result = pcall(channel.connect, channel, true, skynet.self())
			if isOk and result then
				local isOk, msg = pcall(send_request, 0, pack(dpclusterd_cfg.cluster_named))
				local named = skynet.localname(dpclusterd_cfg.named)
				if isOk and named then
					-- 重连成功且获取对面节点的dpclusterd服务地址才算成功.
					skynet.send(named, "lua", "reconnection", node, unpack(msg))
					channel.__interrupt = nil
					skynet.error(string.format("Reconnection nodeName:%s success", node))
				else
					skynet.error(msg)
				end
			end
		end
	end
end

skynet.start(function()
	channel = sc.channel {
			host = init_host,
			port = tonumber(init_port),
			response = read_response,
			nodelay = true,
		}
	skynet.dispatch("lua", function(session , source, cmd, ...)
		local f = assert(command[cmd])
		f(...)
	end)
	skynet.fork(loop)
end)
