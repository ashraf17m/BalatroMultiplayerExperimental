MP.ACTIONS = MP.ACTIONS or {}
MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}
MP.CONNECTION_FEEDBACK = MP.CONNECTION_FEEDBACK or {}
MP.CONNECTION_RESUME = MP.CONNECTION_RESUME or {}

local connection_flow = {}
local connection_action_runtime = {}
local connection_feedback = MP.CONNECTION_FEEDBACK
local connection_resume = MP.CONNECTION_RESUME
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}

-- ============================================================================
-- 1. Connection Feedback & Toasts (from connection_feedback.lua)
-- ============================================================================
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

local function uses_group_disconnect_notice()
	return (MP.is_ffa_mode and MP.is_ffa_mode())
		or (MP.is_duels_mode and MP.is_duels_mode())
		or (MP.is_teams_mode and MP.is_teams_mode())
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

	if not uses_group_disconnect_notice() then
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
	if player_id and player_id == ((G and G.MP_ID or nil)) then
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

	if not uses_group_disconnect_notice() then
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

-- ============================================================================
-- 2. Connection Resume Flow (from connection_resume.lua)
-- ============================================================================
local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end
local build_traceback = MP.UTILS.build_traceback

local function call_resume_method(method_name, ...)
	local method = MP.RESUME and MP.RESUME[method_name] or nil
	if method then
		return method(...)
	end

	return nil
end

for _, method_name in ipairs({
	"get_pending_manual_resume",
	"complete_manual_resume",
	"activate_runtime_match_sync_buffer",
	"fail_manual_resume",
	"refresh_saved_resume_metadata",
}) do
	local name = method_name
	connection_resume[method_name] = function(...)
		return call_resume_method(name, ...)
	end
end

local function build_resume_restore_traceback(step, err)
	local summary = string.format("Resume restore failed at step '%s': %s", tostring(step), tostring(err))
	return build_traceback(summary)
end

local function summarize_resume_restore_error(err)
	local error_text = tostring(err or "Unknown resume restore error.")
	local first_line = string.match(error_text, "([^\r\n]+)") or error_text

	local nested_summary = string.match(first_line, "Resume runtime failed at step '[^']+': .+$")
	if nested_summary then
		return nested_summary
	end

	return first_line
end

function connection_resume.resume_saved_match(pending_resume, code, token, player_id)
	trace_runtime_event("resume.restore_begin", {
		code = code,
		player_id = player_id,
		has_run_snapshot = pending_resume and pending_resume.run_snapshot ~= nil,
		has_meta_state = pending_resume and pending_resume.meta and pending_resume.meta.mp_state ~= nil,
	})
	local current_step = "refresh resume metadata"
	local ok, err = xpcall(function()
		if not connection_resume.refresh_saved_resume_metadata(token, code, player_id) then
			trace_runtime_event("resume.metadata_refresh_failed", {
				code = code,
				player_id = player_id,
			})
			sendWarnMessage("Failed to refresh saved resume metadata before restoring match.", "MULTIPLAYER")
		end
		current_step = "run resume bootstrap"
		if not (MP.NETWORKING_INTERNAL and MP.NETWORKING_INTERNAL.resume_match_runtime) then
			error("Missing multiplayer resume runtime handler.")
		end
		MP.NETWORKING_INTERNAL.resume_match_runtime(pending_resume.run_snapshot, pending_resume.meta and pending_resume.meta.mp_state)
	end, function(restore_err)
		return build_resume_restore_traceback(current_step, restore_err)
	end)

	if not ok then
		local concise_error = summarize_resume_restore_error(err)
		trace_runtime_event("resume.restore_failed", {
			code = code,
			step = current_step,
			error = concise_error,
		})
		connection_resume.fail_manual_resume(true)
		MP.CONNECTION_FEEDBACK.show_resume_restore_failed(concise_error, err)
		return false
	end

	connection_resume.complete_manual_resume()
	trace_runtime_event("resume.restore_complete", {
		code = code,
		player_id = player_id,
	})
	return true
end

