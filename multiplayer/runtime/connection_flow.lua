MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}

local connection_flow = {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}

local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end

local function resume_error_invalidates_saved_match(message)
	if type(message) ~= "string" then
		return false
	end

	return string.find(message, "Could not rejoin lobby", 1, true) ~= nil
		or string.find(message, "Lobby no longer exists", 1, true) ~= nil
end

local function flush_requested_ui_refreshes()
	if MP.UI and MP.UI.flush_requested_refreshes then
		MP.UI.flush_requested_refreshes()
	end
end

local function request_overlay_close_if_open()
	if BALATRO and BALATRO.get_overlay_menu and BALATRO.get_overlay_menu() then
		MP.CONNECTION_SESSION.request_overlay_menu_close()
	end
end

local function show_notice_after_ui_settles(message)
	flush_requested_ui_refreshes()
	MP.CONNECTION_FEEDBACK.show_notice(message)
end

local function queue_notice_after_main_menu(message)
	if not (BALATRO and BALATRO.queue_event) then
		show_notice_after_ui_settles(message)
		return
	end

	BALATRO.queue_event({
		no_delete = true,
		trigger = "immediate",
		blockable = false,
		blocking = false,
		func = function()
			if not (BALATRO.get_main_menu_ui and BALATRO.get_main_menu_ui()) then
				return
			end

			show_notice_after_ui_settles(message)
			return true
		end,
	})
end

local function transition_to_main_menu_with_notice(message)
	request_overlay_close_if_open()

	local root = BALATRO and BALATRO.get_root and BALATRO.get_root() or nil
	if not (root and root.STAGE ~= root.STAGES.MAIN_MENU) then
		return false
	end

	if match_domain.reset_state then
		match_domain.reset_state()
	end
	if BALATRO and BALATRO.go_to_menu then
		BALATRO.go_to_menu()
	end

	MP.CONNECTION_SESSION.refresh_connection_status_ui()
	queue_notice_after_main_menu(message)
	return true
end

local function clear_failed_rejoin_state()
	if MP.CONNECTION_RESUME.get_pending_manual_resume() then
		MP.CONNECTION_RESUME.fail_manual_resume(true)
	elseif MP.MATCH_LIFECYCLE and MP.MATCH_LIFECYCLE.clear_saved_resume then
		MP.MATCH_LIFECYCLE.clear_saved_resume()
	end

	if MP.CONNECTION_FEEDBACK and MP.CONNECTION_FEEDBACK.clear_self_reconnect_countdown then
		MP.CONNECTION_FEEDBACK.clear_self_reconnect_countdown()
	end

	local session_result = MP.CONNECTION_SESSION.clear_local_lobby_session({
		clear_reconnect = true,
		clear_feedback = true,
		refresh_status = false,
	})
	MP.CONNECTION_SESSION.set_client_connected(true)
	return session_result
end

local function handle_failed_rejoin(message)
	local notice_message = message or "Could not rejoin lobby."
	local session_result = clear_failed_rejoin_state()

	if transition_to_main_menu_with_notice(notice_message) then
		return true
	end

	if session_result and session_result.rebuilt_main_menu_shell then
		queue_notice_after_main_menu(notice_message)
		return true
	end

	MP.CONNECTION_SESSION.refresh_connection_status_ui()
	queue_notice_after_main_menu(notice_message)
	return true
end

local function apply_server_lobby_entry_state(code, gamemode_key, lobby_type, reconnect_token, player_id, options, players, is_host, is_in_game, is_coop_save_restore)
	MP.CONNECTION_SESSION.set_reconnect_lobby_state(reconnect_token, code)
	MP.LOBBY_SESSION.apply_joined_lobby_state(code, gamemode_key, lobby_type, player_id)

	local applied, result = MP.LOBBY_SESSION.apply_initial_lobby_snapshot(options, players, is_host, is_in_game, is_coop_save_restore)
	if not applied then
		MP.LOBBY_SESSION.handle_lobby_option_failure(result)
		return false
	end

	return true
end

local function handle_rejoined_lobby_snapshot_failure(pending_resume)
	if pending_resume then
		trace_runtime_event("resume.rejoin_snapshot_apply_failed", {
			pending_resume = true,
			clear_saved_files = false,
		})
		MP.CONNECTION_RESUME.fail_manual_resume(false)
	end
