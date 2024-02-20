local skynet = require "skynet"
local xpcall = xpcall
local traceback = debug.traceback

-- 加载文件路径(先加载不依赖外部数据的模块)
local LOAD_FILES = {
	-- 常量（不依赖其他模块的变量）
	"./lualib/macros/macros_database.lua",
	"./lualib/macros/macros_common.lua",

	-- 协议
	"./protobuf/protoload/loadproto.lua",

	-- 其他
	"./lualib/base/log.lua",
}

for _, filepath in pairs(LOAD_FILES) do
	dofile(filepath)
end

-- 注册的协议
skynet.register_protocol({
	name = "callout",
	id = skynet.PTYPE_CALLOUT,
	unpack = skynet.unpack,
	pack = skynet.pack,
})

skynet.register_protocol({
	name = "dboperate",
	id = skynet.PTYPE_DATABASE_OPERATE,
	unpack = skynet.unpack,
	pack = skynet.pack,
})

if not setfenv then
	-- base on http://lua-users.org/lists/lua-l/2010-06/msg00314.html
	-- this assumes f is a function
	local function findenv(f)
		local level = 1
		repeat
			local name, value = debug.getupvalue(f, level)
			if name == '_ENV' then
				return level, value
			end
			level = level + 1
		until name == nil
		return nil
	end

	getfenv = function (f)
		if type(f) == "number" then
			f = debug.getinfo(f + 1, 'f').func
		end
		if f then
			return select(2, findenv(f))
		else
			return _G
		end
	end

	setfenv = function (f, t)
		local level = findenv(f)
		if level then debug.setupvalue(f, level, t) end
		return f
	end
end

-- 容错执行函数
local function _RetFunc(isOk, ...)
	if not isOk then
		print(...)	-- 缺了日志输出，暂用print代替
	end
	return isOk, ...
end

function TryCall(func, ...)
	return _RetFunc(xpcall(func, traceback, ...))
end

if SERVICE_NAME ~= "main" and not EVERY_NODE_SERVER[SERVICE_NAME] then
	DPCLUSTER_NODE = skynet.getenv("DPCLUSTER_NODE")
	CLUSTERCFG = skynet.getenv("CLUSTERCFG")

	if not DPCLUSTER_NODE then
		error("service env config error!")
	end

	DPCLUSTER_NODE = load("return" .. DPCLUSTER_NODE)()
	CLUSTERCFG = load("return" .. CLUSTERCFG)()

	DPCLUSTER_NODE.self = DPCLUSTER_NODE.main_ip_port
end