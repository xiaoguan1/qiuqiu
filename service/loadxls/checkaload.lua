local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
local is_testserver = skynet.getenv("is_testserver") == "true" and true or false

-- 示例
local function _CheckRobotData()
	local robotdata_xls = sharedata.query("RobotData")
	if type(robotdata_xls) ~= "table" or table.size(robotdata_xls) <= 0 then
		error("RobotData is not empty")
	end
end

-- 游戏启动加载玩配置表数据后检测
-- 检测配置表格是否符合要求（由于有些表格要使用别的表格才能做出判断，因此要等待所有表格加载完才可以检测）
function CheckAfterLoad()
	if not is_testserver then
		-- 不是测试服不用检验
		return
	end

	_CheckRobotData()
end