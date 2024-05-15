local skynet = require "skynet"
require "skynet.manager"
local socket = require "skynet.socket"
local table = table
local pcall = pcall

-- local DPCLUSTER = Import("base/dpcluster.lua")
local PROXYSVR = Import("lualib/base/proxysvr.lua")
local CMD = CMD
local SERVER = SERVER

socket_error = {}
server_list = {}
acct_online = {}
acct_login = {}
player_allkick_time = false
is_shuntdown = false
listen_socket = false
slave_pool = {}

local function has_serverlist()
	for _, _ in pairs(server_list) do
		return true
	end
end

local function get_rserver()
	local lessonline_server = nil
	local lessonline_cnt = nil
	for _servername, _serverinfo in pairs(server_list) do
		if _serverinfo.isvalid then
			if not lessonline_cnt or _serverinfo.online_cnt < lessonline_cnt then
				lessonline_cnt = _serverinfo.online_cnt
				lessonline_server = _serverinfo
			end
		end
	end
	return lessonline_server
end


-- CMD -----------------------------------------------
-- 清空在线信息，以免gated因为网络问题或者宕掉，玩家已经没有acct_online的记录
-- @urs : 包括corp和serverid
function CMD.clear_acctonline(urs)
	local last = acct_online[urs]
	if last then
		local lsvr = last.node_svr
		pcall(lsvr.call.deadlock_kick, urs, last.uid)
		CMD.logout(urs)
	end
end

-- forbidden_time <= 0 为解禁
function CMD.forbidden_login(urs, forbidden_time, forbidden_type)
	-- local ok = FORBIDDEN.ForbiddenLogin(urs, forbidden_time, forbidden_type)
	-- if ok and forbidden_time > 0 then
	-- 	-- 如果在线则踢下线
	-- 	local last = acct_online[urs]
	-- 	if last then
	-- 		local lsvr = last.node_svr
	-- 		lsvr.call.kick(urs, last.uid)
	-- 	end
	-- end
end

-- 解禁所有战斗作弊玩家
function CMD.unseal_allbattleforbidden()
	-- FORBIDDEN.unseal_allbattleForbidden()
end

-- 解禁某个战斗作弊玩家
function CMD.unseal_onebattleforbidden(urs)
	-- FORBIDDEN.UnsealOneBattleForbidden(urs)
end

-- 提出死锁的角色
function CMD.deadlock_kick(urs)
	local last = acct_online[urs]
	if last then
		local lsvr = last.node_svr
		lsvr.call.deadlock_kick(urs, last.uid)
	end
end

function CMD.kick(urs)
	local last = acct_online[urs]
	if last then
		local lsvr = last.node_svr
		lsvr.call.kick(urs, last.uid, true)
	end
end

-- 处理网关无法连通的，设置网关为无效，把连接到该服的玩家设置成不在线
local function _dealwith_disconnectgate(servername)
	for _servername, _serverinfo in pairs(server_list) do
		if _servername == servername and _serverinfo.isvalid then
			_serverinfo.isvalid = false				-- 设置成无效的
			local nsvr = _serverinfo.node_svr
			pcall(shutdown_cs, nsvr.call.shutdown)	-- 尝试关闭gated
			-- 把所有玩家的在线设置成不删除
			for _urs, _data in pairs(acct_online) do
				if _data.servername == servername then
					if _serverinfo.online_cnt >= 1 then
						_serverinfo.online_cnt = _serverinfo.online_cnt - 1
					end
					acct_online[_urs] = nil
				end
			end
			break
		end
	end
end

function CMD.register_gate(servername, serverinfo)		-- 注册gate的地址
	if server_list[servername] then	-- 不能有重名
		error("has gate name:" .. servername)
	end
	serverinfo.servername = servername
	serverinfo.online_cnd = 0
	serverinfo.node_svr = PROXYSVR.GetProxy(serverinfo.address, serverinfo.nodeName)
	serverinfo.isvalid = true
	server_list[servername] = serverinfo

	if serverinfo.nodeName ~= SNODE_NAME then
		local function _HeartBeatErrFunc()			-- 不同节点的需要检测是否宕掉
			_dealwith_disconnectgate(servername)
		end
		DPCLUSTER.heartbeat(_HeartBeatErrFunc, serverinfo.nodeName)
	end
end

function CMD.reregister_gate(servername, serverinfo)
	local server = assert(server_list[servername])
	assert(serverinfo.address == server.address)
	assert(serverinfo.nodeName == server.nodeName)
	server.port = serverinfo.port
	server.sport = serverinfo.sport or serverinfo.port
	server.gate_ip = serverinfo.gate_ip