end

function connection_flow.handle_connected()
	local reconnect_token, last_lobby_code = MP.CONNECTION_SESSION.get_reconnect_lobby_state()
	trace_runtime_event("connection.connected", {
		has_reconnect_token = reconnect_token ~= nil,
		has_last_lobby_code = last_lobby_code ~= nil,
	})

	MP.CONNECTION_SESSION.set_client_connected(true)
	MP.NETWORKING_INTERNAL.send_connection_identity()

	if reconnect_token and last_lobby_code then
		trace_runtime_event("connection.rejoin_send", {
			lobby_code = last_lobby_code,
		})
		MP.NETWORKING_INTERNAL.send_connection_rejoin(last_lobby_code, reconnect_token)
	end
end

function connection_flow.handle_joined_lobby(code, gamemode_key, lobby_type, token, player_id, options, players, is_host, is_in_game, is_coop_save_restore)
	local reconnect_token = select(1, MP.CONNECTION_SESSION.get_reconnect_lobby_state())

	if not MP.NETWORKING_INTERNAL.ensure_server_player_id(player_id, "Connection failed.") then
		return
	end

	MP.CONNECTION_RESUME.complete_manual_resume()
	apply_server_lobby_entry_state(code, gamemode_key, lobby_type, token or reconnect_token, player_id, options, players, is_host, is_in_game, is_coop_save_restore)
end

function connection_flow.handle_rejoined_lobby(code, gamemode_key, lobby_type, token, player_id, options, players, is_host, is_in_game, is_coop_save_restore)
	if not MP.NETWORKING_INTERNAL.ensure_server_player_id(player_id, "Rejoin failed.") then
		trace_runtime_event("resume.rejoin_blocked", {
			reason = "missing_server_player_id",
			code = code,
		})
		return
	end

	local pending_resume = MP.CONNECTION_RESUME.get_pending_manual_resume()
	trace_runtime_event("resume.rejoin_received", {
		code = code,
		lobby_type = lobby_type,
		is_in_game = is_in_game,
		pending_resume = pending_resume ~= nil,
	})

	if pending_resume then
		trace_runtime_event("resume.runtime_sync_buffer_activate", {
			code = code,
		})
		MP.CONNECTION_RESUME.activate_runtime_match_sync_buffer()
	end

	MP.CONNECTION_FEEDBACK.clear_self_reconnect_countdown()
	if not apply_server_lobby_entry_state(code, gamemode_key, lobby_type, token, player_id, options, players, is_host, is_in_game, is_coop_save_restore) then
		handle_rejoined_lobby_snapshot_failure(pending_resume)
		return
	end
	MP.MATCH_LIFECYCLE.reset_local_blind_ready_runtime()
	MP.CONNECTION_SESSION.request_overlay_menu_close()

	if pending_resume then
		if not is_in_game then
			trace_runtime_event("resume.rejoin_inactive_match", {
				code = code,
				clear_saved_files = true,
			})
			MP.CONNECTION_RESUME.fail_manual_resume(true)
			MP.CONNECTION_FEEDBACK.show_notice("Match is no longer active.")
			return
		end

		trace_runtime_event("resume.restore_start", {
			code = code,
		})
		if MP.CONNECTION_RESUME.resume_saved_match(pending_resume, code, token, player_id) then
			trace_runtime_event("resume.restore_success_notice", {
				code = code,
			})
			MP.CONNECTION_FEEDBACK.show_notice("Match resumed!", {
				overlay = false,
			})
		end
		return
	end

	MP.CONNECTION_FEEDBACK.show_notice("Reconnected to lobby!")
end

function connection_flow.handle_keep_alive()
	MP.NETWORKING_INTERNAL.send_keep_alive_ack()
end

function connection_flow.handle_enemy_disconnected(username, timeout, player_id)
	MP.CONNECTION_FEEDBACK.begin_enemy_disconnect(username, timeout, player_id)
end

function connection_flow.handle_enemy_reconnected(username, player_id)
	MP.CONNECTION_FEEDBACK.handle_enemy_reconnected(username, player_id)
end

