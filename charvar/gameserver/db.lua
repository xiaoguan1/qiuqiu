------------------------------------------
-- 创建者: Ghost
-- 创建日期: 2019/08/02
-- 模块作用: gameserver服务对象的存盘变量
------------------------------------------

local string = string
local paris = paris

-- 注意：
--      1.一般取名字前加活动名，防止与别的模块的存盘名冲突
local SaveVars = {

role = {
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

function GetSaveVars(name)
	return SaveVars[name]
end