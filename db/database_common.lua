local skynet = require "skynet"
local CommonDB = require "common_db"
local DATABASE_NAME = DATABASE_NAME
local DATABASE_MESSAGE_BOARD_TABLES = DATABASE_MESSAGE_BOARD_TABLES
local defaultServerId = tonumber(skynet.getenv("server_id"))

local M = {}

------------------------------------------------ message_board库 ------------------------------------------------
-- 玩家是否已经存在
function M.IsHasPlayer(playerId, db)
	if not playerId then return end

	db = db or CommonDB.Getdb(DATABASE_NAME.MESSAGE_BOARD)
	if not db then
		error(string.format("database_common IsHasPlayer error, playerId:[%s]", playerId))
	end

	local res = CommonDB.select(db, DATABASE_MESSAGE_BOARD_TABLES.ROLES, "*", "playerId", playerId)
	return res and true or false
end

-- 检查玩家的playerId和passwd是否正确
function M.CheckAccount(playerId, passwd, db)
	if not (playerId and passwd) then return end

	db = db or CommonDB.Getdb(DATABASE_NAME.MESSAGE_BOARD)
	if not db then
		error(string.format("database_common CheckAccount error, playerId:[%s] passwd:[%s]", playerId, passwd))
	end

	local isOk, res = CommonDB.select(db, DATABASE_MESSAGE_BOARD_TABLES.ROLES, nil, "playerId", playerId)
	if isOk and res and res[1] and res[1].passwd == passwd then
		return true
	end
end

-- 添加新玩家
function M.AddRoles(playerId, passwd, db)
	if not (playerId and passwd) then return end

	db = db or CommonDB.Getdb(DATABASE_NAME.MESSAGE_BOARD)
	if not db then
		error(string.format("database_common AddRoles error, playerId:[%s] passwd:[%s]", playerId, passwd))
	end

	local column = "playerId, passwd"
	local values = string.format("%s, %s", playerId, passwd)

	local isOk, res = CommonDB.insert(db, DATABASE_MESSAGE_BOARD_TABLES.ROLES, column, values)
	if isOk then return true end
end

------------------------------------------------ common_db库 ------------------------------------------------
-- 根据服务器id获取相关配置（运营控制！！！）
function M.GetServerConfig(server_id, db)
	db = db or CommonDB.Getdb(DATABASE_NAME.COMMON_DB)
	if not db then
		error("database_common GetServerConfig db error")
	end

	server_id = server_id or defaultServerId
	local isOk, res = CommonDB.select(db, DATABASE_COMMON_DB_TABLES.SERVER_CONFIG, nil, "server_id", server_id)
	if isOk and res and res[1] then
		return res[1]
	end
end

return M

--[[
	目前数据库的增删查改的操作交由服务自身进行解决，不另起数据库服务进行统一管理。
]]