---------------------------------
-- 模块作用：char类的基类，char包括(role, hero, npc, item)
---------------------------------

local os = os
local Super = Super
local setmetatable = setmetatable

local TmpBaseChar = {
	__ClassType = "<basechar>",
	__data = {},		-- 玩家数据存储区，其中的变量可参考VARNAME
}

clsBaseChar = clsObject:Inherit(TmpBaseChar)

function clsBaseChar:__init__(OCI)
	Super(clsBaseChar).__init__(self, OCI)
	self.__ID = nil		-- 对象ID
end

function clsBaseChar:GetId()
	return self.__ID
end

-- 用metatable实现继承，这样子类继承自clsBaseChar时，可以通过元表功能实现继承
function clsBaseChar:Inherit(o)
	o = o or {}
	setmetatable(o, {__index = self})
	o.__SuperClass = self
	return o
end

function clsBaseChar:SetId(id)
	self.__ID = id
	return id
end

function clsBaseChar:GetName()
	assert("should add in subclass")
end

function clsBaseChar:OnCreate(OCI)
	local id = OCI.__ID or UTIL.NewId()
	self.__ID = id
	CHAR_MGR.AddCharId(id, self)
end

-- 销毁一个Item
function clsBaseChar:Destroy()
	local id = self:GetId()
	CHAR_MGR.RemoveCharId(id)
	Super(clsBaseChar).Destroy(self)
end

-- function clsBaseChar:CallGlobalModBattleSignMarkFunc(fId, battleType, ...)
-- 	local gmBattleSignMarkFunc = self._gmBattleSignMarkFunc
-- 	if gmBattleSignMarkFunc and gmBattleSignMarkFunc[battleType] and gmBattleSignMarkFunc[battleType].fId == fId then
-- 		local func = gmBattleSignMarkFunc[battleType].func
-- 		gmBattleSignMarkFunc[battleType].fId = nil
-- 		gmBattleSignMarkFunc[battleType].func = nil
-- 		return func(fId, ...)
-- 	else
-- 		if self.IsPlayer and self.IsPlayer() then
-- 			-- 玩家提示
-- 			self:Notify(_T("battle0"))
-- 			local msg = string.format("CallGlobalModBattleSignMarkFunc not battle fId:%s battleType:%s name:%s uid:%s", tostring(fId), self:GetName(), self:GetUid())
-- 			_ERROR(msg)
-- 			error(msg)
-- 		end
-- 	end
-- end

-- function clsBaseChar:SetGlobalModBattleSignMarkFunc(fId, battleType, func)
-- 	local gmBattleSignMarkFunc = self._gmBattleSignMarkFunc
-- 	if not gmBattleSignMarkFunc then
-- 		gmBattleSignMarkFunc = {}
-- 		self._gmBattleSignMarkFunc = gmBattleSignMarkFunc
-- 	end

-- 	if gmBattleSignMarkFunc[battleType] then
-- 		gmBattleSignMarkFunc[battleType].fId = fId
-- 		gmBattleSignMarkFunc[battleType].func = func
-- 	else
-- 		gmBattleSignMarkFunc[battleType] = {
-- 			fId = fId,
-- 			func = func,
-- 		}
-- 	end
-- end
