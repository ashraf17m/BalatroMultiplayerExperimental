MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.BALATRO = MP.PLATFORM.BALATRO or {}

local BALATRO = MP.PLATFORM.BALATRO

function BALATRO.create_thread(thread_path)
	if not (love and love.thread and type(love.thread.newThread) == "function") then
		return nil
	end

	return love.thread.newThread(thread_path)
end

function BALATRO.start_thread(thread, ...)
	if not (thread and type(thread.start) == "function") then
		return false
	end

	thread:start(...)
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
