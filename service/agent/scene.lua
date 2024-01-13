local skynet = require "skynet"
local runconfig = require "runconfig"
local mynode = skynet.getenv("node")

snode = nil
sname = nil

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

PROTO_FUN.enter = function(msg)
    if sname then return {"enter", 1, "已在场景"} end

    local snode, sid = random_scene()
    local sname = "scene" .. sid
    local isok = skynet.call(snode, sname, "enter", id, mynode, skynet.self())

    if not isok then return {"enter", 1, "进入失败"} end

    snode = snode
    sname = sname
    return nil
end

PROTO_FUN.leave_scene = function()
    --　不在场景中
    if not sname then return end

    skynet.call(snode, name, "leave", id)
    snode = nil
    sname = nil
end