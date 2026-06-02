MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.BALATRO = MP.PLATFORM.BALATRO or {}

local BALATRO = MP.PLATFORM.BALATRO

local build_threading_traceback =
	(MP.BOOTSTRAP_INTERNAL and MP.BOOTSTRAP_INTERNAL.build_traceback)
	or function(err) return tostring(err) end

function BALATRO.create_thread(thread_path)
	if not (love and love.thread and type(love.thread.newThread) == "function") then
		return nil
	end

	local ok, result = xpcall(function()
		return love.thread.newThread(thread_path)
	end, build_threading_traceback)
	if not ok then
		return nil, result
	end

	return result
end

function BALATRO.start_thread(thread, ...)
	if not (thread and type(thread.start) == "function") then
		return false
	end

	local ok, err = xpcall(function(...)
		thread:start(...)
	end, build_threading_traceback, ...)
	if not ok then
		return false, err
	end

	return true
end

function BALATRO.get_thread_channel(name)
	if not (love and love.thread and type(love.thread.getChannel) == "function") then
		return nil
	end
	if type(name) ~= "string" or name == "" then
		return nil
	end

	return love.thread.getChannel(name)
end

function BALATRO.push_thread_channel(name, payload)
	local channel = BALATRO.get_thread_channel(name)
	if not channel then
		return false
	end

	channel:push(payload)
	return true
end

function BALATRO.pop_thread_channel(name)
	local channel = BALATRO.get_thread_channel(name)
	if not channel then
		return nil
	end

	return channel:pop()
end
