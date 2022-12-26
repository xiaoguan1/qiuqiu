--[[
	@引用:require("FileLib")
	@调用：fileLib.createFolder(path)
	@功能：
		1.创建文件夹
		2.连续创建文件夹
		3.删除文件夹所有内容
		4.删除空文件夹/文件
		5.获取某个文件夹下的所有文件
		6.获取文件夹下的一级文件及文件夹table
		7.判断文件是否存在
		8.判断文件夹是否存在
]]--

local fileLib = {}

--作用：创建文件夹
--参数: path——>创建文件夹的路径
--返回值：无
--设备：ios(已测)
--时间：2017.9.27
fileLib.createFolder=function(path)
	os.execute("mkdir "..path)
end;


--作用：连续创建文件夹，一次性创建你想要的文件夹
--参数: path——>创建文件夹的路径
--返回值：无
--设备：ios(已测)
--时间：2017.9.27
fileLib.createAllFolder=function(path)

	local path_tb={}
	local new_path=""
	
	-- 分割路径保存到table
	for s in string.gmatch(path,"([^'/']+)") do

		if s~=nil then

			table.insert(path_tb,s)
		end
	end
	
	-- 遍历并拼接路径检测是否存在，不存在则新建
	for k,v in ipairs(path_tb) do

		if k==1 then
			new_path=v
		else
			new_path=new_path.."/"..v
		end		

		if os.execute("cd "..new_path) then
			
			print(new_path.." exist")
		else

			print(new_path.." do not exist")
			
			os.execute("mkdir "..new_path)
		end
	end

	print("create suc")
end;


--作用：清楚文件夹下所有文件，连带删除文件夹
--参数: folderPath——>需要删除的文件夹路径
--返回值：无
--设备：ios(已测)
--时间：2017.9.27
fileLib.deleteAllFolder=function(folderPath)
	os.execute("rm -rf "..folderPath)		
end;


--作用：删除空文件夹/文件
--参数: folderPath——>需要删除的空文件夹/文件路径
--返回值：无
--设备：ios(已测)
--时间：2017.9.27
fileLib.deleteAllFolder=function(folderPath)
	os.remove(folderPath)	
end;


--作用：获取某个文件夹下所有的文件
--参数: folderPath——>需要删除的空文件夹/文件路径 backupPath->备份输出文件路径
--返回值：file_tb->所有文件的全路径名table
--设备：ios(已测)
--时间：2017.9.27
fileLib.getAllFileInFolder=function(folderPath, backupPath)
	local file_tb={}
	local fileList={}
	local newPath=""
	local f = io.open(backupPath .. "/file.txt", 'a')
	
	fileList = fileLib.getFileList(folderPath)
	for i= 1, #fileList do
		if string.find(fileList[i], "%.") == nil then
			newPath=folderPath .. "/" .. fileList[i]
			fileLib.getAllFileInFolder(newPath,backupPath)
		else
			f:write(folderPath.."/"..fileList[i].."\n")
		end	
	end
	f:close()
end;


--作用：获取文件夹下的一级文件及文件夹table
--参数: path——>遍历文件的路径
--返回值：fileTable->文件table
--时间：2017.8.31
fileLib.getFileList=function(path)
	local a = io.popen("ls "..path.."/");
	local fileTable = {};

	if a ~= nil then
		for l in a:lines() do
			table.insert(fileTable, l)
		end
	end

	return fileTable;
end;


--作用：判断文件是否存在
--参数: path——>文件夹路径
--返回值：true/false ——>是否存在
--时间：2017.9.27
fileLib.isFileExist=function(path)
	f=io.open(path,"w")
	return f~=nil and f:close();
end;


--作用：判断文件夹是否存在
--参数: folderPath——>文件夹路径
--返回值：true/false ——>是否存在
--时间：2017.9.27
fileLib.isFolderExist=function (folderPath)
	return os.execute("cd "..folderPath)
end

return fileLib