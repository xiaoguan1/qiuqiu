local file = file

if not file then
	error("_G not find file lib !!!")
end

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