end

function CMD.get_serveraddr_nodename(gatename)
	local serverinfo = server_list[gatename]
	if serverinfo then
		return serverinfo.address, serverinfo.nodeName
	end
end

function CMD.logout(urs)			-- gate服务退出要调用这里用户谁离线或者被踢了
	local u = acct_online[urs]
	if u then
		if u.servername then
			local serverinfo = server_list[u.servername]
			if serverinfo and serverinfo.online_cnt >= 1 then
				serverinfo.online_cnt = serverinfo.online_cnt - 1
			end
		end
		acct_online[urs] = nil
	end
end

function CMD.shutdown()
	is_shuntdown = true
	for _servername, _serverinfo in pairs(server_list) do
		if _serverinfo.isvalid then
			_serverinfo.isvalid = false			-- 设置成无效的
			local nsvr = _serverinfo.node_svr
			shutdown_cs(nsvr.call.shutdown)		-- 某个gated关服不成功则报错
		end
	end
end

local function _ForeachNodeKick()
	for _servername, _serverinfo in pairs(server_list) do
		if _serverinfo.isvalid then
			local nsvr = _serverinfo.node_svr
			shutdown_cs(nsvr.call.allkick)		-- 踢出gated的所有玩家
		end
	end
end

function CMD.allkick(isImmd)
	if isImmd then
		player_allkick_time = false
		_ForeachNodeKick()
	else
		if not player_allkick_time then						-- 只是在没踢下线的情况下才设置
			player_allkick_time = os.time() + 2 * 60 + 30	-- 默认2分钟半后再踢下线
		end
	end
end

function CheckAllKick()
	if player_allkick_time and os.time() >= player_allkick_time then
		player_allkick_time = false
		_ForeachNodeKick()
	end
end

-- 关闭某个网关
function CMD.shutdown_gate(servername)
	local serverinfo = assert(server_list[servername])
	if serverinfo.isvalid then
		serverinfo.isvalid = false
		local nsvr = serverinfo.node_svr
		shutdown_cs(nsvr.call.shutdown)
	end
end

-- 某个activity重新启动了需要所有网关刷一遍其玩家信息到activity中创建一份
function CMD.reconnect_activity(server_name)
	for _servername, _serverinfo in pairs(server_list) do
		if _serverinfo.isvalid then
			local nsvr = serverinfo.node_svr
			nsvr.call.reconnect_activity(server_name)
		end
	end
end

function CMD.new_uid(corp_id, server_id)
	-- return lutil.new_uid(server_id or host_id, skynet.self())
end

function CMD.is_forbiddenlogin(usr)
	-- return FORBIDDEN.isForbiddenLogin(usr)
end


-- SERVICE -------------------------------------------
function SERVER.login_handler(usr, uid, corp_id, secret, extData)
	-- only one can login, because disallow multilogin
	local last = acct_online[usr]
	if last then
		local lsvr = last.node_svr
		local ok, err = pcall(lsvr.call.kick, usr, last.uid, true)
		if not ok then
			error("kick error")
		end
	end
	if acct_online[usr] then
		error(string.format("usr %s is already online", usr))
	end

	local serverinfo = nil
	-- local isForbidden, sType, leftTime = FORBIDDEN.isForbiddenLogin(usr)
	-- if isForbidden then
	-- 	return false, "forbidden", sType, leftTime
	-- else
		serverinfo = assert(get_rserver(), "unknown server")
		local nsvr = serverinfo.node_svr
		local online_cnt = nsvr.call.login(usr, uid, corp_id, secret, extData)
		acct_login[usr] = {
			address = serverinfo.address,
			nodeName = serverinfo.nodeName,
			node_svr = nsvr,
			uid = uid,
			servername = serverinfo.servername,
		}
		serverinfo.online_cnt = online_cnt
	-- end

	return true, serverinfo.gate_ip, serverinfo.port, serverinfo.sport
end

function SERVER.command_handler(command, ...)
	local f = assert(CMD[command], command)
	return f(...)
end


