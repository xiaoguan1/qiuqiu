--------------------------------------
-- 创建者：Ghost
-- 创建日期：2019/08/02

--------------------------------------
local skynet = require "skynet"
local assert = assert
local is_crossserver = skynet.getenv("is_cross") == "true" and true or false
assert(not is_crossserver, "cross service can not load rpc")
local is_testserver = skynet.getenv("is_testserver")

local PROXYSVR = Import("base/proxysvr.lua")
local assert = assert
local os_time = os.time
local coroutine = coroutine
local SERVICE_NAME = SERVICE_NAME
local DPCLUSTER_NODE = DPCLUSTER_NODE
local debug = debug
local _WARN = _WARN
local _ERROR = _ERROR
local error = error
local string = string
local sfind = string.find

local SELF_ADDR = skynet.self()
local SNODE_NAME = DPCLUSTER_NODE.self
local RPCTIMEOUT_SEC = 2
local SNODE_RPCTIMEOUT_SEC = 10
local RPCTIMEOUT_CHECKTIME = 200
local IS_AGENT = SERVICE_NAME == "agent"
local isCheckUsingRpc = true
local co2urs = nil
local modLastTime = nil
local modLastFuncName = {}
local objLastFuncName = {}
local objLastTime = nil
local TRACEBACK_TIPS_THRESHOLD = 128
local TIPS_THRESHOLD = nil
if is_testserver then
	TIPS_THRESHOLD = 12		-- 测试服12
else
	TIPS_THRESHOLD = 16		-- 正式服16，玩家比较多的情况下很容易出现多玩家在交互模块调用一样的接口
end

local MEAT_READONLY = {__newindex = function (t, k, v)
	error("read only")
end}


