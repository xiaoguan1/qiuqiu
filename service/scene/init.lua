local skynet = require "skynet"
local math = math

PROTO_FUN = {}

balls = {}    -- [playerid] = ball

foods = {}    -- [id] = food
food_maxid, food_count = 0, 0

skynet.init(function()
	skynet.fork(function()
		--　保持帧率执行
		local stime = skynet.now()
		local frame = 0
		while true do
			frame = frame + 1
			local isok, err = pcall(update, frame)

			if not isok then skynet.error(err) end

			local etime = skynet.now()
			local waittime = frame * 20 - (etime - stime)

			if waittime <= 0 then waittime = 2 end

			skynet.sleep(waittime)
		end
	end)
end)

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local fun = PROTO_FUN[cmd]
		if not fun then
			-- 后续补上错误打印
			print(string.format("[%s] [session:%s], [cmd:%s] not find fun.", SERVICE_NAME, session, cmd))
			return
		end
		if session == 0 then
			xpcall(fun, traceback, address, ...)
		else
			local ret = table.pack(xpcall(fun, traceback, address, ...))
			local isOk = ret[1]
			if not isOk then
				skynet.ret()
				return
			end
			skynet.retpack(table.unpack(ret, 2))
		end
	end)

	dofile("./service/scene/battle/battle.lua")
end)


function ball(playerid, node, agent)
	local m = {
		playerid = playerid,
		node = node,
		agent = agent,
		x = math.random(0, 100),
		y = math.random(0, 100),
		size = 2,
		speedx = 0,
		speedy = 0,
	}
	return m
end

function food()
	local m = {
		id = nil,
		x = math.random(0, 100),
		y = math.random(0, 100),
	}
	return m
end

-- 广播
function broadcast(msg)
	for _, v in pairs(balls) do
		s.send(v.node, v.agent, "send", msg)
	end
end

-- 位置更新
function move_update()
	for _, v in pairs(balls) do
		v.x = v.x + v.speedx * 0.2
		v.y = v.y + v.speedy * 0.2
		if v.speedx ~= 0 or v.speedy ~= 0 then
			local msg = {"move", v.playerid, v.x, v.y}
			broadcast(msg)
		end
	end
end

-- 食物生成
function food_update()
	if food_count > 50 then return end

	if math.random(1, 100) < 98 then return end

	food_maxid = food_maxid + 1
	food_count = food_count + 1
	local f = food()
	f.id = food_maxid
	foods[f.id] = f

	local msg = {"addfood", f.id, f.x, f.y}
	broadcast(msg)
end

-- 吞下食物
function eat_update()
	for _playerid, b in pairs(balls) do
		for fid, f in pairs(foods) do
			-- 勾股定理可得出是否在范围内
			if (b.x - f.x) ^ 2 + (b.y - f.y) ^ 2 < b.size ^ 2 then
				b.size = b.size + 1
				food_count = food_count - 1
				local msg = {"eat", b.playerid, fid, b, size}
				broadcast(msg)
				foods[fid] = nil
			end
		end
	end
end

-- 由定时器推动的主循环（食物生成、位置更新、碰撞检测等等）
function update(frame)
	food_update()
	move_update()
	eat_update()
end