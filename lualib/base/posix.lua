----------------------------------------
-- 创建者：Ghost
-- 创建日期：2022/06/23
-- 模块作用：posix拓展库
----------------------------------------

local string = string

posix = posix and posix or (require ("posix") or {})

function posix.stat_x(path)
	local stat = posix.stat(path)
	if stat then
		local mode = stat.mode
		if mode then
			if string.byte(mode, 3) ~= 120 then	-- "rwxrwxr-x" x=120 
				-- chmod 改变一下
				posix.chmod(path, "rwxrwxr-x")	-- 修改权限
				return posix.stat(path)
			end
		end
    end
	return stat
end

function posix.mkdir_p(path)			-- ../data/path 的话 path是不会创建的，需要 ../data/path
	local start = 1
	while true do
		local tmpStart, tmpEnd = string.find(path, "%/", start)
		if tmpStart and tmpEnd then
			local tpath = string.sub(path, 1, tmpEnd)
			if not posix.stat_x(tpath) then
				posix.mkdir_p(tpath)
				posix.stat_x(tpath)		-- 再次执行，以防止创建出来的没有x权限
			end
			start = tmpEnd + 1
		else
			break
		end
	end
end