local POOL_TABLE = {}
local function _CreateTable(listener, timeout)
	local ctbl = POOL_TABLE[#POOL_TABLE]
	if ctbl then
		POOL_TABLE[#POOL_TABLE] = nil
		ctbl.listener = listener
		ctbl.eTime = os_time() + (timeout or RPCTIMEOUT_SEC)
		return ctbl
	else
		return {
			listener = listener,
			eTime = os_time() + (timeout or RPCTIMEOUT_SEC)
		}
	end
end
local function _AddCacheTable(tbl)
	if #POOL_TABLE >= 200 then
		return
	end
	tbl.listener = nil
	tbl.eTime = nil
	POOL_TABLE[#POOL_TABLE + 1] = tbl
end

LISTENER_FUNC = {}
LISTENER_NO = 0
local function _AddListener(listener, timeout)
	LISTENER_NO = LISTENER_NO + 1
	if LISTENER_NO > 100000000 then
		LISTENER_NO = 1
	end
	LISTENER_FUNC[LISTENER_NO] = _CreateTable(listener, timeout)
	return LISTENER_NO
end
local function _StealListener(no)
	local tbl = LISTENER_FUNC[no]
	if tbl then
		LISTENER_FUNC[no] = nil
		local listener = tbl.listener
		_AddCacheTable(tbl)
		return listener
	end
end


function IsCheckUsingRpc(isCheck)
	isCheckUsingRpc = isCheck
end

local function _CheckRpcMessage(funcName, sType, extS)
	if not isCheckUsingRpc then return end
	local nTime = os_time()
	local co = coroutine.running()
	if co2urs then
		co = co2urs[co] or co
	end
	if sType == "mod" then
		if modLastTime ~= nTime then
			modLastFuncName = {
				[funcName] = {
					cnt = 1,			-- 不会与co和urs冲突，urs会有 _serverid 作为结尾的
					[co] = 1,
				},
			}
			modLastTime = nTime
			return
		end
		modLastFuncName[funcName] = modLastFuncName[funcName] or {}
		if is_testserver then
			local nCnt = (modLastFuncName[funcName].cnt or 0) + 1
			modLastFuncName[funcName].cnt = nCnt
			if nCnt % TIPS_THRESHOLD == 0 then
				local msg = string.format("Warnning! Rpc mod:%s funcName:%s 1 send more than %s message", extS, funcName, nCnt)
				if nCnt == TIPS_THRESHOLD then
					_WARN(msg, debug.traceback())
				else
					_WARN(msg)
				end
			end
		end
		-- 同协程校验
		local cCnt = (modLastFuncName[funcName][co] or 0) + 1
		modLastFuncName[funcName][co] = cCnt
		if cCnt % TIPS_THRESHOLD == 0 then
			local msg = string.format("Warnning! Same coroutine rpc mod:%s funcName:%s co:%s 1 second more than %s message", extS, funcName, co, cCnt)
			if (is_testserver and cCnt == TIPS_THRESHOLD) or cCnt == TRACEBACK_TIPS_THRESHOLD then
				_ERROR(msg, debug.traceback())
			else
				_ERROR(msg)
			end
		end
	else
		if objLastTime ~= nTime then
			objLastFuncName = {
				[funcName] = {
					cnt = 1,
					[co] = 1,
				}
			}
			objLastTime = nTime
			return
		end
		objLastFuncName[funcName] = objLastFuncName[funcName] or {}
		if is_testserver then
			local nCnt = (objLastFuncName[funcName].cnt or 0) + 1
			objLastFuncName[funcName].cnt = nCnt
			if nCnt % TIPS_THRESHOLD == 0 then
				local msg = string.format("Warnning! Rpc obj:%s funcName:%s 1 second more than %s message", extS, funcName, nCnt)
				if nCnt == TIPS_THRESHOLD then
					_WARN(msg, debug.traceback())
				else
					_WARN(msg)
				end
			end
		end
		-- 同协程校验
		local cCnt = (objLastFuncName[funcName][co] or 0) + 1
		objLastFuncName[funcName][co] = cCnt
		if cCnt % TIPS_THRESHOLD == 0 then
			local msg = string.format("Warnning! Same coroutine use rpc obj:%s funcName:%s co:%s 1 second more than %s message", extS, funcName, co, nCnt)
			if (is_testserver and cCnt == TIPS_THRESHOLD) or cCnt == TRACEBACK_TIPS_THRESHOLD then
				_ERROR(msg, debug.traceback())
			else
				_ERROR(msg)
			end
		end
	end
end


local SERVICE_MAP = {
	-- 注意：actsvc/xxx活动的自动以xxx为名字的rpc
	-- 注意：crosssvc/xxx活动的自动以xxx为名字的rpc
	gameserver = {
		serviceName = "gameserver",
		svr = assert(PROXYSVR.GetProxyByServiceName("gameserver", "rpc")),
		cuse = {mod_call = true, obj_call = true, mod_send = "true", obj_send = "true"},
	},
	agent = {
		serviceName = "agent",
		svr = nil,	-- 特殊处理，因为不用agent有不同的service addr 和 node_name
		cuse = {obj_send = true, obj_cb_send = true, obj_recall_send = true},
	},
}




local function BindFunc(tbl, rpctype, reqtype)
	assert(rpctype == "mod" or rpctype == "obj" or rpctype == "obj_cb" or rpctype == "obj_recall")
	assert(reqtype == "send" or reqtype == "call")

	local function _Agent_Obj(tbl, rpctype, reqtype, _name, _sData, cache)
		tbl[_name] = setmetatable({}, {
			__index = function (t1, funcName)
				if not cache[funcName] then
					cache[funcName] = function (obj, ...)
						local agentSvr = PROXYSVR.GetProxy(obj:GetAgentAddress(), obj:GetAgentNodeName(), nil, "rpc")
						local id = obj:GetId()
						_CheckRpcMessage(funcName, "obj", id)
						return agentSvr[reqtype][rpctype](id, funcName, ...)
					end
				end
				return cache[funcName]
			end,
			__newindex = function (t, k, v)
				error("read only")
			end
		})
	end

	local function _Agent_Obj_Cb(tbl, rpctype, reqtype, _name, _sData, cache)
		tbl[_name] = setmetatable({}, {
			__index = function (t1, funcName)
				if not cache[funcName] then
					cache[funcName] = function (listener,obj, ...)
						if type(listener) ~= "function" then
							error(string.format("1st param must be function, serviceName:%s, functionName:%s", _name, funcName))
						end
						local nodeName = obj:GetAgentNodeName()
						local to = SNODE_NAME == nodeName and SNODE_RPCTIMEOUT_SEC or RPCTIMEOUT_SEC
						local lNo = _AddListener(listener, to)
						local agentSvr = PROXYSVR.GetProxy(obj:GetAgentAddress(), nodeName, nil, "rpc")
						local id = obj:GetId()
						_CheckRpcMessage(funcName, "obj", id)
						return agentSvr[reqtype][rpctype](id, funcName, SELF_ADDR, SNODE_NAME, lNo, ...)
					end
				end
				return cache[funcName]
			end,
			__newindex = function (t, k, v)
				error("read only")
			end
		})
	end

	local function _Agent_Obj_Recall(tbl, rpctype, reqtype, _name, _sData, cache)
		tbl[_name] = setmetatable({}, {
			__index = function (t1, funcName)
				if not cache[funcName] then
					cache[funcName] = function (listener, obj, ...)
						if type(listener) ~= "function" then
							error(string.format("1st param must be function, serviceName:%s, functionName:%s", _name, funcName))
						end
						local nodeName = obj:GetAgentNodeName()
						local to = SNODE_NAME == nodeName and SNODE_RPCTIMEOUT_SEC or RPCTIMEOUT_SEC
						local lNo = _AddListener(listener, to)
						local agentSvr = PROXYSVR.GetProxy(obj:GetAgentAddress(), nodeName, nil, "rpc")
						local id = obj:GetId()
						_CheckRpcMessage(funcName, "obj", id)
						return agentSvr[reqtype][rpctype](id, funcName, SELF_ADDR, SNODE_NAME, lNo, ...)
					end
				end
				return cache[funcName]
			end,
			__newindex = function (t, k, v)
				error("read only")
			end
		})
	end

	local function _Other_Mod(tbl, rpctype, reqtype, _name, _sData, cache)
		tbl[_name] = setmetatable({}, {
			__index = function (t1, tModName)
				if not cache[tModName] then
					if sfind(tModName, ":") then
						local namedData = CROSS_ACTNAME_IPPORTSVC_CONTAINSUB[_name]
						if not namedData then
							error("not cross actname ipportsvc:" .. _name)
						end
						local named = namedData.named
						local cache1 = {}
						cache[tModName] = setmetatable({}, {
							__index = function (t1, modName)
								if not cache1[modName] then
									local cache2 = {}
									cache1[modName] = setmetatable({}, {
										__index = function (t2, funcName)
											if not cache2[funcName] then
												local proxySvr = assert(PROXYSVR.GetProxy(named, tModName, nil, "rpc"))
												cache2[funcName] = function (...)
													_CheckRpcMessage(funcName, "mod", modName)
													return proxySvr[reqtype][rpctype](modName, funcName, ...)
												end
											end
											return cache2[funcName]
										end,
										__newindex = function (t, k, v)
											error("read only")
										end
									})
								end
								return cache1[modName]
							end,
							__newindex = function (t, k, v)
								error("read only")
							end
						})
					else
						local cache2 = {}
						cache[tModName] = setmetatable({}, {
							__index = function (t2, funcName)
								if not cache2[funcName] then
									cache2[funcName] = function (...)
										local svr = _sData.svr
										if not svr then
											error(string.format("actName:%s not proxy!", _name))
										end
										_CheckRpcMessage(funcName, "mod, tModName")
										return svr[reqtype][rpctype](tModName, funcName, ...)
									end
								end
								return cache2[funcName]
							end,
							__newindex = function (t, k, v)
								error("read only")
							end
						})
					end
				end
				return cache[tModName]
			end,
			__newindex = function (t, k, v)
				error("read only")
			end
		})
	end

	local function _Other_obj(tbl, rpctype, reqtype, _name, _sData, cache)
		tbl[_name] = setmetatable({}, {
			__index = function (t1, funcName)
				if not cache[funcName] then
					if NAME_SERVER_NODE[_sData.serviceName].servercross then
						cache[funcName] = function (obj, ...)
							local proxySvr = PROXYSVR.GetProxyByServiceName(_sData.serviceName, "rpc", obj:GetServerId())
							local id = obj:GetId()
							_CheckRpcMessage(funcName, "obj", id)
							return proxySvr[reqtype][rpctype](id, funcName, ...)
						end
					else
						cache[funcName] = function (obj, ...)
							local id = obj:GetId()
							_CheckRpcMessage(funcName, "obj", id)
							return _sData.svr[reqtype][rpctype](id, funcName, ...)
						end
					end
				end
				return cache[funcName]
			end,
			__newindex = function (t, k, v)
				error("read only")
			end
		})
	end

	local function _Pfcross_ServerCache(ismult, tbl, rpctype, reqtype, _name, _sData, cache, serverId, subServiceName)
		local cache1 = {}
		cache[serverId] = setmetatable({}, {
			__index = function (t1, modName)
				if not cache1[modName] then
					local cache2 = {}
					cache1[modName] = setmetatable({}, {
						__index = function (t2, funcName)
							cache2[funcName] = cache2[funcName] or function (...)
								-- 实时拿，因为可能不一样
								local proxySvr = nil
								if ismult then
									proxySvr = PROXYSVR.GetMultPFCrossProxy(_sData.serviceName, "rpc", serverId, subServiceName)
								else
									proxySvr = PROXYSVR.GetPFCrossProxy(_sData.serviceName, "rpc", serverId, subServiceName)
								end
								-- 如果没有proxySvr，如果是send的则不管(_WARN一下)，如果是call的要报错
								if proxySvr then
									_CheckRpcMessage(funcName, "mod", modName)
									return proxySvr[reqtype][rpctype](modName, funcName, ...)
								elseif reqtype == "call" then
									error(string.format("_Pfcross_ServerCache not serverName:%s serverId:%s proxySvr! May the activity hasn't started or node restart", _sData.serviceName, serverId))
								else
									_WARN_F("_Pfcross_ServerCache not serverName:%s serverId:%s proxySvr! May the activity hasn't started or node restart", _sData.serviceName, serverId)
								end
							end
							return cache2[funcName]
						end,
						__newindex = function (t, k, v)
							error("read only")
						end
					})
				end
				return cache1[modName]
			end,
			__newindex = function (t, k, v)
				error("read only")
			end
		})
	end

	local function _Pfcross_Mod(tbl, rpctype, reqtype, _name, _sData, cache, ismult)
		tbl[_name] = setmetatable({}, {
			__index = function (t1, param)
				local pt = type(param)
				if pt == "number" then
					if not cache[param] then
						local serverId = param
						_Pfcross_ServerCache(ismult, tbl, rpctype, reqtype, _name, _sData, cache, serverId)
					end
					return cache[param]
				else
					if not cache[param] then
						-- param是子服务名
						local subShortServiceName = param
						local mainServiceData = CROSS_NAMED_SERVER_NODE[_sData.serviceName]
						if not mainServiceData then
							error("not mainServiceData by serviceName:" .. _sData.serviceName)
						end
						local subServiceName = "crosssvc/" .. subShortServiceName
						if not mainServiceData.subsvc or not mainServiceData.subsvc[subServiceName] then
							error(string.format("not subShortServiceName:%s by mainServiceData:%s", subServiceName, _sData.serviceName))
						end
						local cache1 = {}
						cache[param] = setmetatable({}, {
							__index = function (t2, serverId)
								if type(serverId) ~= "number" then
									error("pfcross subService rpc need RPC.mod_sendorcall.mainService.subService[serverId].modName.funcName")
								end
								if not cache1[serverId] then
									_Pfcross_ServerCache(ismult, tbl, rpctype, reqtype, _name, _sData, cache1, serverId, subServiceName)
								end
								return cache1[serverId]
							end,
							__newindex = function (t, k, v)
								error("read only")
							end
						})
					end
					return cache[param]
				end
			end,
			__newindex = function (t, k, v)
				error("read only")
			end
		})
	end

	local function _Pfcross_Obj(tbl, rpctype, reqtyp, _name, _sData, cache, ismult)
		tbl[_name] = setmetatable({}, {
			__index = function (t1, funcName)
				if not cache[funcName] then
					cache[funcName] = function (obj, ...)
						local serverId = obj:GetServerId()
						local proxySvr = nil
						if ismult then
							proxySvr = PROXYSVR.GetMultPFCrossProxy(_sData.serviceName, "rpc", serverId, _sData.serviceName)
						else
							proxySvr = PROXYSVR.GetPFCrossProxy(_sData.serviceName, "rpc", serverId, _sData.serviceName)
						end
						-- 如果没有proxySvr，如果是send的则不管(_WARN一下),如果是call的要报错
						if proxySvr then
							local id = obj:GetId()
							_CheckRpcMessage(funcName, "obj", id)
							return proxySvr[reqtype][rpctype](id, funcName, ...)
						elseif reqtype == "call" then
							error(string.format("_Pfcross_Obj not serverName:%s serverId:%s proxySvr! May the activity hasn't started or node restart", _sData.serviceName, serverId))
						else
							_WARN_F("_Pfcross_Obj not serverName:%s serverId:%s proxySvr! May the activity hasn't started or node restart", _sData.serviceName, serverId)
						end
					end
				end
				return cache[funcName]
			end,
			__newindex = function (t, k, v)
				error("read only")
			end
		})
	end

	local BIND_FUNCMAP = {
		["agent"] = {					-- agent服务
			["obj"] = _Agent_Obj,
			["obj_cb"] = _Agent_Obj_Cb,
			["obj_recall"] = _Agent_Obj_Recall,
		},
		["pfcross"] = {					-- 单平台跨服服务
			["mod"] = _Pfcross_Mod,
			["obj"] = _Pfcross_Obj,
		},
		["multpfcross"] = {				-- 多平台跨服服务
			["mod"] = _Pfcross_Mod,
			["obj"] = _Pfcross_Obj,
		},
		["other"] = {					-- 其他服务
			["mod"] = _Other_Mod,
			["obj"] = _Other_obj,
		},
	}

	for _name, _sData in pairs(SERVICE_MAP) do
		if _sData.serviceName ~= SERVICE_NAME then
			if _sData.cuse[rpctype .. "_" .. reqtype] then
				local cache = {}
				if _name == "agent" then
					assert(rpctype == "obj" or rpctype == "obj_cb" or rpctype == "obj_recall")
					assert(reqtype ~= "call")
					BIND_FUNCMAP["agent"][rpctype](tbl, rpctype, reqtype, _name, _sData, cache)
				elseif _sData.ispfcross then
					BIND_FUNCMAP["pfcross"][rpctype](tbl, rpctype, reqtype, _name, _sData, cache, false)
				elseif _sData.ismultpfcross then
					BIND_FUNCMAP["multpfcross"][rpctype](tbl, rpctype, reqtype, _name, _sData, cache, true)
				else
					BIND_FUNCMAP["other"][rpctype](tbl, rpctype, reqtype, _name, _sData, cache)
				end
			end
		end
	end
end


function BindAllFunc()
	mod_call = {}
	obj_call = {}
	mod_send = {}
	obj_send = {}
	obj_cb_send = {}
	obj_recall_send = {}

	BindFunc(mod_call, "mod", "call")
	BindFunc(obj_call, "obj", "call")
	BindFunc(mod_send, "mod", "send")
	BindFunc(obj_send, "obj", "send")
	BindFunc(obj_cb_send, "obj_cb", "send")
	BindFunc(obj_recall_send, "obj_recall", "send")

	setmetatable(mod_call, MEAT_READONLY)
	setmetatable(obj_call, MEAT_READONLY)
	setmetatable(mod_send, MEAT_READONLY)
	setmetatable(obj_send, MEAT_READONLY)
	setmetatable(obj_cb_send, MEAT_READONLY)
	setmetatable(obj_recall_send, MEAT_READONLY)
end

function FCheck()
	local nTime = os_time()
	-- 测试超时函数，如果超时则调用false, "timeout error"
	local delListener = nil
	for _no, _data in pairs(LISTENER_FUNC) do
		if _data.eTime < nTime then
			LISTENER_FUNC[_no] = nil
			local listener = _data.listener
			_ERROR("FCheck timeout error:", _no)
			if not delListener then
				delListener = {}
			end
			table.insert(delListener, listener)
		end
	end
	if delListener then
		for _, listener in pairs(delListener) do
			TryCall(listener, false, "timeout error")
		end
	end
end

function __init__()
    BindAllFunc()
	-- 注意：检测是否有rpc网络断开所有才使用fork替代callout，一般不能使用fork
	--		用fork需要告诉主程，让主程来判断
	local ENV = getfenv(1)
	assert(ENV.FCheck)
	skynet.fork(function ()
		while true do
			skynet.sleep(RPCTIMEOUT_CHECKTIME)
			TryCall(ENV.FCheck)		-- 一定要有ENV，这样可以达到热更FCheck(这是使用skynet.fork的缺陷)
		end
	end)
end
