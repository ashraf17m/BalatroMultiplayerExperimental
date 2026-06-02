local json = require("json")

MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}

local network_loop = {}
local BALATRO = MP.PLATFORM.BALATRO
-- Bound per-frame queue work while still draining normal socket-thread bursts.
local MAX_NETWORK_MESSAGES_PER_UPDATE = 128
local is_runtime_trace_enabled = (MP.UTILS and MP.UTILS.is_runtime_trace_enabled) or function() return false end
local build_network_runtime_traceback =
	(MP.UTILS and MP.UTILS.build_traceback)
	or (MP.BOOTSTRAP_INTERNAL and MP.BOOTSTRAP_INTERNAL.build_traceback)
	or function(err) return tostring(err) end

local function refresh_live_team_score()
	local teams_domain = MP.DOMAIN and MP.DOMAIN.TEAMS or nil
	if teams_domain and teams_domain.refresh_live_score then
		teams_domain.refresh_live_score()
	end
end

local function get_network_message_preview(msg)
	local preview = tostring(msg)
	if string.len(preview) > 240 then
		preview = string.sub(preview, 1, 240) .. "..."
	end

	return preview
end

function network_loop.warn_runtime_issue(summary, details)
	sendWarnMessage(summary, "MULTIPLAYER")
	if details and details ~= summary then
		sendTraceMessage(details, "MULTIPLAYER")
	end
end

function network_loop.initialize_runtime_loop_state()
	MP.CONNECTION_FEEDBACK.initialize_runtime_state()
end

function network_loop.transition_to_menu_after_connection_loss(message, opts)
	MP.MATCH_LIFECYCLE.transition_to_menu_after_connection_loss(message, opts)
end

function network_loop.handle_reconnect_timeout(message)
	network_loop.transition_to_menu_after_connection_loss(message)
end

function network_loop.update_disconnect_countdowns()
	MP.CONNECTION_FEEDBACK.update_countdowns(network_loop.handle_reconnect_timeout)
end

local last_game_seed = nil

local function append_action_payload_log(log, action_name, payload)
	for k, v in pairs(payload or {}) do
		if action_name == "startGame" and k == "seed" then
			last_game_seed = v
		else
			log = log .. string.format(" (%s: %s) ", k, v)
		end
	end

	if action_name == "receiveEndGameJokers" and last_game_seed then
		log = log .. string.format(" (seed: %s) ", last_game_seed)
	end

	return log
end

function network_loop.handle_outdated_server_message(msg)
	if string.sub(msg, 1, 1) ~= "a" then
		return false
	end

	if msg ~= "action:keepAlive" then
		BALATRO.push_thread_channel("networkToUi", json.encode({
			action = "error",
			message = "Attempting to connect to outdated server",
		}))
		BALATRO.push_thread_channel("networkToUi", '{"action":"disconnected"}')
	end

	return true
end

function network_loop.log_network_action(parsed_action)
	if not is_runtime_trace_enabled() then
		return
	end

	if type(parsed_action) ~= "table" then
		return
	end

	if tonumber(parsed_action.version) == (MP.PROTOCOL and MP.PROTOCOL.VERSION or 2)
		and type(parsed_action.family) == "string"
		and type(parsed_action.action) == "string"
	then
		local route_name = string.format("%s.%s", parsed_action.family, parsed_action.action)
		local log = append_action_payload_log(
			string.format("Client got protocol_v2 %s message: ", route_name),
			parsed_action.action,
			parsed_action.payload
		)
		if sendTraceMessage then
			sendTraceMessage(log, "MULTIPLAYER")
		end
		return
	end

	local action_name = parsed_action.action
	if (action_name == "keepAlive") or (action_name == "keepAliveAck") then
		return
	end

	local log = append_action_payload_log(
		string.format("Client got %s message: ", tostring(action_name)),
		action_name,
		parsed_action
	)
	if sendTraceMessage then
		sendTraceMessage(log, "MULTIPLAYER")
	end
end

function network_loop.dispatch_network_action(parsed_action)
	if MP.NETWORKING_INTERNAL.dispatch_parsed_action then
		MP.NETWORKING_INTERNAL.dispatch_parsed_action(parsed_action)
	else
		sendWarnMessage("No multiplayer action dispatcher loaded for " .. tostring(parsed_action.action), "MULTIPLAYER")
	end
end

function network_loop.decode_network_action_message(msg)
	local ok, parsed_action = xpcall(function()
		return json.decode(msg)
	end, build_network_runtime_traceback)

	if not ok then
		network_loop.warn_runtime_issue(
			"Failed to decode multiplayer message.",
			tostring(parsed_action) .. "\nRaw payload: " .. get_network_message_preview(msg)
		)
		return nil
	end

	if type(parsed_action) ~= "table" then
		network_loop.warn_runtime_issue(
			"Received malformed multiplayer message.",
			"Decoded payload was not an action table. Raw payload: " .. get_network_message_preview(msg)
		)
		return nil
	end

	if tonumber(parsed_action.version) == (MP.PROTOCOL and MP.PROTOCOL.VERSION or 2) then
		local decoded_packet, protocol_err = MP.PROTOCOL.decode_v2_packet(parsed_action)
		if not decoded_packet then
			network_loop.warn_runtime_issue(
				"Failed to decode multiplayer protocol v2 message.",
				tostring(protocol_err) .. "\nRaw payload: " .. get_network_message_preview(msg)
			)
			return nil
		end

		return decoded_packet
	end

	if type(parsed_action.action) ~= "string" or parsed_action.action == "" then
		network_loop.warn_runtime_issue(
			"Received multiplayer message without an action.",
			"Raw payload: " .. get_network_message_preview(msg)
		)
		return nil
	end

	return parsed_action
end

function network_loop.process_network_messages()
	local processed_messages = 0
	while processed_messages < MAX_NETWORK_MESSAGES_PER_UPDATE do
		local msg = BALATRO.pop_thread_channel("networkToUi")
		if msg then
			processed_messages = processed_messages + 1
			if network_loop.handle_outdated_server_message(msg) then
				return
			end

			local parsed_action = network_loop.decode_network_action_message(msg)
			if parsed_action then
				network_loop.log_network_action(parsed_action)
				network_loop.dispatch_network_action(parsed_action)
			end
		else
			return
		end
	end
end

function network_loop.run_update_cycle()
	network_loop.update_disconnect_countdowns()

	refresh_live_team_score()

	network_loop.process_network_messages()
end

function network_loop.install_runtime_loop()
	if MP.NETWORKING_INTERNAL.runtime_loop_installed then
		return
	end

	network_loop.initialize_runtime_loop_state()

	if not (MP.GAME_UPDATE_CYCLE and MP.GAME_UPDATE_CYCLE.install and MP.GAME_UPDATE_CYCLE.install()) then
		sendWarnMessage("Failed to install multiplayer game update cycle.", "MULTIPLAYER")
		return
	end

	MP.NETWORKING_INTERNAL.runtime_loop_installed = true
end

MP.GAME_UPDATE_CYCLE.register_after("mp.networking.runtime_loop", function()
	network_loop.run_update_cycle()
end, 40)

MP.NETWORKING_INTERNAL.warn_runtime_issue = network_loop.warn_runtime_issue
MP.NETWORKING_INTERNAL.install_runtime_loop = network_loop.install_runtime_loop
MP.NETWORKING_INTERNAL.process_network_messages = network_loop.process_network_messages
MP.NETWORKING_INTERNAL.transition_to_menu_after_connection_loss = network_loop.transition_to_menu_after_connection_loss
