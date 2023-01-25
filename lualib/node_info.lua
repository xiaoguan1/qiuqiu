local skynet = require "skynet"
local DatabaseCommon = require "database_common"

local M = {}

-- 获取当前节点的信息
function M.GetNodeInfo()
	local config = DatabaseCommon.GetServerConfig()

	DPCLUSTER_NODE = {
		no = config.server_id,	-- 当前节点的服务器编号
		main_ip_port = config.main_node_ip .. ":" .. config.main_node_port,	-- 服务器地址
		cluster_ip_port = config.cluster_node_ip .. ":" .. config.cluster_node_port, -- 集群地址
	}
	return DPCLUSTER_NODE
end

function M.GetClusterCfg()
	if not DPCLUSTER_NODE then
		error("GetClusterCfg error.")
	end

	local ret = {}
	for key, value in pairs(DPCLUSTER_NODE) do
		if key ~= "no" then
			ret[value] = value
		end
	end

	ret.__nowaiting = skynet.getenv("nowaiting") == "true" and true or false
	return ret
end

return M