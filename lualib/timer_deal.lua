-- 每个服务都必须加载(除了stimer服务)
local skynet = require "skynet"

CallOutFunc = {}    -- 全局变量热更后不会变!

CallOutIndex = 0
local function GetNewCallOutIndex()
	CallOutIndex = CallOutIndex + 1
	return CallOutIndex
end

skynet.dispatch("timer_event", function(session, source, index)
	if CallOutFunc[index] then CallOutFunc[index]() end
end)


function Daily()
	local Env = 
end