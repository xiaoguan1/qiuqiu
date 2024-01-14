local skynet = require "skynet"
local core = require "skynet.core"
require "skynet.manager"	-- import manager apis
local string = string
local codecache = require "skynet.codecache"

local services = {}
local command = {}
local instance = {} -- for confirm (function command.LAUNCH / command.ERROR / command.LAUNCHOK)
local launch_session = {} -- for command.QUERY, service_address -> session

local function handle_to_address(handle)
	return tonumber("0x" .. string.sub(handle , 2))
end

local NORET = {}

-- skynet服务更新文件
function command.UPDATE_CMD(_, service_name, updatefile)
	codecache.clearone(updatefile)
	for _address, _v in pairs(services) do
		local sp_tbl = string.split(_v, " ")
		if sp_tbl and sp_tbl[2] and sp_tbl[2] == service_name then
			local ok, ret, err = pcall(skynet.call, "update", "update_file", service_name, updatefile)
			skynet.error(skynet.address(_address), _v, updatefile, ok, ret, err)
		end
	end
end

-- 获取每个服务的相应时间
function command.SERVICE_RT()
	local ret = {}
	for _address, _v in pairs(services) do
		local sp_tbl = string.split(_v, " ")
		local service_name = sp_tbl and sp_tbl[2]
		if service_name then
			local sTime = os.realtime()
			skynet.call(_address, "debug", "PING")
			local eTime = os.realtime()
			ret[service_name .. string.format("[:%08x]", _address)] = eTime - sTime
		end
	end
	return ret
end

-- 判断所有服务的信息
function command.SERVICE_STAT()
	local ret = {}
	for _address, _v in pairs(services) do
		local sp_tbl = string.split(_v, " ")
		local service_name = sp_tbl and sp_tbl[2]
		if service_name then
			local ok, stat = pcall(skynet.call, _address, "debug", "STAT")
			if ok then
				ret[service_name .. string.format("[:%08x]", _address)] = stat
			end
		end
	end
	return ret
end


function command.LIST()
	local list = {}
	for k,v in pairs(services) do
		list[skynet.address(k)] = v
	end
	return list
end

local function list_srv(ti, fmt_func, ...)
	local list = {}
	local sessions = {}
	local req = skynet.request()
	for addr in pairs(services) do
		local r = { addr, "debug", ... }
		req:add(r)
		sessions[r] = addr
	end
	for req, resp in req:select(ti) do
		local addr = req[1]
		if resp then
			local stat = resp[1]
			list[skynet.address(addr)] = fmt_func(stat, addr)
		else
			list[skynet.address(addr)] = fmt_func("ERROR", addr)
		end
		sessions[req] = nil
	end
	for session, addr in pairs(sessions) do
		list[skynet.address(addr)] = fmt_func("TIMEOUT", addr)
	end
	return list
end

function command.STAT(addr, ti)
	return list_srv(ti, function(v) return v end, "STAT")
end

function command.KILL(_, handle)
	skynet.kill(handle)
	local ret = { [skynet.address(handle)] = tostring(services[handle]) }
	services[handle] = nil
	return ret
end

function command.MEM(addr, ti)
	return list_srv(ti, function(kb, addr)
		local v = services[addr]
		if type(kb) == "string" then
			return string.format("%s (%s)", kb, v)
		else
			return string.format("%.2f Kb (%s)",kb,v)
		end
	end, "MEM")
end

function command.GC(addr, ti)
	for k,v in pairs(services) do
		skynet.send(k,"debug","GC")
	end
	return command.MEM(addr, ti)
end

function command.REMOVE(_, handle, kill)
	services[handle] = nil
	local response = instance[handle]
	if response then
		-- instance is dead
		response(not kill)	-- return nil to caller of newservice, when kill == false
		instance[handle] = nil
		launch_session[handle] = nil
	end

	-- don't return (skynet.ret) because the handle may exit
	return NORET
end

local function launch_service(service, ...)
	local param = table.concat({...}, " ")
	local inst = skynet.launch(service, param)
	local session = skynet.context()
	local response = skynet.response()
	if inst then
		services[inst] = service .. " " .. param
		instance[inst] = response
		launch_session[inst] = session
	else
		response(false)
		return
	end
	return inst
end

function command.LAUNCH(_, service, ...)
	launch_service(service, ...)
	return NORET
end

function command.LOGLAUNCH(_, service, ...)
	local inst = launch_service(service, ...)
	if inst then
		core.command("LOGON", skynet.address(inst))
	end
	return NORET
end

function command.ERROR(address)
	-- see serivce-src/service_lua.c
	-- init failed
	local response = instance[address]
	if response then
		response(false)
		launch_session[address] = nil
		instance[address] = nil
	end
	services[address] = nil
	return NORET
end

function command.LAUNCHOK(address)
	-- init notice
	local response = instance[address]
	if response then
		response(true, address)
		instance[address] = nil
		launch_session[address] = nil
	end

	return NORET
end

function command.QUERY(_, request_session)
	for address, session in pairs(launch_session) do
		if session == request_session then
			return address
		end
	end
end

-- for historical reasons, launcher support text command (for C service)

skynet.register_protocol {
	name = "text",
	id = skynet.PTYPE_TEXT,
	unpack = skynet.tostring,
	dispatch = function(session, address , cmd)
		if cmd == "" then
			command.LAUNCHOK(address)
		elseif cmd == "ERROR" then
			command.ERROR(address)
		else
			error ("Invalid text command " .. cmd)
		end
	end,
}

skynet.dispatch("lua", function(session, address, cmd , ...)
	cmd = string.upper(cmd)
	local f = command[cmd]
	if f then
		local ret = f(address, ...)
		if ret ~= NORET then
			skynet.ret(skynet.pack(ret))
		end
	else
		skynet.ret(skynet.pack {"Unknown command"} )
	end
end)

skynet.start(function() end)
