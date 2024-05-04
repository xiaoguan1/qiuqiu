------------------------------------------
-- 创建者: Ghost
-- 创建日期: 2019/08/02
-- 模块作用: gameserver服务对象的存盘变量
------------------------------------------

local string = string
local paris = paris

local TmpVars = {

role = {
	"Uid",
	"Name",
	"Sex",
	"CorpId",	-- 创角平台
	"NCorpId",	-- 登录平台

	"GameSvrVar",
	"FriendData",			-- 好友数据
	"ClubData",
	"TowerData",
	"Hunt",					-- 公会狩猎
	"achlevelrewardact",	-- 等于送礼
	"FriendShip",
	"MailAct",				-- 活动邮件
	"LimitActiveOut",		-- 限时兑换掉落
	"MailReach",			-- 达标邮件
	"ThemeActData",			-- 主题活动
	"BraveFightData",		-- 勇者试炼数据
	"Gods",					-- 邪神降临
	"ServerActData",		-- 开服主题活动
	"GoldBadGeInfo",		-- 炼金徽章信息
	"IsYardTask",			-- 是否检测过分享码
	"DoubleHerPlot",		-- 双新英雄剧情副本
	"ArmyClubInfo",			-- 军团数据
	"MergeActData",			-- 合服活动
	"ShuguangFightData",	-- 曙光幻境英雄符文、赋能、星魂装备保存
	"TrainDummy",			-- 训练场
	"LinkActData",			-- 联动主题活动
	"Todayacttips",			-- 今日提示
	"LeagueChampoinHOFData",	-- 平台联赛名人堂数据
},

}

-- 将生成的内容插入到 "autogen-begin" 和 "autogen-end" 之前
function GenFile(filePath, data)
	local path = string.match(filePath, ".+%.lua")
	if not path then return end

	local content
	local rf = io.open(filePath, "r")
	if rf then
		content = rf:read("*a")
		rf:close()
	end

	if content then
		local sub
		data, sub = string.gsub(content, "(%-%-autogen%-begin).-(%-%-autogen%-end)", "%1" .. data .. "%2")
		assert(sub == 1, string.format("must insert into the file: %s once", filePath))
	else
		error("not file:" .. filePath)
	end

	local fd = assert(io.open(filePath, "w"))
	fd:write(data)
	fd:flush()
	fd:close()
end

local VAR_PATTERN_FORMAT = [[
function %s:Get%s()
	return self.%s.%s
end
function %s:Set%s(%s)
	self.%s.%s = %s
end
]]

local SAVE_PATTERN_FORMAT = [[
function %s:Get%s()
	return self.%s.%s
end
function %s:Set%s(%s)
	self.%s.%s = %s
end
]]

function table_member_key(Table, Value)
	for k, v in pairs(Table) do
		if v == Value then
			return k
		end
	end
	return nil
end

-- 生成文件绑定属性
function BindFuncFile(className, varList, saveVarList, filePath)
	local varListStr = ""
	for _, _varName in pairs(varList) do
		local saveStr = table_member_key(saveVarList, _varName) and "__data" or "__tmp"

		if className == "clsRole" and saveStr == "__data" then
			varListStr = varListStr .. string.format(SAVE_PATTERN_FORMAT,
				className, _varName, saveStr, _varName,
				className, _varName, _varName, saveStr, _varName, _varName
			) .. "\n"
		else
			varListStr = varListStr .. string.format(VAR_PATTERN_FORMAT,
				className, _varName, saveStr, _varName,
				className, _varName, _varName, saveStr, _varName, _varName
			) .. "\n"
		end
	end
	GenFile(filePath, "\n" .. varListStr .. "\n")
end

function gen()
	for _, _oneVar in pairs(TmpVars) do
		for _, _varName in pairs(_oneVar) do
			-- 存盘需要简单的命名方式，方便阅读与修改
			if not string.match(_varName, "^[%a_][%w_]*$") then
				error(string.format("%s is not var name", _varName))
			end
		end
	end

	dofile("charvar/gameserver/db.lua")
	-- 绑定属性文件
	BindFuncFile("clsRole", TmpVars.role, assert(GetSaveVars("role")), "service/gameserver/char/role/role.lua")
end

gen()