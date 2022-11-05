local skynet = require "skynet"
local mysql = require "skynet.db.mysql"
local log = require "common_log"

local M = {}

M.Getdb = function()
	local function on_connect(db)
		db:query("set charset utf8")
	end
	local db = mysql.connect({
		host = "127.0.0.1",
		port = 3306,
		database = "message_board",
		user = "root",
		password = "root",
		max_pack_size = 1024 * 1024,
		on_connect = on_connect,
	})

	if not db then
		skynet.error("数据库连接失败！！！")
		return
	end
	return db
end

M.check_account = function(account, passwd, db)
	db = db or Getdb()
	if not (account and passwd and db) then return end

	local sql = string.format("select * from roles where account = %s", account)
	local res = db:query(sql)

	if not res["badresult"] and #res == 1 then
		local result = res[1]
		return result.passwd == passwd
	end
	skynet.error("查找失败！！！")
end

M.isHas = function(account, passwd, db)
	db = db or Getdb()
	if not (account and passwd and db) then return end

	local sql = string.format("select * from roles where account = %s", account)
	local res = db:query(sql)

	if not res["badresult"] and #res == 1 then
		return true
	end
end

M.insert = function(account, passwd, db)
	db = db or Getdb()
	if not (account and passwd and db) then return end

	local sql = string.format("insert into roles(account, passwd) values (%s, %s)", account, passwd)
	local res = db:query(sql)
	log.PRINT("insert insert ", res)
	if not res["badresult"] and res.affected_rows == 1 then
		return true
	end
end

return M