MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}

local SOCKET_THREAD_PARTS = {
	"networking/socket_thread_setup.lua",
	"networking/socket_thread_queues.lua",
	"networking/socket_thread_loop.lua",
}

local warn_transport_failure = MP.NETWORKING_INTERNAL.warn_runtime_issue or function(summary, details)
	sendWarnMessage(summary, "MULTIPLAYER")
	if details and details ~= summary then
		sendTraceMessage(details, "MULTIPLAYER")
	end
end

local function fail_transport_start(summary, details)
	MP.NETWORKING_THREAD = nil
	MP.NETWORKING_INTERNAL.networking_started = false
	warn_transport_failure(summary, details)
	return false
end

local function build_socket_thread_source()
	local parts = {}

	for _, file in ipairs(SOCKET_THREAD_PARTS) do
		local part = MP.PLATFORM.SMODS.load_mod_file(file, { required = true })
		if part == nil then
			return nil
		end

		parts[#parts + 1] = part
	end

	return table.concat(parts, "\n")
end

local function start_networking()
	if MP.NETWORKING_INTERNAL.networking_started then
		return true
	end

	local socket_source = build_socket_thread_source()
	if not socket_source then
		sendWarnMessage("Failed to load multiplayer networking socket.", "MULTIPLAYER")
		return false
	end

	local thread_api = MP.PLATFORM and MP.PLATFORM.BALATRO or nil
	local config_api = MP.PLATFORM and MP.PLATFORM.SMODS or nil
	local connection_settings = config_api and config_api.get_connection_settings and config_api.get_connection_settings(MP) or {}
	local connect_action = MP.ACTIONS and MP.ACTIONS.connect or nil

	if type(connect_action) ~= "function" then
		return fail_transport_start("Missing multiplayer connect action.")
	end

	if not (thread_api and type(thread_api.create_thread) == "function") then
		return fail_transport_start("Missing multiplayer networking thread creation API.")
	end

	local created_thread, create_error = thread_api.create_thread(socket_source)
	MP.NETWORKING_THREAD = created_thread
	if not MP.NETWORKING_THREAD then
		return fail_transport_start("Failed to create multiplayer networking thread.", create_error)
	end

	if type(thread_api.start_thread) ~= "function" then
		return fail_transport_start("Missing multiplayer networking thread start API.")
	end

	local started, start_error = thread_api.start_thread(
		MP.NETWORKING_THREAD,
		connection_settings.server_url,
		connection_settings.server_port
	)
	if not started then
		return fail_transport_start("Failed to start multiplayer networking thread.", start_error)
	end

	MP.NETWORKING_INTERNAL.networking_started = true
	connect_action()
	return true
end

MP.NETWORKING_INTERNAL.start_networking = start_networking
