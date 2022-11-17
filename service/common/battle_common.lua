local M = {}

M.foodlist_msg =  function()
	local msg = {"foodlist"}
	for k, v in pairs(balls) do
		table.insert(msg, v.id)
		table.insert(msg, v.x)
		table.insert(msg, v.y)
	end
	return msg
end

M.balllist_msg = function()
	local msg = {"balllist"}
	for k, v in pairs(balls) do
		table.insert(msg, v.playerid)
		table.insert(msg, v.x)
		table.insert(msg, v.y)
		table.insert(msg, v.size)
	end
	return msg
end

return M