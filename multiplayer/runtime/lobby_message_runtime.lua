MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}

local lobby_message_runtime = {}
local load_required_service = MP.UTILS.load_required_service

local function get_lobby_domain()
	return MP.DOMAIN and MP.DOMAIN.LOBBY or {}
end

local function get_main_menu_play_ui()
	return MP.UI and MP.UI.MAIN_MENU_PLAY or {}
end

local function ensure_state_apply_runtime(required_method)
	return load_required_service(
		"multiplayer/runtime/network_state_apply.lua",
		required_method,
		"Multiplayer state apply runtime service is missing.",
		function()
			return MP.STATE_APPLY
		end
	)
end

local function apply_state_update(method_name, ...)
	local state_apply = ensure_state_apply_runtime(method_name)
	local method = state_apply and state_apply[method_name] or nil
	if method then
		return method(...)
	end

	return nil
end

function lobby_message_runtime.handle_lobby_info(players, is_host, is_in_game, lobby_type, is_coop_save_restore)
	apply_state_update("lobby_info", players, is_host, is_in_game, lobby_type, is_coop_save_restore)
end

function lobby_message_runtime.handle_lobby_list(lobbies)
	local lobby_domain = get_lobby_domain()
	if lobby_domain.set_browser_pending then
		lobby_domain.set_browser_pending(false)
	end
	if lobby_domain.set_browser_lobbies then
		lobby_domain.set_browser_lobbies(lobbies)
	end

	local main_menu_play_ui = get_main_menu_play_ui()
	if main_menu_play_ui.refresh_browse_lobbies_overlay then
		main_menu_play_ui.refresh_browse_lobbies_overlay()
	end
end

function lobby_message_runtime.handle_lobby_join_request_received(request)
	local lobby_domain = get_lobby_domain()
	if lobby_domain.store_join_request then
		lobby_domain.store_join_request(request)
	end

	local main_menu_play_ui = get_main_menu_play_ui()
	if main_menu_play_ui.open_join_request_notification then
		main_menu_play_ui.open_join_request_notification(request)
		return
	end

	if MP.UI and MP.UI.UTILS and MP.UI.UTILS.overlay_message then
		MP.UI.UTILS.overlay_message(tostring(request and request.username or "A player") .. " wants to join.")
	end
end

function lobby_message_runtime.handle_lobby_join_request_pending(code, request_id, expires_at, expires_in_ms)
	local lobby_domain = get_lobby_domain()
	if lobby_domain.set_setup_temp_code then
		lobby_domain.set_setup_temp_code(code or "")
	end
	if lobby_domain.set_pending_join_request and request_id then
		lobby_domain.set_pending_join_request({
			code = code,
			requestId = request_id,
			expiresAt = expires_at,
			expiresInMs = expires_in_ms,
		})
	end

	local main_menu_play_ui = get_main_menu_play_ui()
	if MP.UI and MP.UI.refresh_main_menu_multiplayer_buttons then
		MP.UI.refresh_main_menu_multiplayer_buttons()
	end
	if main_menu_play_ui.refresh_browse_lobbies_overlay then
		main_menu_play_ui.refresh_browse_lobbies_overlay()
	end
end

function lobby_message_runtime.handle_lobby_join_request_rejected(code, message, request_id, reason)
	local lobby_domain = get_lobby_domain()
	if lobby_domain.set_setup_temp_code then
		lobby_domain.set_setup_temp_code(code or "")
	end
	if lobby_domain.clear_pending_join_request then
		lobby_domain.clear_pending_join_request(request_id)
	end

	local main_menu_play_ui = get_main_menu_play_ui()
	if MP.UI and MP.UI.refresh_main_menu_multiplayer_buttons then
		MP.UI.refresh_main_menu_multiplayer_buttons()
	end
	if main_menu_play_ui.refresh_browse_lobbies_overlay then
		main_menu_play_ui.refresh_browse_lobbies_overlay()
	end

	if reason ~= "expired" and reason ~= "cancelled" and MP.UI and MP.UI.UTILS and MP.UI.UTILS.overlay_message then
		MP.UI.UTILS.overlay_message(message or localize("k_join_request_denied"))
	end
