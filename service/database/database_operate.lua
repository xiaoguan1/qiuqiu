local skynet = require "skynet"
local mysql = require "skynet.db.mysql"
local DATABASE_NAME = DATABASE_NAME
local DATABASE_MESSAGE_BOARD_TABLES = DATABASE_MESSAGE_BOARD_TABLES
local defaultServerId = tonumber(skynet.getenv("server_id"))
local queue = require "skynet.queue"
local cjson = require "cjson"
CS = queue()
DB_CONNECT = {}

--[[
	策略1：数据库的增删查改的操作交由服务自身进行解决，不另起数据库服务进行统一管理。（特别注意要防范脏写脏读）
	策略2：起一个数据库的skynet服务，交由该服务进行读写操作(容易产生性能瓶颈，因为数据库的读写全靠该服务)
	
	当前采用的是策略2（目标：两种策略都实现，且优化策略2 起多个数据库的skynet服务）
]]

-- 内部接口 -----------------------------

-- 连接数据库
local function _Getdb(databaseName)
	if DB_CONNECT[databaseName] then
		return DB_CONNECT[databaseName]
	end

	if not (databaseName and table.is_has_value(DATABASE_NAME, databaseName)) then return end

	local function on_connect(db) db:query("set charset utf8") end
	local db = mysql.connect({
		host = "127.0.0.1",
		port = 3306,
		database = databaseName,
		user = "root",
		password = "root",
		max_pack_size = 1024 * 1024,
		on_connect = on_connect,
	})

	if not db then
		_ERROR_F("connect db fail! databaseName:%s", databaseName)
		return
	end

	DB_CONNECT[databaseName] = db
	return db
end

local function Getdb(databaseName)
	return CS(_Getdb, databaseName)
end


-- 查询数据
local function select(db, tableName, column, key, value)
	local sql = string.format("select %s from %s where %s=%s", column or "*", tableName, key, value)
	local res = db:query(sql)

	if not res["badresult"] and #res == 1 then
		--以roles表为例 正确结果的返回：res = {{ passwd = "123", playerId = "1001" }}
		return true, res
	end
end

-- 插入新数据
local function insert(db, tableName, column, values)
	if not (db and tableName and column and values) then return end

	local sql = string.format("insert into %s(%s) values (%s)", tableName, column, values)
	local res = db:query(sql)

	if not res["badresult"] and res.affected_rows == 1 then
		--以roles表为例 正确结果的返回：res = { warning_count = 0, insert_id = 0, server_status = 2, affected_rows = 1 }
		return true, res
	end
end


-- message_board数据库的外部接口 -----------------------------
-- 玩家是否已经存在
function IsHasPlayer(playerId)
	if not playerId then return end

	local db = Getdb(DATABASE_NAME.MESSAGE_BOARD)
	if not db then
		error(string.format("database_common IsHasPlayer error, playerId:[%s]", playerId))
	end

	local res = select(db, DATABASE_MESSAGE_BOARD_TABLES.ROLES, "*", "playerId", playerId)
	return res and true or false
end

-- 检查玩家的playerId和passwd是否正确
function CheckAccount(playerId, passwd)
	if not (playerId and passwd) then return end

	local db = Getdb(DATABASE_NAME.MESSAGE_BOARD)
	if not db then
		error(string.format("database_common CheckAccount error, playerId:[%s] passwd:[%s]", playerId, passwd))
	end

	local isOk, res = select(db, DATABASE_MESSAGE_BOARD_TABLES.ROLES, nil, "playerId", playerId)
	if isOk and res and res[1] and res[1].passwd == passwd then
		return true
	end
end

-- 添加新玩家
function AddRoles(playerId, passwd)
	if not (playerId and passwd) then return end

	local db = Getdb(DATABASE_NAME.MESSAGE_BOARD)
	if not db then
		error(string.format("database_common AddRoles error, playerId:[%s] passwd:[%s]", playerId, passwd))
	end

	local column = "playerId, passwd"
	local values = string.format("%s, %s", playerId, passwd)

	local isOk, res = insert(db, DATABASE_MESSAGE_BOARD_TABLES.ROLES, column, values)
	if isOk then return true end
end


-- common_db库的外部接口 -----------------------------

-- 根据服务器id获取相关配置（运营控制！！！）
function GetServerConfig(server_id)
	local db = Getdb(DATABASE_NAME.COMMON_DB)
	if not db then
		error("database_common GetServerConfig db error")
	end

	server_id = server_id or defaultServerId
	local isOk, res = select(db, DATABASE_COMMON_DB_TABLES.SERVER_CONFIG, nil, "server_id", server_id)
	if isOk and res and res[1] then
		if res[1].gateway_posts then
			res[1].gateway_posts = cjson.decode(res[1].gateway_posts)
		end
		return res[1]
	end
end
