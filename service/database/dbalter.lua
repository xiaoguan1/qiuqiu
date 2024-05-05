----------------------------------------
-- 创建者：Ghost
-- 创建日期: 2020/11/28
-- 模块作用: 数据库起服或更新修改
-- 注意: 数据块的热更过程中如果写日志，SyncData，Scm数据表都没更好那可能存在一点点问题。但是这些都是查看级别的
----------------------------------------

local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
require "skynet.manager"
local mysql = require "skynet.db.mysql"
local table = table
local is_testserver = (skynet.getenv("is_testserver") == "true") and true or false

-- 加载活动存盘列表，可能要加mysql活动列表
local ACTIVITY_DB_VARS_MOD = Import("charvar/activity/db.lua")
local GAMESERVER_DB_VARS_MOD = Import("charvar/activity/db.lua")
local SCM_DB_SCM_MOD = Import("charvar/agent/scm_rolevar.lua")

local LOG_CREATE_PARTITION_YEAR = 3             -- 拆分年限
local LOG_MIN_PARTITION_YEAR = 1                -- 启动游戏服日志库中存在拆分最先年限
assert(LOG_CREATE_PARTITION_YEAR >= LOG_MIN_PARTITION_YEAR) -- 生成3年的数据启动的时候判断不够1年的则创建（防止开服1年了不关）

local LOG_PARTITION_DATA = {}
local NOW_TIME = os.time()
local DATE_DATA = os.date("*t", NOW_TIME)
for i = 1, 12 * LOG_CREATE_PARTITION_YEAR do
	local ti = os.time({year = DATE_DATA.year, month = DATE_DATA.month + i - 1, day = 1})
	local name = "p" .. os.date("%Y%m", ti)
	local desc = os.date("%Y-%m-%d", ti)
	LOG_PARTITION_DATA[name] = desc
end
local PARTITION_SQL_TBL = {}
for _name, _desc in pairs(LOG_PARTITION_DATA) do
	table.insert(PARTITION_SQL_TBL, string.format("PARTITION %s VALUES LESS THAN('%s')", _name, _desc))
end
table.sort(PARTITION_SQL_TBL)
local PARTITION_SQL = table.concat(PARTITION_SQL_TBL, ",\n")

local CREATE_ROLEDATA_SQL = [[
CREATE TABLE role_data (
	uid varchar(32) not null COMMENT "玩家唯一id",
	name varchar(64) not null COMMENT "玩家名字",
	mapdata varchar(128) not null COMMENT "地图数据",
	data mediumtext not null COMMENT "玩家数据",
	gameserver mediumtext COMMENT "游戏服数据",
	maze mediumtext COMMENT "迷宫数据",
	arena mediumtext COMMENT "竞技场数据",
	chat mediumtext COMMENT "聊天数据",
	champion mediumtext COMMENT "争霸赛数据",
	Account varchar(64) COMMENT "玩家账号",
	primary key (uid),
	unique key uk_role_name (name)
) ENGINE = InnoDB DEFAULT CHARSET = utf8;
]]

local SYNC_ROLEDATA_SQL = "insert into role_data (uid, name, mapdata, data, maze, arena, chat, champion, gameserver, Account) select uid, name, mapdata, data, maze, arena, chat, champion, gameserver, Account from role;"
local DROP_NAME_UNIQUEKEY_SQL = "drop index uk_role_name on role;"
local REMOVE_NAME_NOTNULL = "alter table role modify column name varchar(64) default null"
local DROP_USELESS_SQL = [[
alter table role
	drop column mapdata,
	drop column data,
	drop column maze,
	drop column arena,
	drop column chat,
	drop column champion,
	drop column gameserver;
]]

