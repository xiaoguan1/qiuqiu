-----------------------------------------
-- 模块作用：所有类的基类。继承该类有2个好处
--              1.可以热更类
--              2.可以查询追踪类的内存泄露
-----------------------------------------
local skynet = require "skynet"
local type = type
local table = table
local pairs = pairs
local select = select
local error = error
local assert = assert
local xpcall = xpcall
local getfenv = getfenv
local tcopy = table.copy
local tpack = table.pack
local tremove= table.remove
local tunpack = table.unpack
local tinsert = table.insert
local traceback = debug.traceback
local getmetatable = getmetatable
local setmetatable = setmetatable
local is_testserver = (skynet.getenv("is_testserver") == "true") and true or false

-- 全局类型列表
ClassTypeList = {}
-- 基础类库

-- 获取一个class的父类
function Super(TmpClass)
	return TmpClass.__SuperClass
end

-- 判断一个class或者对象是否
function IsSub(clsOrObj, Ancestor)
	local Temp = clsOrObj
	while 1 do
		local mt = getmetatable(Temp)
		if mt then
			Temp = mt.__index
			if Temp == Ancestor then
				return true
			end
		else
			return false
		end
	end
end

-- 暂时没有一个比较好的方法来防止将Class的table当成一个示例来使用
-- 大家命令一个Class的时候一定要和其产生的实例区别开来
clsObject = {
	-- 用于区别是否是一个对象 or Class or 普通table
	__ClassType = "<base class>"
}

function clsObject:Inherit(o)
	o = o or {}

	-- 没有对table属性做深拷贝，如果这个类有table属性应该在init函数中初始化
	-- 不应该把一个table属性放在class的定义中

	if not self.__SubClass then
		self.__SubClass = {}
		setmetatable(self.__SubClass, {__mode = "v"})
	end
	table.insert(self.__SubClass, o)

	-- 这里不能设置metatable，否则会导致copy错误！！！，要设置metatable必须放在子类里去弄
	-- setmetatable(o, {__index = self})
	for k, v in pairs(self) do
		if not o[k] then
			o[k] = v
		end
	end
	o.__SuperClass = nil
	o.__SuperClass = self

	return o
end

function clsObject:AttachToClass(Obj)
	setmetatable(Obj, {__ObjectType="<base object>", __index = self})
	return Obj
end

function clsObject:New(...)
	local o = {}

	-- 没有初始化对象的属性，对象属性应该在init函数中显示初始化
	-- 如果是子类，应该在自己的init函数中先调用父类的init函数

	self:AttachToClass(o)

	if o.__init__ then
		o:__init__(...)
	end

	return 0
end

function clsObject:__init__()
	-- nothing
end

local function _obj_check(...)
	if is_testserver then
		local n = select('#', ...)
		local arg = {...}
		for i = 1, n do
			if type(arg[i]) == "table" then
				if arg[i].__ClassType then		-- 是对象或者类
					error("param can not be obj or class")
				end
			end
		end
	end
end

local function _AddEventListener(isMajor, mKey, self, eId, env, funcName, ...)
	if type(env[funcName] ~= "function") then
		-- _ERROR_F("_AddEventListener env:%s, funcName:%s error, env[%s] not type function, %s", env, funcName, funcName, debug.traceback())
		return
	end
	_obj_check(...)
	local eData = self.__eventData
	if not eData then
		eData = {}
		self.__eventData = eData
	end

	local ed = eData[eId]
	if not ed then
		ed = {
			normal = {},
			major = {},
		}
		eData[eId] = ed
	end

	if isMajor then
		local nidx = nil
		ed.major[mKey] = ed.major[mKey] or {}
		for _no, _data in pairs(ed.major[mKey]) do
			if _data[1] == env and _data[2] == funcName then
				nidx = _no
				break
			end
		end

		if nidx then
			ed.major[mKey][nidx] = {
				env,
				funcName,
				tpack(...),
			}
		else
			tinsert(ed.major[mKey], {
				env,
				funcName,
				tpack(...),
			})
		end
	else
		local nidx = nil
		for _no, _data in pairs(ed.normal) do
			if _data[1] == env and _data[2] == funcName then
				nidx = _no
				break
			end
		end

		if nidx then
			ed.normal[nidx] = {
				env,
				funcName,
				tpack(...),
			}
		else
			tinsert(ed.normal, {
				env,
				funcName,
				tpack(...),
			})
		end
	end
	return true
end

-- 注册监听事件，此监听函数为调用环境的监听函数getfenv(2)[funcName]
-- @tparam type eId 事件id
-- @tparam type funcName 监听函数名,此监听函数为调用环境的监听函数getfenv(2)[funcName](self, ...[AddListener], ...[DispatchEvent])
-- @tparam type ...
-- @tparam boolean 添加成功则返回true,重复注册会覆盖旧的
-- @author ghost
function clsObject:AddListener(eId, funcName, ...)
	local env = getfenv(2)
	if not env then
		error("not env")
	end
	if eId == EVENT_ID.FUNCOPEN then
		-- _ERROR_F("EVENT_ID.FUNCOPEN may use AddMajorListener %s", debug.traceback())
	end
	return _AddEventListener(nil, nil, self, eId, env, funcName, ...)
end

