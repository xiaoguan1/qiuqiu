----------------------------
-- 创建者：Ghost
-- 模块作用：sys拓展函数
----------------------------

local pcall = pcall
local pairs = pairs
local ipairs = ipairs
local type = type
local string = string
local tostring = tostring
if not sys then
	sys = {}
	_G.sys = sys
end
sys.path = sys.path or {}

local function _normalize(value)
	local retval = ''
	if type(value) == 'function' then
		retval = '<' .. tostring(value) .. '>'
	elseif type(value) == 'table' then
		retval = '<' .. tostring(value) .. '>'
	elseif type(value) == 'string' then
		retval = string.format('%q', value)
	else
		retval = tostring(value)
	end
	return retval
end


function sys.repr (value)
	local retval = ''
	if type(value) == 'table' then
		local visited = {}
		retval = retval .. '{'
		for i, v in ipairs(value) do
			retval = retval .. _normalize(v) .. ','
			visited[i] = 1
		end
		for k, v in pairs(value) do
			if not visited[k] then
				retval = retval .. '[' .. _normalize(k) .. '] = ' .. _normalize(v) .. ', '
			end
		end
		retval = retval .. '}'
		return retval
	else
		retval = _normalize(value)
	end
	return retval
end

function sys.FindErrorType(value, dummy)
	if not value then
		return
	end
	local Types = {number = 1, string = 1, table = 1, boolean = 1,}
	--print (value, dummy)
	if not Types[type(value)] then
		print(value, dummy)
		error()
	else
		if type(value) == "table" then
			print("table", sys.repr(value), dummy)
			for k, v in pairs(value) do
				sys.FindErrorType(k, v)
				sys.FindErrorType(v, k)
			end
		end
	end
end

local function dodump(value, c)
	local retval = ''
	if type(value) == 'table' then
		c = (c or 0) + 1
		if c >= 100 then
			error("sys,dump to deep:" .. retval)
		end

		retval = retval .. '{'
		for k, v in pairs(value) do
			retval = retval .. '[' .. dodump(k, c) .. '] = ' .. dodump(v, c) .. ', '
		end
		retval = retval .. '}'
		return retval
	else
		retval = _normalize(value)
	end
	return retval
end

-- 为了防止死循环，不让它遍历超过100个结点。谨慎使用。
function sys.dump(value)
	local ni, ret = pcall(dodump, value)
	return ret
end

local function _Foreach(t, f)
	for k, v in pairs(t) do
		if f(k, v) then
			break
		end			-- 拓展可中断
	end
end

local function _WordsIndentBy(xn)
	local result = ""
	for i = 1, xn do
		result = result .. "  "
	end
	return result
end

local function _ToTreeString(t, deep)
	if type(t) ~= "table" then
		return tostring(t)
	else
		local indent = _WordsIndentBy(deep)
		local result = indent .. "{\n"

		_Foreach(t, function(k, v)
			result = result .. _WordsIndentBy(deep + 1)
			if type(k) == "string" then
				result = result .. "[" .. string.format('%q', k) .. "]="
			else
				result = result .. "[" .. tostring(k) .. "]="
			end
			if type(v) == "table" then
				local subT = _ToTreeString(v, deep + 2)
				result = result .. "\n" .. subT .. "," .. "\n" 
			else
				if type(v) == "string" then
					result = result .. string.format('%q', v) .. "," .. "\n"
				else
					result = result .. tostring(v) .. "," .. "\n"
				end
			end
		end)
		return result .. indent .. "}"
	end
end

function sys.dumptree(t)
	return _ToTreeString(t, 0)
end
