-----------------------------------------------
-- 创建时间：2024/05/25
-- 创建人：guanguowei
-- 模块作用：其他启动skynet引擎的公用模块
-----------------------------------------------

local skynet = require "skynet"
require "skynet.manager"
local NODE_ONLYSERVER = NODE_ONLYSERVER

function EveryNodeServer()
	for _, uniservice in ipairs(NODE_ONLYSERVER) do
		local sid = skynet.uniqueservice(uniservice.service)
		skynet.name(uniservice.named, sid)
	end
end