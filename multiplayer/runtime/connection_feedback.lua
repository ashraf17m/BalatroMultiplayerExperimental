local connection_feedback = MP.CONNECTION_FEEDBACK or {}
MP.CONNECTION_FEEDBACK = connection_feedback
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function warn_connection_message(message)
	if type(message) ~= "string" or message == "" then
		return false
	end

	sendWarnMessage(message, "MULTIPLAYER")
	return true
end

local function show_connection_overlay(message, no_back)
	if
		MP.UI
		and MP.UI.UTILS
		and MP.UI.UTILS.overlay_message
		and type(message) == "string"
		and message ~= ""
	then
		MP.UI.UTILS.overlay_message(message, no_back)
		return true
	end

	return false
end

local function show_connection_attention_text(message)
	attention_text({
		scale = 0.4,
		text = message,
		hold = 4,
		align = "cm",
		offset = { x = 0, y = 1.5 },
		major = BALATRO.get_room_attach and BALATRO.get_room_attach() or nil,
	})
end

function connection_feedback.get_runtime()
	connection_feedback.RUNTIME = connection_feedback.RUNTIME or {
		enemy_disconnect_countdown = nil,
		self_reconnect_countdown = nil,
	}

	return connection_feedback.RUNTIME
end

function connection_feedback.initialize_runtime_state()
	local runtime = connection_feedback.get_runtime()
	runtime.enemy_disconnect_countdown = nil
	runtime.self_reconnect_countdown = nil
	return runtime
end

function connection_feedback.clear_enemy_disconnect_countdown()
	local runtime = connection_feedback.get_runtime()
	runtime.enemy_disconnect_countdown = nil
end

function connection_feedback.clear_self_reconnect_countdown()
	local runtime = connection_feedback.get_runtime()
	runtime.self_reconnect_countdown = nil
end

function connection_feedback.clear_all_countdowns()
	local runtime = connection_feedback.get_runtime()
	runtime.enemy_disconnect_countdown = nil
	runtime.self_reconnect_countdown = nil
end

function connection_feedback.has_self_reconnect_countdown()
	local runtime = connection_feedback.get_runtime()
	return runtime.self_reconnect_countdown ~= nil
end

function connection_feedback.show_notice(message, opts)
	local options = opts or {}
	local notice_message = type(message) == "string" and message or tostring(message or "")
	if notice_message == "" then
		return false
	end

	local overlay_message = options.overlay_message
	if overlay_message == nil then
		overlay_message = notice_message
	end

	if options.warn ~= false then
		warn_connection_message(notice_message)
	end

	if options.trace_details and options.trace_details ~= notice_message then
		sendTraceMessage(tostring(options.trace_details), "MULTIPLAYER")
	end

	if options.overlay ~= false and overlay_message ~= false then
		show_connection_overlay(overlay_message, options.no_back)
	end

	return true
end

function connection_feedback.show_resume_restore_failed(concise_error, trace_details)
	local error_summary = tostring(concise_error or "Unknown resume restore error.")
	return connection_feedback.show_notice(
		"Failed to restore multiplayer match. " .. error_summary,
		{
			trace_details = trace_details,
			overlay_message = "Failed to restore multiplayer match.\n" .. error_summary,
		}
	)
end

function connection_feedback.begin_enemy_disconnect(username, timeout, player_id)
	local display_name = username or "Opponent"
	local countdown_timeout = timeout or 60

	warn_connection_message(display_name .. " disconnected, waiting for reconnection...")

	if not MP.is_ffa_mode() and not MP.is_teams_mode() then
		local runtime = connection_feedback.get_runtime()
		runtime.enemy_disconnect_countdown = {
			end_time = (BALATRO.get_wall_time and BALATRO.get_wall_time() or 0) + countdown_timeout,
			display = countdown_timeout .. "s remaining",
			player_id = player_id,
		}

		MP.UI.UTILS.overlay_message_countdown(
			display_name .. " disconnected,\nwaiting for reconnection...",
			runtime.enemy_disconnect_countdown,
			true
		)
		return true
	end

	show_connection_attention_text(display_name .. " disconnected")
	return true
end

function connection_feedback.handle_enemy_reconnected(username, player_id)
	if player_id and player_id == (BALATRO.get_player_id and BALATRO.get_player_id() or nil) then
		return false
	end

	local runtime = connection_feedback.get_runtime()
	local enemy_disconnect_countdown = runtime.enemy_disconnect_countdown
	if
		enemy_disconnect_countdown
		and player_id
		and enemy_disconnect_countdown.player_id
		and enemy_disconnect_countdown.player_id ~= player_id
	then
		return false
	end

	local display_name = username or "Opponent"
	runtime.enemy_disconnect_countdown = nil
	warn_connection_message(display_name .. " reconnected!")

	if not MP.is_ffa_mode() and not MP.is_teams_mode() then
		if BALATRO.exit_overlay_menu then
			BALATRO.exit_overlay_menu()
		end
		show_connection_overlay(display_name .. " reconnected!")
	else
		show_connection_attention_text(display_name .. " reconnected")
	end

	return true
end

function connection_feedback.begin_self_reconnect(timeout)
	local countdown_timeout = timeout or 120
	local runtime = connection_feedback.get_runtime()
	runtime.self_reconnect_countdown = {
		end_time = (BALATRO.get_wall_time and BALATRO.get_wall_time() or 0) + countdown_timeout,
		display = countdown_timeout .. "s remaining",
	}

	warn_connection_message("Connection lost, attempting to reconnect...")
	MP.UI.UTILS.overlay_message_countdown(
		"Connection lost,\nattempting to reconnect...",
		runtime.self_reconnect_countdown,
		true
	)
	return runtime.self_reconnect_countdown
end

function connection_feedback.update_countdowns(on_self_reconnect_timeout)
	local runtime = connection_feedback.get_runtime()
	if not (runtime.enemy_disconnect_countdown or runtime.self_reconnect_countdown) then
		return
	end

	local now = BALATRO.get_wall_time and BALATRO.get_wall_time() or 0

	if runtime.enemy_disconnect_countdown then
		local remaining = math.max(0, math.ceil(runtime.enemy_disconnect_countdown.end_time - now))
		runtime.enemy_disconnect_countdown.display = remaining .. "s remaining"
	end

	if runtime.self_reconnect_countdown then
		local remaining = math.max(0, math.ceil(runtime.self_reconnect_countdown.end_time - now))
		runtime.self_reconnect_countdown.display = remaining .. "s remaining"
		if remaining <= 0 then
			runtime.self_reconnect_countdown = nil
			if on_self_reconnect_timeout then
				on_self_reconnect_timeout("Reconnection failed.\nReturning to main menu.")
			end
		end
	end
end
