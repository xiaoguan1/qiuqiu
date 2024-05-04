----------------------------------------
-- 创建者：Ghost
-- 创建日期: 2019/08/02
-- 模块作用: activity服务对象存盘变量
----------------------------------------

local string = string
local paris = paris

-- 注意：
--		1.一般取名前加活动名，防止与别的模块的存盘名字冲突
--		2.如果字段是table格式的，那么在改变后要手动SetSave，否则不会存盘(测试服如果忘记了20秒会检测一边然后报错的)
--		3.不能在role里面用SetSave(已经没有SetSave函数了)

local SaveVars = {

role = {
	["BoxofficeSave"]			= "actsvc/boxofficeSave",			-- key为存盘字段，value为服务名字
	["Maze"]					= "actsvc/maze",
	["ChampionData"]			= "actsvc/champion",				-- 排位赛数据
	["ArenaMaxIntegral"]		= "actsvc/arena",					-- 竞技场历史最高积分
	["ArenaAttTotalWinCnt"]		= "actsvc/arena",					-- 竞技场进攻胜利总次数
	["BattleShareCnt"]			= "actsvc/chat",					-- 战斗分享次数
	["BattleShareTime"]			= "actsvc/chat",					-- 战斗分享次数刷新时间
	["ShieldRedChannel"]		= "actsvc/chat",					-- 设置屏蔽的频道
},

}

local ServiceRoleVars = {}
for _key, _serviceName in pairs(SaveVars.role) do
	if not ServiceRoleVars[_serviceName] then
		ServiceRoleVars[_serviceName] = {}
	end
	ServiceRoleVars[_serviceName][_key] = true
end

function GetSaveVars_All(name)
	return SaveVars[name]
end

function GetRoleVars_ByServiceName(serviceName)
	return ServiceRoleVars[serviceName]
end