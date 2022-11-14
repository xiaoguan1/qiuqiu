local skynet = require "skynet"

local runconfig = require "runconfig"
local mynode = skynet.getenv("node")

s.snode = nil
s.sname = nil

local function random_scene()
    -- 选择node
    local nodes = {}
    for k, v in pairs(runconfig.scene) do
        table.insert(nodes, k)
        if runconfig.scene[mynode] then
            table.insert(nodes, mynode)
        end
    end

    local idx = math.random(1, #nodes)
    local scenenode = nodes[idx]

    --　具体场景
    local scenelist = runconfig.scene[scenenode]
    local idx = math.random(1, #scenelist)
    local sceneid = scenelist[idx]
    return scenenode, sceneid
end

-- s.client.enter = function(msg)
--     if s.sname then return {"enter", 1, "已在场景"} end

--     local snode, sid = random_scene()
--     local sname = "scene" .. sid
--     print("sssssssssss222 ", snode, sname)
--     local isok = s.call(snode, sname, "enter", s.id, mynode, skynet.self())

--     if not isok then return {"enter", 1, "进入失败"} end

--     s.snode = snode
--     s.sname = sname
--     return nil
-- end

s.leave_scene = function()
    --　不在场景中
    if not s.sname then return end

    s.call(s.snode, s.name, "leave", s.id)
    s.snode = nil
    s.sname = nil
end