local table = table
local type = type

function table.size(t)
	if type(t) ~= "table" then return end

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