-------- 必须具备这些脚本文件 --------
dofile "../lualib/table.lua"
dofile "../lualib/string.lua"
local filelib = dofile "../lualib/filelib.lua"
-------- 必须具备这些脚本文件 --------

-- 计算绝对路径
local nowPath = filelib.getNowPath()
local protoPath = nowPath .. "/../protobuf/proto/"
local pbPath = nowPath .. "/../protobuf/pb/"

local protofiles = filelib.getFileList(protoPath)
if not protofiles or type(protofiles) ~= "table" or table.empty(protofiles) then
	error("not find protofiles")
	return
end

for _, filename in pairs(protofiles) do
	local fname = string.split(filename, "%.", 1)
	if not fname then break end

	local newfileProtoPath = protoPath .. filename
	local newfilePbPath = pbPath .. fname .. ".pb"
	os.execute("protoc --proto_path=" .. protoPath .. " -o " .. newfilePbPath .. " " .. newfileProtoPath)
end