-- 目前还有一些问题，编译协议时是无序如果后面有编译顺序的需求需要加代码!!!

-------- 必须具备这些自定义脚本文件 --------
dofile "../lualib/extend/table.lua"
dofile "../lualib/extend/string.lua"
dofile "../lualib/extend/file.lua"
-------- 必须具备这些自定义脚本文件 --------

-- 计算绝对路径
local nowPath = file.crtpath()
local protoPath = nowPath .. "/../protobuf/network/proto/"
local pbPath = nowPath .. "/../protobuf/network/pb/"

local protofiles = file.getFileList(protoPath)
if not protofiles or type(protofiles) ~= "table" or table.empty(protofiles) then
	error("not find protofiles")
end

-- 编译网络协议文件
for _, filename in pairs(protofiles) do
	local fname = string.split(filename, "%.", 1)
	if not fname then break end

	local fileProtoPath = protoPath .. filename
	local newfilePbPath = pbPath .. fname .. ".pb"

	local isOk = os.execute("protoc --proto_path=" .. protoPath .. " -o " .. newfilePbPath .. " " .. fileProtoPath)	
	if not isOk then
		error(string.format("protobuf compile error, file:[%s]", filename))
	end
end