-- 注册监听事件，此监听函数为对象的监听函数self[funcName]
-- @tparam type eId 事件id
-- @tparam type funcName 监听函数名,此监听函数为对象的监听函数self[funcName](self, ...[AddListener], ...[DispatchEvent])
-- @tparam type ...
-- @tparam boolean 添加成功则返回true,重复注册会覆盖旧的
function clsObject:AddObjListener(eId, funcName, ...)
	return _AddEventListener(nil, nil, self, eId, self, funcName, ...)
end

-- 注册监听事件，此监听函数为对象的监听函数getfenv(2)[funcName]
-- @tparam type eId 事件id
-- @tparam type mKey 为2级key，Dispatch的时候需要带上mKey，这样直接索引上。防止单一eId太多事件需要遍历耗性能
-- @tparam type funcName 监听函数名,此监听函数为调用环境的监听函数getfenv(2)[funcName](self, ...[AddListener], ...[DispatchEvent])
-- @tparam type ...
-- @tparam boolean 添加成功则返回true,重复注册会覆盖旧的
-- @author ghost
function clsObject:AddMajorListener(eId, mKey, funcName, ...)
	local env = getfenv(2)
	if not env then
		error("not env")
	end
	assert(mKey)
	if type(env[funcName]) ~= "function" then
		-- _ERROR_F("AddMajorListener env:%s, funcName:%s error, env[%s] not type function, %s", env, funcName, funcName, debug.traceback())")
		return
	end
	return _AddEventListener(true, mKey, self, eId, env, funcName, ...)
end

local function _CallFunc(self, eventData, ...)
	local ed = tcopy(eventData)		-- 防止事件里面有使用call，那么可能会破坏了lua的pairs，这样可能后续没有了某些函数调用
	for _, _data in pairs(ed) do
		local eargs = _data[3]
		local elen = eargs.n or #eargs
		local nargs = tpack(...)
		local alen = nargs.n or #nargs
		for i = 1, alen do
			eargs[elen + i] = nargs[i]
		end
		elen = elen + alen
		local ok, ret = xpcall(_data[1][_data[2]], traceback, self, tunpack(eargs, 1, elen))
		if not ok then
			-- _ERROR_F("DispatchEvent error, env:%s funcName:%s, ret:%s", _data[1], _data[2], ret)
		end
	end
end

function clsObject:DispatchEvent(eId, ...)
	local eData = self.__eventData
	if eData and eData[eId] then
		_obj_check(...)
		local majorKey = select(1, ...)
		if majorKey ~= nil and eData[eId].major[majorKey] and not table.empty(eData[eId].major[majorKey]) then
			-- 执行majorKey的List
			_CallFunc(self, eData[eId].major[majorKey], ...)
		end
		if not table.empty(eData[eId].normal) then
			_CallFunc(self, eData[eId].normal, ...)
		end
	end
end

local function _DelListener(isMajor, mKey, self, eId, env, funcName)
	local eData = self.__eventData
	if eData and eData[eId] then
		-- _WARN_F("_DelListener not eData, eId:%s", eId)
		return
	end
	local ed = eData[eId]
	if not ed then
		-- _WARN_F("_DelListener not eData, eId:%s", eId)
		return
	end

	if isMajor then
		local idx = nil
		for _no, _data in pairs(ed.major[mKey] or {}) do
			if _data[1] == env and _data[2] == funcName then
				idx = _no
				break
			end
		end
		if idx then
			tremove(ed.major[mKey], idx)
		end
	else
		local idx = nil
		for _no, _data in pairs(ed.normal) do
			if _data[1] == env and _data[2] == funcName then
				idx = _no
				break
			end
		end
		if idx then
			tremove(ed.normal, idx)
		end
	end

	return true
end

-- 删除事件
-- @tparam type eId 事件id
-- @tparam type funcName 监听函数名,此监听函数为调用环境的监听函数getfenv(2)[funcName]
-- @treturn boolean 删除成功则返回true
function clsObject:DelListener(eId, funcName)
	local env = getfenv(2)
	if not env then
		error("not env")
	end
	return _DelListener(nil, nil, self, eId, env, funcName)
end

-- 删除事件
-- @tparam type eId 事件id
-- @tparam type funcName 监听函数名,此监听函数为对象的监听函数self[funcName]
-- @treturn boolean 删除成功则返回true
function clsObject:DelObjListener(eId, funcName)
	return _DelListener(nil, nil, self, eId, self, funcName)
end

-- 删除事件
-- @tparam type eId 事件id
-- @tparam type mKey 为2级key
-- @tparam type funcName 监听函数名,此监听函数为对象的监听函数self[funcName]
-- @treturn boolean 删除成功则返回true
function clsObject:DelMajorListener(eId, mKey, funcName)
	local env = getfenv(2)
	if not env then
		error("not env")
	end
	assert(mKey)
	return _DelListener(true, mKey, self, eId, env, funcName)
end

function clsObject:IsClass()
	return true
end

function clsObject:Destroy()
	-- 所有对象释放的时候删除callout
	if CALLOUT then
		CALLOUT.RemoveAll(self)
	end
end

local function _Copy(src, rel)
	rel = rel or {}
	if type(src) ~= "table" then
		return rel
	end
	for k, v in pairs(src) do
		rel[k] = v
	end
	return rel
end

function clsObject:Update(OldSelf)
	if not self.__SubClass then
		return
	end
	for _, Sub in pairs(self.__SubClass) do
		local OldSub = _Copy(Sub)
		for k, _ in paris(self) do
			if Sub[k] == OldSelf[k] then
				Sub[k] = self[k]
			end
		end
		Sub:Update(OldSub)
	end
end

-- 个人注释：还不能用！！！！