function CreateRoleColumns()
	local DATABASE_CFG = assert(load("return " .. skynet.getenv("database_info"))())
	local function on_connect(db)
		db:query("set charset utf8")
	end
	local dbObj = mysql.connect({
		host = DATABASE_CFG.dbhost,
		port = DATABASE_CFG.dbport,
		database = DATABASE_CFG.dbname,
		user = DATABASE_CFG.dbuser,
		password = DATABASE_CFG.dbpasswd,
		max_packet_size = 1024 * 1024 * 2^9 - 1,
		on_connect = on_connect,
	})
	-- 询问query的时候如果断开还是会继续连接，直到连接上
	if not dbObj then
		error("connect mysql error!")
	end

	local sql = "desc role_data;"
	local columnsInfo = dbObj:query(sql)
	if columnsInfo["badresult"] then
		if is_testserver then
			-- 帮忙创建一个表
			local ret = dbObj:query(CREATE_ROLEDATA_SQL)
			assert(not ret["badresult"])
			local cntRet = dbObj:query("select count(*) as cnt from role;")
			if not cntRet["badresult"] and cntRet[1] and cntRet[1].cnt > 0 then	-- 如果role有数据则迁移
				ret = dbObj:query(SYNC_ROLEDATA_SQL)
				assert(not ret["badresult"], sys.dump(ret))
				ret = dbObj:query(DROP_NAME_UNIQUEKEY_SQL)
				assert(not ret["badresult"])
				ret = dbObj:query(REMOVE_NAME_NOTNULL)
				assert(not ret["badresult"])
				ret = dbObj:query(DROP_USELESS_SQL)
				assert(not ret["badresult"])
			end

			columnsInfo = dbObj:query(sql)
			assert(not columnsInfo["badresult"])
		else
			error("query db error:" .. sys.dump(columnsInfo))
		end
	end

	for _serviceName, _ in pairs(NODE_SERVER_INFO) do
		local _, _, _columnsName = string.find(_serviceName, "^actsvc/(.*)")
		if _columnsName then
			local DB_ROLEVARS = ACTIVITY_DB_VARS_MOD.GetRoleVars_ByServiceName(_serviceName)
			if DB_ROLEVARS then
				local hasColumns = false
				for _, _cdata in pairs(columnsInfo) do
					if _cdata.Field == _columnsName then
						hasColumns = true
						break
					end
				end
				if not hasColumns then
					local sql = string.format("alter table role_data add %s mediumtext;", _columnsName)
					-- _RUN
					local res = dbObj:query(sql)
					assert(not res["badresult"])
					skynet.error("add role_data columns: " .. _columnsName)
				end
			end
		end
	end

	local HAS_DBVAR = #GAMESERVER_DB_VARS_MOD.GetSaveVars("role") > 0
	if HAS_DBVAR then
		local hasColumns = false
		for _, _cdata in pairs(columnsInfo) do
			if _cdata.Field == "gameserver" then
				hasColumns = true
				break
			end
		end
		if not hasColumns then
			local sql = string.format("alter table role_data add gameserver mediumtext;")

			local res = dbObj:query(sql)
			assert(not res["badresult"])
			skynet.error("add role_data columns: gameserver")
		end
	end

	local sql = "desc role;"
	local columnsInfo = dbObj:query(sql)
	if columnsInfo["badresult"] then
		error("query db error: " .. sys.dump(columnsInfo))
	end

	local SCM_ROLEVAR = SCM_DB_SCM_MOD.GetScmRoleVar()
	if SCM_ROLEVAR then
		-- 存在该table，对比已经有的columns，插入没有的columns
		for _columnsName, _filedType in pairs(SCM_ROLEVAR) do
			local hasColumns = false
			local hasModify = false
			for _, _cdata in pairs(columnsInfo) do
				if _columnsName == _cdata.Field then
					if _filedType ~= _cdata.Type then
						hasModify = true
					else
						hasColumns = true
					end
				end
				break
			end
			if hasModify then
				local sql = string.format("alter table %s modify column %s %s;", "role", _columnsName, _filedType)
				local res = dbObj:query(sql)
				assert(not res["badresult"])
				skynet.error(sql)
			elseif not hasColumns then
				local sql = string.format("alter table %s add `%s` %s;", "role", _columnsName, _filedType)
				local res = dbObj:query(sql)
				assert(not res["badresult"])
				skynet.error(sql)
			end
		end
	end

	mysql.disconnect(dbObj)
end

