-- 一些杂项
local table = table

-- table转换城字符串，效率不太高，一般用于调试
local function tableToString(tbl)
	local function parseTable(tbl)
		local isArray, isSimple = true, true
		local count = 0

		for key, value in pairs(tbl) do
			if type(key) ~= "number" or key ~= (count + 1) then
				isArray = false
			end

			if type(value) ~= "table" then
				isSimple = false
			end

			count = count + 1
		end

		return {
			count = count,
			isArray = isArray,
			isSimple = isSimple,
		}
	end

	local function indent(list, n)
		for i = 1, n do table.insert(list, "  ") end
	end

    local function impl(t, list, level)
		assert(level <= 20, "max print level")

		if type(t) == "table" then
			local info = parseTable(t)
			local simpleArray = info.isArray and info.isSimple
			local singleLine = info.isSimple and info.count <= 20

			table.insert(list, "{")

			if not singleLine then table.insert(list, "\n") end

			local xpairs = info.isArray and ipairs or pairs

			local index = 1
			for key, v in xpairs(t) do
				if not singleLine then
					indent(list, level + 1)
				end

				if type(key) == "string" then
					table.insert(list, key)
				else
					if not simpleArray then
						table.insert(list, "[")
						table.insert(list, key)
						table.insert(list, "]")
					end
				end

				if not simpleArray then
					table.insert(list, " = ")
				end

				impl(v, list, level + 1)

				if index ~= info.count then
					table.insert(list, ', ')
				end

				if not singleLine then
					table.insert(list, "\n")
				end

				index = index + 1
			end

			if not singleLine then indent(list, level) end

			if level == 0 then
				table.insert(list, "}\n")
			else
				table.insert(list, "}")
			end
		elseif type(t) == "string" then
			table.insert(list, '"')
			table.insert(list, t)
			table.insert(list, '"')
		else
			table.insert(list, tostring(t))
		end
	end

	local list = {}
	impl(tbl, list, 0)
	return table.concat(list)
end


-- 打印所有
PRINT = function(...)
	local str = ""
	local msg = { ... }

	if not msg then return end

	for _, v in pairs(msg) do
        if (type(v) == "table") then
            if table.size(v) > 0 then
                str = str .. tableToString(v)
			else
				str = str .. "{\n}"
            end
		else
			str = str .. tostring(v)
        end
    end
	print(str)
end



