local stat = stat

if not stat then
	error("_G not find stat lib !!!")
end

function stat.is_dir (filepath)
	if not filepath then return end
	return stat.filetype(filepath) == "dir"
end

function stat.is_file (filepath)
	if not filepath then return end
	return stat.filetype(filepath) == "file"
end
