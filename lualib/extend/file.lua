local assert = assert
local table = table
local string = string
local file = file

if not file then
	error("_G not find file lib !!!")
end

-- 获取一个文件的详细信息
-- file.detailed(filepath)

function file.is_dir (filepath)
	if not filepath then return end
	local fdt = file.detailed(filepath)
	return fdt and fdt.type == "dir"
end

function file.is_file (filepath)
	if not filepath then return end
	local fdt = file.detailed(filepath)
	return fdt and fdt.type == "file"
end

-- 创建一个文件夹
function file.createFolder(path)
	os.execute("mkdir ".. path)
end

-- 创建一个文件
function file.createFile(path)
	os.execute("touch ".. path)
end

-- 连续创建文件夹，一次性创建你想要的文件夹
function file.createManyFolder(path)
	local path_tb={}
	local new_path=""

	-- 分割路径保存到table
	for s in string.gmatch(path,"([^'/']+)") do
		if s~=nil then
			table.insert(path_tb,s)
		end
	end

	-- 遍历并拼接路径检测是否存在，不存在则新建
	for k, v in ipairs(path_tb) do
		if k == 1 then
			new_path = v
		else
			new_path = new_path .. "/" .. v
		end

		if not os.execute("cd ".. new_path) then
			if os.execute("mkdir ".. new_path) then
				_INFO_F("%s create succeeds!", new_path)
			else
				_ERROR_F("%s create error!", new_path)
			end
		end
	end
end

-- 删除文件夹下所有文件，连带删除文件夹
-- 参数：folderPath——>需要删除的文件夹路径
function file.deleteAllFolder(folderPath)
	if folderPath == "/" or folderPath == "/*" then
		error("file deleteAllFolder not delete root path!!!")
	end
	os.execute("rm -rf ".. folderPath)
end

-- 返回当前路径
-- file.crtpath()

-- 获取文件夹下的一级文件及文件夹
-- 参数: path——>遍历文件的路径
function file.getFileList(path)
	local iterator = io.popen("ls " .. path .. "/")
	if not iterator then return end

	local fileTable = {}
	for l in iterator:lines() do
		table.insert(fileTable, l)
	end

	return fileTable
end

function file.getAllFileInFolder(folderPath, backupPath)
	local f = assert(io.open(backupPath .. "/file.txt", 'a'))

	local newPath = ""
	local fileList = file.getFileLis(folderPath)
	for i= 1, #fileList do
		if string.find(fileList[i], "%.") == nil then
			newPath = folderPath .. "/" .. fileList[i]
			file.getAllFileInFolder(newPath, backupPath)
		else
			f:write(folderPath .. "/" .. fileList[i] .. "\n")
		end
	end
	f:close()
end