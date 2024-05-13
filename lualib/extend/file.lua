local file = file

if not file then
	error("_G not find file lib !!!")
end

function file.is_dir (filepath)
	if not filepath then return end
	return file.type(filepath) == "dir"
end

function file.is_file (filepath)
	if not filepath then return end
	return file.type(filepath) == "file"
end

-- 创建一个文件夹
