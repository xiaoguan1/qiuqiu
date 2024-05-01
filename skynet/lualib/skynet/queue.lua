local skynet = require "skynet"
local coroutine = coroutine
local xpcall = xpcall
local traceback = debug.traceback
local table = table

if SERVICE_NAME == "agent" then	-- agent服务要特殊处理
	
local co2urs = {
	-- [co] = urs,	-- 协程对应的urs
}

-- 获取协程对应的urs
function skynet.get_co2urs()
	return co2urs
end

function skynet.queue()
	local current_thread
	local ref = 0
	-- local thread_queue = {}
	local thread_queue = {h = 1, t = 0}

	local function xpcall_ret(self, thread, ok, ...)
		ref = ref - 1
		if ref == 0 then
			-- current_thread = table.remove(thread_queue, 1)
			local h = thread_queue.h
			current_thread = thread_queue[h]
			thread_queue[h] = nil
			thread_queue.h = h + 1
			if thread_queue.h > thread_queue.t then
				-- queue is empty
				thread_queue.h = 1
				thread_queue.t = 0
			end
			if current_thread then
				skynet.wakeup(current_thread)
			end
		end
		local urs = self.ownerUrs
		if urs then
			assert(coroutine.running() == thread)
			co2urs[thread] = nil
		end
		assert(ok, (...))
		return ...
	end

	local M = setmetatable(
		{
			GetThreadQueueLength = function ()
				return thread_queue.t - thread_queue.h + 1
			end,
			GetCurrentThread = function ()
				return current_thread
			end,
			ownerUrs = nil,		-- 专门针对玩家的
			SetOwnerUrs = function (self, urs)
				self.ownerUrs = urs
			end,
		},
		{
			__call = function (self, f, ...)
				local thread = coroutine.running()
				if current_thread and current_thread ~= thread then
					-- table.insert(thread_queue, thread)
					thread_queue.t = thread_queue.t + 1
					thread_queue[thread_queue.t] = thread
					skynet.wait()
					assert(ref == 0)	-- current_thread == thread
				end
				current_thread = thread

				ref = ref + 1
				local urs = self.ownerUrs
				if urs then
					co2urs[thread] = urs
				end
				return xpcall_ret(self, thread, xpcall(f, traceback, ...))
			end,
		}
	)

	return M
end

else

function skynet.queue()
	local current_thread
	local ref = 0
	-- local thread_queue = {}
	local thread_queue = {h = 1, t = 0}	-- 目的：优化掉table.remove函数

	local function xpcall_ret(ok, ...)
		ref = ref - 1
		if ref == 0 then
			-- queue is empty
			-- current_thread = table.remove(thread_queue,1)
			local h = thread_queue.h
			current_thread = thread_queue[h]
			thread_queue[h] = nil
			thread_queue.h = h + 1
			if thread_queue.h > thread_queue.t then
				thread_queue.h = 1
				thread_queue.t = 0
			end
			if current_thread then
				skynet.wakeup(current_thread)
			end
		end
		assert(ok, (...))
		return ...
	end

	return function(f, ...)
		local thread = coroutine.running()
		if current_thread and current_thread ~= thread then
			-- table.insert(thread_queue, thread)
			thread_queue.t = thread_queue.t + 1
			thread_queue[thread_queue.t] = thread
			skynet.wait()
			assert(ref == 0)	-- current_thread == thread
		end
		current_thread = thread

		ref = ref + 1
		return xpcall_ret(xpcall(f, traceback, ...))
	end
end

end

return skynet.queue
