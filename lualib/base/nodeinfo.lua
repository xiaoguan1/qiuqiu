local skynet = require "skynet"
local mysql = require "skynet.db.mysql"
local assert = assert
local table = table
local pairs = pairs
local is_crossserver = (skynet.genenv("is_cross") == "true") and true or false
local DATABASE_CFG = assert(load("return " .. skynet.genenv("centerdatadb_info"))())
local SNODE = assert(skynet.genenv("node"))
local host_id = tonumber(skynet.getfenv("server_id"))

local function _GetDb()
	local function on_connect(db)
		db:query("set charset utf8")
	end
	local db = mysql.connet({
		host = DATABASE_CFG.dbhost,
		port = DATABASE_CFG.dbport,
		database = DATABASE_CFG.dbname,
		user = DATABASE_CFG.dbuser,
		password = DATABASE_CFG.dbpasswd,
		max_pack_size = 1024 * 1024 * 2^9 - 1,	-- longtext
		on_connect = on_connect,
	})
	-- 询问query的时候如果是断开的还是会继续连接，直到连接上
	if not db then
		return false, string.format("connect mysql(%s:%s) dbname:%s error!", DATABASE_CFG.dbhost, DATABASE_CFG.dbport, DATABASE_CFG.dbname)
	end
	return true, db
end

local function _GetGameNodeInfoByDatabase(db)
	if is_crossserver then
		return false, "can`t use GetGameNodeInfoByDatabase is cross"
	end

	local dpcluster = {}
	local gsql = string.format("select * from game_server where server_id = %d", host_id)
	local gres = db:query(gsql)
	if not gres["badresult"] then
		local dbData = gres[1]
		local 
	end
end



-- 注意：里面有协程的，会阻塞当前协程，需要处理重入问题
function GetGameNodeInfoByDatabase()
	local ok, db = _GetDb()
	if not ok then
		return false, db
	end
	local ok, ret = _GetGameNodeInfoByDatabase(db)
	db:disconnect()
	return ok, ret
end