-- ============================================================================
-- 3. Outgoing Connection Actions (from connection_action_runtime.lua)
-- ============================================================================
local connection_action_runtime = {}
local cached_connection_identity = nil
local load_required_service = MP.UTILS.load_required_service

local CONNECTION_IDENTITY_METHODS = {
	"set_username",
	"set_blind_col",
	"sync_blind_target_scale",
}

local function send_payload(payload)
	if payload then
		Client.send(payload)
	end
end

local function ensure_connection_identity()
	if cached_connection_identity then
		return cached_connection_identity
	end

	if MP.CONNECTION_IDENTITY and MP.CONNECTION_IDENTITY.set_username then
		cached_connection_identity = MP.CONNECTION_IDENTITY
		return cached_connection_identity
	end

	cached_connection_identity = load_required_service(
		"multiplayer/runtime/session_runtime.lua",
		CONNECTION_IDENTITY_METHODS,
		"Multiplayer network client identity service is missing.",
		function()
			return MP.CONNECTION_IDENTITY
		end
	)
	return cached_connection_identity
end

local function get_identity_payload_values()
	local client = MP.LOBBY and MP.LOBBY.client or {}
	return client.username, client.blind_col, MP.MOD_STRING, client.blind_target_scale
end

function connection_action_runtime.connect()
	send_payload(MP.CONNECTION_WIRE.build_connect_payload())
end

function connection_action_runtime.send_identity()
	local username, blind_col, mod_hash, blind_target_scale = get_identity_payload_values()
	send_payload(MP.CONNECTION_WIRE.build_identity_payload(username, blind_col, mod_hash, blind_target_scale))
end

function connection_action_runtime.send_rejoin(code, reconnect_token)
	send_payload(MP.CONNECTION_WIRE.build_rejoin_payload(code, reconnect_token))
end

function connection_action_runtime.send_keep_alive_ack()
	send_payload(MP.CONNECTION_WIRE.build_keep_alive_ack_payload())
end

function connection_action_runtime.set_username(username)
	if not ensure_connection_identity() then
		return nil
	end

	return MP.CONNECTION_IDENTITY.set_username(username)
end

function connection_action_runtime.set_blind_col(num)
	if not ensure_connection_identity() then
		return nil
	end

	return MP.CONNECTION_IDENTITY.set_blind_col(num)
end

function connection_action_runtime.sync_blind_target_scale(scale)
	if not ensure_connection_identity() then
		return nil
	end

	return MP.CONNECTION_IDENTITY.sync_blind_target_scale(scale)
end

MP.ACTIONS.connect = connection_action_runtime.connect
MP.ACTIONS.set_username = connection_action_runtime.set_username
MP.ACTIONS.set_blind_col = connection_action_runtime.set_blind_col
MP.ACTIONS.sync_blind_target_scale = connection_action_runtime.sync_blind_target_scale

MP.NETWORKING_INTERNAL.send_connection_identity = connection_action_runtime.send_identity
MP.NETWORKING_INTERNAL.send_connection_rejoin = connection_action_runtime.send_rejoin
MP.NETWORKING_INTERNAL.send_keep_alive_ack = connection_action_runtime.send_keep_alive_ack

-- ============================================================================
-- 4. Connection Flow & Handshake Handlers (from connection_flow.lua)
-- ============================================================================
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
	if BALATRO and (G and G.OVERLAY_MENU) then
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
			if not ((G and G.MAIN_MENU_UI or nil)) then
				return
			end

			show_notice_after_ui_settles(message)
			return true
		end,
	})
end

local function transition_to_main_menu_with_notice(message)
	request_overlay_close_if_open()

	local root = G or nil
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

	local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY or nil
	if lobby_domain and lobby_domain.clear_pending_join_request then
		lobby_domain.clear_pending_join_request()
	end
	MP.CONNECTION_RESUME.complete_manual_resume()
	apply_server_lobby_entry_state(code, gamemode_key, lobby_type, token or reconnect_token, player_id, options, players, is_host, is_in_game, is_coop_save_restore)
	MP.CONNECTION_SESSION.request_overlay_menu_close()
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

return connection_flow
