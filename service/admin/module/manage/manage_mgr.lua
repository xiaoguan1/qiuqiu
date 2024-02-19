local skynet = require "skynet"
local runconfig = require "runconfig"

function shutdown()		-- 关服
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

function ping()		-- ping所有服务
	print(os.time())
	print(skynet.time())
	return sys.dump(skynet.ret())
end

function mem()
	local proxy = PROXYSVR.GetProxy(".launcher")
	local ret = proxy.call.MEM()
	return sys.dump(ret)
end

function rt()		-- "ping一下所有服务，并获取相应时间差"
	local proxy = PROXYSVR.GetProxy(".launcher")
	local ret = proxy.call.SERVICE_RT()
	return sys.dump(ret)
end

function stat()
	local proxy = PROXYSVR.GetProxy(".launcher")
	local ret = proxy.call.SERVICE_STAT()
	return sys.dump(ret)
end

function service_mem()
	local proxy = PROXYSVR.GetProxy(".launcher")
	local ret = proxy.call.SERVICE_MEM()

	-- 将ret格式化 是返回的ret更好看
	local maxNamelen = 0
	local nameSort = {}
	local tmpRet = {}
	for _, _data in pairs(ret) do
		local serviceName = _data.serviceName
		tmpRet[serviceName] = _data
		table.insert(nameSort, serviceName)
		local len = string.len(serviceName)
		if len > maxNamelen then
			maxNamelen = len
		end
	end
	table.sort(nameSort)

	local dumpT = {}
	local format = string.format("%%%ds : luamem:%%-20s\tcmem:%%-20s", maxNamelen)
	print("format ", format)
	for _, _serviceName in pairs(nameSort) do
		local _data = tmpRet[_serviceName]
		table.insert(dumpT, string.format(
			format, _serviceName, _data.luamem .. " (Kb)", _data.cmem .. " (Kb)"
		))
	end

	local msg = table.concat(dumpT, "\n") .. "\n"
	return msg
end

function servertime(args)
	local ymdhms = args and args.args
	if not ymdhms then
		_ERROR("servertime args error!!!")
		return
	end

	local proxy = PROXYSVR.GetProxy(".launcher")
	if ymdhms == "reset" then
		_WARN("reset servertime!!!")
		proxy.send.SERVICE_STARTTIME(0)
	else
		local newSec = os.Sec2DateStr(ymdhms)
		if not newSec then return end
		local now = os.time()
		local diff = newSec - now
		_WARN_F("changing servertime[%s] to [%s] offset[%s]", now, newSec, diff)
		proxy.send.SERVICE_STARTTIME(diff)
	end
	_INFO_F("change server time successful!!! ")
end