end

function lobby_message_runtime.handle_lobby_join_request_closed(code, request_id, reason)
	local lobby_domain = get_lobby_domain()
	if lobby_domain.remove_join_request then
		lobby_domain.remove_join_request(request_id)
	end

	local main_menu_play_ui = get_main_menu_play_ui()
	if main_menu_play_ui.close_join_request_notification then
		local closed_notification = main_menu_play_ui.close_join_request_notification(request_id)
		if not closed_notification and main_menu_play_ui.show_next_join_request_notification then
			main_menu_play_ui.show_next_join_request_notification()
		end
	end
end

function lobby_message_runtime.handle_lobby_player_joined(player)
	apply_state_update("lobby_player_joined", player)
end

function lobby_message_runtime.handle_lobby_player_updated(player)
	apply_state_update("lobby_player_updated", player)
end

function lobby_message_runtime.handle_lobby_player_left(player_id, is_host, owner_player_id, assignments)
	apply_state_update("lobby_player_left", player_id, is_host, owner_player_id, assignments)
end

function lobby_message_runtime.handle_lobby_type_changed(lobby_type, players)
	apply_state_update("lobby_type_changed", lobby_type, players)
end

function lobby_message_runtime.handle_lobby_player_team(player_id, team_id)
	apply_state_update("lobby_player_team", player_id, team_id)
end

function lobby_message_runtime.handle_lobby_nemesis_assignments(assignments)
	apply_state_update("lobby_nemesis_assignments", assignments)
end

function lobby_message_runtime.handle_lobby_options(message)
	local lobby_session = load_required_service(
		"multiplayer/runtime/session_runtime.lua",
		"apply_lobby_options",
		"Multiplayer lobby session runtime service is missing.",
		function()
			return MP.LOBBY_SESSION
		end
	)
	if not (lobby_session and lobby_session.apply_lobby_options) then
		return
	end

	local options = MP.LOBBY_WIRE.extract_lobby_option_payload(message)
	local applied, result = lobby_session.apply_lobby_options(options)
	if not applied and lobby_session.handle_lobby_option_failure then
		lobby_session.handle_lobby_option_failure(result)
	end
end

MP.NETWORKING_INTERNAL.handle_lobby_info = lobby_message_runtime.handle_lobby_info
MP.NETWORKING_INTERNAL.handle_lobby_list = lobby_message_runtime.handle_lobby_list
MP.NETWORKING_INTERNAL.handle_lobby_join_request_received = lobby_message_runtime.handle_lobby_join_request_received
MP.NETWORKING_INTERNAL.handle_lobby_join_request_pending = lobby_message_runtime.handle_lobby_join_request_pending
MP.NETWORKING_INTERNAL.handle_lobby_join_request_rejected = lobby_message_runtime.handle_lobby_join_request_rejected
MP.NETWORKING_INTERNAL.handle_lobby_join_request_closed = lobby_message_runtime.handle_lobby_join_request_closed
MP.NETWORKING_INTERNAL.handle_lobby_player_joined = lobby_message_runtime.handle_lobby_player_joined
MP.NETWORKING_INTERNAL.handle_lobby_player_updated = lobby_message_runtime.handle_lobby_player_updated
MP.NETWORKING_INTERNAL.handle_lobby_player_left = lobby_message_runtime.handle_lobby_player_left
MP.NETWORKING_INTERNAL.handle_lobby_type_changed = lobby_message_runtime.handle_lobby_type_changed
MP.NETWORKING_INTERNAL.handle_lobby_player_team = lobby_message_runtime.handle_lobby_player_team
MP.NETWORKING_INTERNAL.handle_lobby_nemesis_assignments = lobby_message_runtime.handle_lobby_nemesis_assignments
MP.NETWORKING_INTERNAL.handle_lobby_options = lobby_message_runtime.handle_lobby_options