function Accept(conf, s, fd, addr)
	if is_shuntdown then
		-- We haven`t call socket.start, so use socket.close_fd rather than socket.close.
		socket.close_fd(fd)
		return
	end
	if not has_serverlist() then
		-- We haven`t call socket.start, so use socket.close_fd rather than socket.close.
		socket.close_fd(fd)
		return
	end

	-- call slave auth
	local ssvr = PROXYSVR.GetProxy(s, DPCLUSTER_NODE.self)
	local ok, urs, uid, corp_id, secret, extData = ssvr.call("auth", fd, addr)
	-- slave will accept(start) fd, so we can write to fd later

	if not ok then
		if urs == "socket error" then
			error(urs)
		end
		return
	end

	if not conf.multilogin then
		if acct_login[urs] then
			-- pbc_send_msg_snode(fd, _P("loginError"), {
				-- error_no = 2,
				-- err_desc = "other user logining..."
			-- })
			error(string.format("urs:%s is already login", urs))
		end
		acct_login[urs] = true
	end

	local ok, rOk, gate_ip, port, sport = xpcall(conf.login_handler, debug.traceback, urs, uid, corp_id, secret, extData)
	-- unlock login

	if ok then
		if rOk then
			-- 这里表示玩家已经进入游戏
			-- pbc_send_msg_snode(fd, _P("loginPlayerEnter"), {
				-- ip = gate_ip,
				-- port = port,
				-- sport = sport,
				-- secret = secret,
			-- })
		else
			if gate_ip == "forbidden" then
				-- pbc_send_msg_snode(fd, _P("roleForbiddenMsgBox"), {
					-- type = port or FORBIDDEN_TYPE.MCS,
					-- left_time = sport or (os.time() + 86400)
				-- })
				-- pbc_send_err_snode(fd, _P("loginPlayerEnter"), _E("loginForbidLogin"))
			else
				-- pbc_send_err_snode(fd, _P("loginPlayerEnter"), _E("loginConnectErr"))
			end
			-- LOG._WANR_F("usr:%s uid:%s can not login msg:%s", urs, uid, gate_ip or "nil")
			return
		end
	else
		-- 这里验证通过了(密码md5那些)，但是有可能没有逻辑服务器，或者登录的时候逻辑有数据错误
		-- 或者玩家记录了在游戏，所以退出游戏的时候记得也要删除logind.lua登录信息
		-- pbc_send_err_snode（fd, _P("loginPlayerEnter"), _E("loginGetGateErr")）
		error(rOk)
	end
end

local balance = 1
function AcceptClient(fd, addr, conf)
	local s = slave_pool[balance]
	balance = balance + 1
	if balance > #slave_pool then
		balance = 1
	end
	skynet.error("logind master client connect:", fd, addr)
	local ok, err = xpcall(Accept, debug.traceback, conf, s, fd, addr)
	if not ok then
		if err ~= socket_error then
			-- LOG.LOG_EVENT(LOGIND_ERRFILE, string.format("invalid client (fd = %d) error = %s", fd, err))
		end
	end
	if is_websocket then
		local ssvr = PROXYSVR.GetProxy(s, DPCLUSTER_NODE.self)
		ssvr.send("closews", fd, addr)
	else
		-- We haven`t call socket.start, so use socket.close_fd rather than socket.close.
		socket.close_fd(fd)
	end
end

-- 重新监听另外一个端口
function CMD.relisten(conf)
	local host = conf.host or "::"
	local port = assert(tonumber(conf.port))
	local backlog = conf.backlog or 128
	local balance = 1

	SERVER.host = host
	SERVER.port = port
	SERVER.backlog = backlog

	skynet.error(string.format("login server relisten at %s:%d:%d", host, port, backlog))
	local ENV = getfenv(1)
	assert(ENV.Accept)
	local oLSocket = listen_socket
	assert(oLSocket)
	listen_socket = socket.listen(host, port, backlog)
	socket.close(oLSocket)	-- 关闭旧的socket

	socket.start(listen_socket, function (fd, addr)
		AcceptClient(fd, addr, SERVER)
	end)
end

function launch_master(conf)
	local instance = conf.instance or 8
	assert(instance > 0)
	local host = conf.host or "::"
	local port = assert(tonumber(conf.port))
	local backlog = conf.backlog or 128

	-- lutil.set_checkuid_service(skynet.self())

	skynet.dispatch("lua", function (_, source, command, ...)
		skynet.ret(skynet.pack(conf.command_handler(command, ...)))
	end)

	for i = 1, instance do
		table.insert(slave_pool, skynet.newservice(SERVICE_NAME))
	end

	skynet.error(string.format("login server listen at %s:%d:%d", host, port, backlog))
	listen_socket = socket.listen(host, port, backlog)
	socket.start(listen_socket, function (fd, addr)
		AcceptClient(fd, addr, conf)
	end)
end

function __init__()
	CALLOUT.CallFre("CheckAllKick", 3)
end