local CREATE_TABLE_SQL_PARTITION_FMT = [[
CREATE TABLE `%s` (
	`timestamp` datetime not null default current_timestamp,
	%s
) ENGINE = InnoDB DEFAULT CHARSET = utf8
partition by range columns(timestamp) (
	%s
);
]]
local CREATE_TABLE_SQL_FMT = [[
CREATE TABLE `%s` (
	`timestamp` datetime not null default current_timestamp,
	%s
) ENGINE = InnoDB DEFAULT CHARSET = utf8;
]]
local INDEXS_SQL_FMT = "alter table %s add index %s(`%s`);"
local log_xls = sharedata.query("LogData")
local log_indexs_xls = sharedata.query("LogIndexsData")
local log_partition_xls = sharedata.query("LogPartitionData")
function CreateGameLogTable()
	local LOGDB = skynet.getenv("logdb") == "true" and true or false
	if not LOGDB then return end

	local LOGDB_CFG = assert(load("return " .. skynet.getenv("logdb_info"))())
	local function on_connect(db)
		db:query("set charset utf8")
	end
	local dbObj = mysql.connect({
		host = LOGDB_CFG.dbhost,
		port = LOGDB_CFG.dbport,
		database = LOGDB_CFG.dbname,
		user = LOGDB_CFG.dbuser,
		password = LOGDB_CFG.dbpasswd,
		max_packet_size = 1024 * 1024 * 2^9 - 1,
		on_connect = on_connect,
	})
	if not dbObj then
		error("connect mysql error!")
	end

	-- 如果没有log table则加入，如果有则查看desc对应一下columns
	--		不存在则加，如果类型不一样咋办（直接报错，因为只能改表把名字改成不一样，或者手动改字段类型）
	assert(log_xls)
	for _tableName, _data in pairs(log_xls) do
		local columnsInfo = dbObj:query(string.format("desc %s;", _tableName))
		if columnsInfo["badresult"] then
			local columnsTbl = {}
			for _columnsName, field in pairs(_data) do
				local _filedType = field.FieldType
				local _filedDesc = field.FieldDes
				table.insert(columnsTbl, string.format("`%s` %s comment `%s`", _columnsName, _filedType, _filedDesc))
			end
			local sql = nil
			if log_partition_xls[_tableName] then
				sql = string.format(CREATE_TABLE_SQL_PARTITION_FMT, _tableName, table.concat(columnsTbl, ",\n\t"), PARTITION_SQL)
			else
				sql = string.format(CREATE_TABLE_SQL_FMT, _tableName, table.concat(columnsTbl, ",\n\t"))
			end

			-- 不存在该table，创建table
			local res = dbObj:query(sql)
			assert(not res["badresult"])
			skynet.error("create gamelog table:" .. _tableName)
		else
			local ldata = {
				["timestamp"] = {
					fieldType = "datetime",
					FieldDes = "timestamp",
				}
			}
			for _columnsName, _field in pairs(_data) do
				ldata[_columnsName] = _field
			end
			-- 存在该table，对比已经有的columns，插入没有的columns
			for _columnsName, _field in pairs(ldata) do
				local _fieldType = _field.fieldType
				local _fieldDesc = _field.FieldDes
				local hasColumns = false
				for _, _cdata in pairs(columnsInfo) do
					if _columnsName == _cdata.Field then
						if _fieldType ~= _cdata.Type then
							if LOG_MODIFY_COLUMN[_tableName] and LOG_MODIFY_COLUMN[_tableName][_cdata.Field] == _cdata.Type then
								local sql = string.format("alter table %s modify column %s %s comment '%s';",
									_tableName, _columnsName, _fieldType, _fieldDesc
								)
								local res = dbObj:query(sql)
								assert(not res["badresult"])
								skynet.error(sql)
							elseif LOG_MODIFY_COLUMN["*"] and LOG_MODIFY_COLUMN["*"][_cdata.Field] == _cdata.Type then
								local sql = string.format("alter table %s modify column %s %s comment '%s';",
								_tableName, _columnsName, _fieldType, _fieldDesc
								)
								local res = dbObj:query(sql)
								assert(not res["badresult"])
								skynet.error(sql)
							else
								error(string.format("mysql table:%s field:%s type:%s xls type:%s",
									_tableName, _cdata.Field, _cdata.Type, _fieldType
								))
							end
						end
						hasColumns = true
						break
					end
				end
				if not hasColumns then
					local sql = string.format("alter table %s add '%s' %s comment '%s';",
						_tableName, _columnsName, _fieldType, _fieldDesc
					)
					local res = dbObj:query(sql)
					assert(not res["badresult"])
					skynet.error(sql)
				end
			end
		end
		if log_indexs_xls[_tableName] then
			local indexsInfo = dbObj:query(string.format("show index from %s;", _tableName))
			assert(not indexsInfo["badresult"])
			local indexsData = {}
			for _, _data in ipairs(indexsInfo) do
				indexsData[_data.Key_name] = indexsData[_data.Key_name] or {}
				indexsData[_data.Key_name][_data.Seq_in_index] = _data.Column_name
			end
			local isIndexsChange = false
			for _, _keyData in pairs(log_indexs_xls[_tableName]) do
				local hasEqual = false
				for _, _cKeyData in pairs(indexsData) do
					if table.equal(_keyData, _cKeyData) then
						hasEqual = true
					end
					if hasEqual then
						break
					end
				end
				if not hasEqual then
					isIndexsChange = true
					break
				end
			end
			if isIndexsChange then
				-- 先删除旧的indexs
				for _indexName, _ in pairs(indexsData) do
					local sql = string.format("drop index %s on %s;", _indexName, _tableName)
					local res = dbObj:query(sql)
					if res["badresult"] then
						local msg = string.format("drop index:%s on %s error:%s", _indexName, _tableName, sys.dump(res))
						error(msg)
					else
						skynet.error(sql)
					end
				end
				for _, _keyData in pairs(log_indexs_xls[_tableName]) do
					local iName = table.concat(_keyData, "_")
					local sql = string.format(INDEXS_SQL_FMT, _tableName, iName, table.concat(_keyData, "`, `"))
					local res = dbObj:query(sql)
					if res["badresult"] then
						local msg = string.format("%s error:%s", sql, sys.dump(res))
						error(msg)
					else
						skynet.error(sql)
					end
				end
			end
		end

		-- 如果原本没有的，后面有
		local columnsInfo = dbObj:query(string.format("select partition_name, partition_description form INFORMATION_SCHEMA.PARTITIONS where TABLE_SCHEMA='%s' and TABLE_NAME='%s'", LOGDB_CFG.dbname, _tableName))
		if columnsInfo["badresult"] then
			local msg = string.format("select partition %s %s error:%s", LOGDB_CFG.dbname, _tableName, sys.dump(columnsInfo))
			error(msg)
		else
			if log_partition_xls[_tableName] then
				local checkColumns = {}
				local partCnt = 0
				for _, _data in pairs(columnsInfo) do
					if _data.partition_name then
						checkColumns[_data.partition_name] = _data.partition_description
						if LOG_PARTITION_DATA[_data.partition_name] then
							partCnt = partCnt + 1
						end
					end
				end
				if partCnt <= LOG_MIN_PARTITION_YEAR * 12 then	-- 不够1年的分区量
					local partTbl = {}
					for _name, _desc in pairs(checkColumns) do
						table.insert(partTbl, string.format("PARTITION %s VALUES LESS THAN('%s')", _name, _desc))
					end
					for _name, _desc in pairs(LOG_PARTITION_DATA) do
						if not checkColumns[_name] then
							table.insert(partTbl, string.format("PARTITION %s VALUES LESS THAN('%s')", _name, _desc))
						end
					end
					if #partTbl > 1 then
						table.sort(partTbl)
						local sql = string.format("alter table %s partition by range columns(timestamp) (", _tableName) .. table.concat(partTbl, ",") .. ");"
						local res = dbObj:query(sql)
						if res["badresult"] then
							local msg = string.format("%s error:%s", sql, sys.dump(res))
							error(msg)
						else
							skynet.error(sql)
						end
					end
				end
			end
		end
	end

	mysql.disconnect(dbObj)
