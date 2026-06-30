local function get_network_to_ui_channel()
	if not (love and love.thread and love.thread.getChannel) then
		return nil
	end

	local ok, channel = pcall(love.thread.getChannel, "networkToUi")
	if ok then
		return channel
	end

	return nil
end

local function get_texture_memory_mib()
	if not (love and love.graphics and love.graphics.getStats) then
		return nil
	end

	local ok, stats = pcall(love.graphics.getStats)
	if ok and type(stats) == "table" and tonumber(stats.texturememory) then
		return stats.texturememory / 1024 / 1024
	end

	return nil
end

function MP.UTILS.log_mem_debug_messages()
	if not (MP.EXPERIMENTAL and MP.EXPERIMENTAL.mem_debug) then
		return false
	end

	sendDebugMessage("Lua memory in use: " .. tostring(collectgarbage("count") / 1024) .. " MiB", "MULTIPLAYER")

	local texture_memory_mib = get_texture_memory_mib()
	if texture_memory_mib then
		sendDebugMessage("Texture memory in use: " .. tostring(texture_memory_mib) .. " MiB", "MULTIPLAYER")
	end

	local network_to_ui = get_network_to_ui_channel()
	local queued_messages = network_to_ui and network_to_ui.getCount and network_to_ui:getCount() or 0
	if queued_messages > 10 then
		sendDebugMessage("High networkToUi count: " .. tostring(queued_messages), "MULTIPLAYER")
	end

	if MP._DEBUG_PANIC_COLLECTS then
		sendDebugMessage("nuGC panic collects: " .. tostring(MP._DEBUG_PANIC_COLLECTS), "MULTIPLAYER")
	end

	return true
end
