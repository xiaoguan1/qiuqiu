local pb = require "protobuf"
local filelib = require "filelib"

function load()
	local nowPath = filelib.getNowPath()
	local networkPbPath = nowPath .. "/protobuf/network/pb/"
	local databasePbPath = nowPath .. "/protobuf/database/pb/"

	local networkPbFiles = filelib.getFileList(networkPbPath)
	local databasePbFiles = filelib.getFileList(databasePbPath)

	if not (networkPbFiles and networkPbFiles) then
		error(string.format("proto load fail."))
	end

	-- 加载网络协议文件
	for _, filename in pairs(networkPbFiles) do
		pb.register_file(networkPbPath .. filename)
	end

	-- 加载数据库序列化文件
	for _, filename in pairs(databasePbFiles) do
		pb.register_file(databasePbPath .. filename)
	end
end

load()