end

local CREATE_SYNC_TABLE_FMT = [[
CREATE TABLE `%s` (
	%s
) ENGINE = InnoDB DEFAULT CHARSET = utf8;
]]

local PRIMARY_KEYS_FMT = "alter table %s add primary key(`%s`);"
local sync_xls = sharedata.query("SyncData")
-- 创建SyncData表
function CreateSyncDataTable()
	local DATABASE_CFG = assert(load("return " .. skynet.getenv("database_info"))())
	local function on_connect(db)
		db:query("set charset utf8")
	end
	local dbObj = mysql.connect({
		host = DATABASE_CFG.dbhost,
		port = DATABASE_CFG.dbport,
		database = DATABASE_CFG.dbname,
		user = DATABASE_CFG.dbuser,
		password = DATABASE_CFG.dbpasswd,
		max_packet_size = 1024 * 1024 * 2^9 - 1,		-- longtext
		on_connect = on_connect,
	})
	-- 询问query的时候如果是断开还是会继续连接，直到连接上
	if not dbObj then
		error("connect mysql error!")
	end
	for tName, tData in pairs(sync_xls) do
		local desc = dbObj:query(string.format("desc %s;"), tName)
		-- 建表
		if desc.badresult then
			local columns = {}
			for cName, cData in pairs(tData.Field) do
				table.insert(columns, string.format("`%s` %s comment '%s'",
					cName, cData.FieldType, cData.FieldDes))
			end
			assert(#columns > 0)
			local sql = string.format(CREATE_SYNC_TABLE_FMT, tName, table.concat(columns, ",\n\t"))
			local ret = dbObj:query(sql)
			assert(not ret.badresult)
			skynet.error("create server table:" .. tName)
			-- 加主键
			sql = string.format(PRIMARY_KEYS_FMT, tName, table.concat(tData.Primary, "`,`"))
			ret = dbObj:query(sql)
			assert(not ret.badresult)
			skynet.error("add table primary" .. sql)
		else
			for cName, cData in pairs(tData.Field) do
				local fType, fDesc = cData.FieldType, cData.FieldDes
				local hasCol
				for _, colInfo in pairs(desc) do
					if cName == colInfo.Field then
						-- 字段类型不一致
						if fType ~= colInfo.Type then
							if LOG_MODIFY_COLUMN[tName] and LOG_MODIFY_COLUMN[tName][colInfo.Field] == colInfo.Type then
								local sql = string.format("alter table %s modify column %s %s comment '%s';",
									tName, cName, fType, fDesc
								)
								local ret = dbObj:query(sql)
								assert(not ret.badresult)
								skynet.error(sql)
							else
								error(string.format("mysql table:%s field:%s type:%s, xls type:%s",
									tName, colInfo.Field, colInfo.Type, fType
								))
							end
						end
						hasCol = true
						break
					end
				end
				if not hasCol then
					local sql = string.format("alter table %s add `%s` %s comment '%s';",
						tName, cName, fType, fDesc
					)
					local ret = dbObj:query(sql)
					assert(not ret.badresult)
					skynet.error(sql)
				end
			end
		end
		-- 建额外索引
		local index = tData.Index
		if index then
			local info = dbObj.query(string.format("show index from %s;", tName))
			assert(not info.badresult)
			local orgData = {}
			for _, data in pairs(info) do
				-- 排除主键索引
				if data.Key_name ~= "PRIMARY" then
					orgData[data.Key_name] = orgData[data.Key_name] or {}
					orgData[data.Key_name][data.Seq_in_index] = data.Column_name
				end
			end
			local isIndexsChange = false
			for _, _keyData in pairs(index) do
				local hasEqual = false
				for _, _cKeyData in pairs(orgData) do
					if table.equal(_keyData, _cKeyData) then
						hasEqual = true
					end
					if hasEqual then
						break
					end
				end
				if not hasEqual then
					isIndexsChange = true
					break
				end
			end
			-- 索引变化
			if isIndexsChange then
				-- 先删除旧的indexs
				for name, _ in pairs(orgData) do
					local sql = string.format("drop index %s on %s;", name, tName)
					local ret = dbObj:query(sql)
					if ret.badresult then
						error(string.format("drop index:%s on %s error:[%s]%s",
							name, tName, ret.errno, ret.err))
					else
						skynet.error(sql)
					end
				end
				for _, _keyData in pairs(index) do
					local iName = table.concat(_keyData, "_")
					local sql = string.format(INDEXS_SQL_FMT, tName, iName, table.concat(_keyData, "`, `"))
					local ret = dbObj:query(sql)
					if ret.badresult then
						local msg = string.format("%s error:%s", sql, ret.errno, ret.err)
						error(msg)
					else
						skynet.error(sql)
					end
				end
			end
		end
	end
	mysql.disconnect(dbObj)
end

