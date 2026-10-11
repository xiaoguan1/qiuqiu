-----------------------------------------
-- 模块作用：所有类的基类。继承该类有2个好处
--              1.可以热更类
--              2.可以查询追踪类的内存泄露
-----------------------------------------
local skynet = require "skynet"
local is_testserver = (skynet.getenv("is_testserver") == "true") and true or false


globalClass = setmetatable({}, {__mode = "v"})		-- 管理全局对象

-- 暂时没有一个比较好的方法来防止将Class的table当成一个示例来使用
-- 大家命令一个Class的时候一定要和其产生的实例区别开来
clsObject = {
	-- 用于区别是否是一个对象 or Class or 普通table
	__ClassType = "<base class>"
}


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


-- 继承父类
function clsObject:Inherit(o)
	o = o or {}

	table.insert(globalClass, o)

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

-- 生成一个对象
function clsObject:New(...)
	local o = setmetatable({}, {__ObjectType="<base object>", __index = self})

	-- 初始化对象
	if o.__init__ then
		o:__init__(...)
	end

	return o
end

function clsObject:IsClass()
	return true
end