function connection_flow.handle_error(message, display)
	local team_money_ui = MP.UI and MP.UI.TEAM_MONEY or nil
	if team_money_ui and team_money_ui.clear_pending_target_row then
		team_money_ui.clear_pending_target_row()
	end

	if display == "log" then
		MP.CONNECTION_FEEDBACK.show_notice(message, { overlay = false })
		return
	end

	if resume_error_invalidates_saved_match(message) then
		trace_runtime_event("resume.rejoin_failed", {
			message = message,
			clear_saved_files = true,
		})
		handle_failed_rejoin(message)
		return
	end

	MP.CONNECTION_FEEDBACK.show_notice(message)
end

function connection_flow.handle_kicked_from_lobby(message)
	local notice_message = message or "You have been kicked from the lobby."

	MP.MATCH_LIFECYCLE.clear_saved_resume()
	-- A lobby kick should only end the current lobby session, not the
	-- underlying multiplayer service connection.
	local session_result = MP.CONNECTION_SESSION.clear_local_lobby_session({
		clear_reconnect = true,
		clear_feedback = true,
		refresh_status = false,
	})

	if transition_to_main_menu_with_notice(notice_message) then
		return
	end

	if session_result and session_result.rebuilt_main_menu_shell then
		queue_notice_after_main_menu(notice_message)
		return
	end

	-- The menu-transition path already refreshed the status UI. Only the
	-- fallback in-place notice path still needs it here.
	MP.CONNECTION_SESSION.refresh_connection_status_ui()
	MP.CONNECTION_FEEDBACK.show_notice(notice_message)
end

function connection_flow.handle_disconnected()
	local was_in_match = MP.is_lobby_match_in_progress and MP.is_lobby_match_in_progress()
	trace_runtime_event("connection.disconnected", {
		was_in_match = was_in_match,
	})
	MP.CONNECTION_SESSION.set_client_connected(false)
	MP.CONNECTION_FEEDBACK.clear_self_reconnect_countdown()

	if was_in_match and MP.NETWORKING_INTERNAL.transition_to_menu_after_connection_loss then
		trace_runtime_event("connection.loss_resume_path", {
			was_in_match = true,
		})
		MP.NETWORKING_INTERNAL.transition_to_menu_after_connection_loss(nil, {
			resume_message = "Connection lost.\nUse Play -> Resume the Match within 120s.",
			no_resume_message = "Connection lost.\nNo safe resume snapshot was available.",
		})
		return
	end

	MP.CONNECTION_SESSION.clear_local_lobby_session({
		clear_reconnect = true,
		refresh_status = true,
	})
end

function connection_flow.handle_reconnecting()
	local reconnect_token, last_lobby_code = MP.CONNECTION_SESSION.get_reconnect_lobby_state()
	local timeout = 120

	if reconnect_token and last_lobby_code and not MP.CONNECTION_FEEDBACK.has_self_reconnect_countdown() then
		trace_runtime_event("connection.reconnecting", {
			lobby_code = last_lobby_code,
			timeout = timeout,
		})
		MP.MATCH_LIFECYCLE.capture_resume_snapshot()
		MP.CONNECTION_SESSION.set_client_connected(false)
		MP.CONNECTION_FEEDBACK.begin_self_reconnect(timeout)
	end
end

MP.NETWORKING_INTERNAL.handle_connected = connection_flow.handle_connected
MP.NETWORKING_INTERNAL.handle_joined_lobby = connection_flow.handle_joined_lobby
MP.NETWORKING_INTERNAL.handle_rejoined_lobby = connection_flow.handle_rejoined_lobby
MP.NETWORKING_INTERNAL.handle_keep_alive = connection_flow.handle_keep_alive
MP.NETWORKING_INTERNAL.handle_enemy_disconnected = connection_flow.handle_enemy_disconnected
MP.NETWORKING_INTERNAL.handle_enemy_reconnected = connection_flow.handle_enemy_reconnected
MP.NETWORKING_INTERNAL.handle_error = connection_flow.handle_error
MP.NETWORKING_INTERNAL.handle_kicked_from_lobby = connection_flow.handle_kicked_from_lobby
MP.NETWORKING_INTERNAL.handle_disconnected = connection_flow.handle_disconnected
MP.NETWORKING_INTERNAL.handle_reconnecting = connection_flow.handle_reconnecting
