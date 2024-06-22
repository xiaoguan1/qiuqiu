mysql = require "skynet.db.mysql"
local string = string
local table = table



-- 防止sql注入问题
function quote_sql_str(str)
	str = string.gsub(str, "'", "\\'")
	if not str then
		return
	end

	str = string.gsub(str, '"', '\\"')
	if not str then
		return
	end

	return table.concat({"'", str, "'"})
end
