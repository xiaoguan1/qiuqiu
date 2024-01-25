local table = table
local type = type

-- 统计table的元素数量
function table.size(t)
	assert(type(t) == "table")

	local count = 0
	for _, _ in pairs(t) do count = count + 1 end
	return count
end

function table.empty(t)
	if type(t) ~= "table" then return end

	for _, _ in pairs(t) do
		return false
	end

	return true
end

function table.is_has_value(tbl, value)
	if type(tbl) ~= "table" then return end
	for _, _value in pairs(tbl) do
		if value == _value then return true end
	end
	return false
end

function table.copy(tbl)
	if not tbl then
		return nil
	end
	local ret = {}
	for k, v in pairs(tbl) do
		ret[k] = v
	end
	return ret
end