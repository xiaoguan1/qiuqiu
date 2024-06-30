local table = table
local type = type
local next = next
local _ERROR = _ERROR

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

function table.is_has_value(tbl, value, tkey)
	if type(tbl) ~= "table" then return end
	for _, _value in pairs(tbl) do
		if tkey and type(_value) == "table" then
			if _value[tkey] == value then
				return true
			end
		else
			if value == _value then
				return true
			end
		end
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

-- 第一层是只读，如果是嵌套了多层table，那么从第二层开始就不是只读了
function table.simple_readonly(const_table)
	function _readonly(const_table)
		local function _PairsFunc(t, key)
			local nk, nv = next(const_table, key)
			if nk then
				nv = t[nk]
			end
			return nk, nv
		end
		local mt = {
			__index = const_table,
			__newindex = function (t, k, v)
				error("can`t update " .. tostring(const_table) .. "[" .. tostring(k) .. "] = " .. tostring(v))
			end,
			__pairs = function (t)
				return _PairsFunc, t, nil
			end,
			-- 不用设置_ipairs, lua5.3会自动添加的
			__len = function (t)
				return #const_table
			end,
		}
		return mt
	end

	local t = {}
	setmetatable(t, _readonly(const_table))
	return t
end

function table.deepcopy(src)
	if type(src) ~= "table" then
		return
	end
	local cache = {}
	local isOk = true
	local function clone_table(t, level)
		if not level then
			level = 0
		end

		if level > 100 then
			return t
		end

		local k, v
		local rel = {}
		for k, v in pairs(t) do
			if type(v) == "table" then
				if cache[v] then
					rel[k] = cache[v]
				else
					rel[k] = clone_table(v, level + 1)
					cache[v] = rel[k]
				end
			elseif type(v) == "userdata" then
				error("can not deepcopy userdata")
			else
				rel[k] = v
			end
		end
		return rel
	end
	local dtbl = clone_table(src)
	if not isOk then
		local _print = _ERROR or print
		_print("has getmetatable can not deepcopy", debug.traceback())
	end
	return dtbl
end