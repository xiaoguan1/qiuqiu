local skynet = require "skynet"
local mysql = require "skynet.db.mysql"
local table = table

local M = {}

------------------------------------------------ 连接数据库 ------------------------------------------------
function M.Getdb(databaseName)
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
	return db
end

------------------------------------------------ 数据库的公共操作接口 ------------------------------------------------
-- 查询数据
function M.select(db, tableName, column, key, value)
	local sql = string.format("select %s from %s where %s=%s", column or "*", tableName, key, value)
	local res = db:query(sql)

	if not res["badresult"] and #res == 1 then
		--以roles表为例 正确结果的返回：res = {{ passwd = "123", playerId = "1001" }}
		return true, res
	end
end

-- 插入新数据
function M.insert(db, tableName, column, values)
	if not (db and tableName and column and values) then return end

	local sql = string.format("insert into %s(%s) values (%s)", tableName, column, values)
	local res = db:query(sql)

	if not res["badresult"] and res.affected_rows == 1 then
		--以roles表为例 正确结果的返回：res = { warning_count = 0, insert_id = 0, server_status = 2, affected_rows = 1 }
		return true, res
	end
end

return M