local session_runtime = {}
MP.CONNECTION_SESSION = MP.CONNECTION_SESSION or {}
MP.LOBBY_SESSION = MP.LOBBY_SESSION or {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

session_runtime.CONNECTION = MP.CONNECTION_SESSION
session_runtime.LOBBY = MP.LOBBY_SESSION

local connection_session = session_runtime.CONNECTION
local lobby_session = session_runtime.LOBBY

local function call_action_if_present(owner, action_name)
	local action = owner and owner[action_name]
	if not action then
		return false
	end
	action()
	return true
end

local function get_runtime_state()
	session_runtime.state = session_runtime.state or {
		reconnect_token = nil,
		reconnect_lobby_code = nil,
	}
	return session_runtime.state
end

local function set_reconnect_lobby_state_fields(token, code)
	local state = get_runtime_state()
	state.reconnect_token = token
	state.reconnect_lobby_code = code
	return state
end

function connection_session.refresh_connection_status_ui()
	if call_action_if_present(MP.UI, "request_connection_status_refresh") then
		return
	end
	call_action_if_present(MP.UI, "update_connection_status")
end

function connection_session.request_overlay_menu_close()
	if call_action_if_present(MP.UI, "request_overlay_menu_close") then
		return
	end
	call_action_if_present(MP.UI, "close_active_overlay_menu")
end

function connection_session.request_lobby_main_menu_refresh()
	if call_action_if_present(MP.UI, "request_lobby_main_menu_refresh") then
		return
	end
	call_action_if_present(MP, "refresh_lobby_main_menu")
end

local function request_lobby_option_failure(message)
	if not message then
		return false
	end

	local runtime = MP.UI and MP.UI.get_lobby_session_runtime and MP.UI.get_lobby_session_runtime() or nil
	if runtime then
		runtime.pending_option_failure_message = message
	end

	if call_action_if_present(MP.UI, "request_lobby_option_failure") then
		return true
	end

	return false
end

local function get_lobby_option_failure_reason(result)
	if result and result.type == "ruleset_not_found" then
		return localize("k_ruleset_not_found")
	end

	return result and result.reason or "Unknown failure"
end

function connection_session.get_reconnect_lobby_state()
	local state = get_runtime_state()
	return state.reconnect_token, state.reconnect_lobby_code
end

function connection_session.set_reconnect_lobby_state(token, code)
	local state = set_reconnect_lobby_state_fields(token, code)
	return state.reconnect_token, state.reconnect_lobby_code
end

function connection_session.clear_reconnect_lobby_state()
	set_reconnect_lobby_state_fields(nil, nil)
end

function connection_session.set_client_connected(is_connected)
	local connected = MP.set_lobby_client_connected and MP.set_lobby_client_connected(is_connected)
		or not not is_connected
	connection_session.refresh_connection_status_ui()
	return connected
end

function connection_session.rebuild_normal_main_menu_shell()
	if not (BALATRO.is_main_menu_stage and BALATRO.is_main_menu_stage()) then
		return false
	end

	local main_menu_ui = BALATRO.get_main_menu_ui and BALATRO.get_main_menu_ui() or nil
	if not (main_menu_ui and main_menu_ui.is_mp_lobby_menu) then
		return false
	end

	if not BALATRO.go_to_menu then
		return false
	end

	BALATRO.go_to_menu()
	if MP.reset_game_states then
		MP.reset_game_states()
	end
	connection_session.refresh_connection_status_ui()
	return true
end

function connection_session.clear_local_lobby_session(opts)
	local options = opts or {}
	local rebuilt_main_menu_shell = false

	if MP.clear_lobby_session then
		MP.clear_lobby_session()
	end
	if options.clear_reconnect then
		connection_session.clear_reconnect_lobby_state()
	end
	if options.rebuild_main_menu_shell ~= false then
		rebuilt_main_menu_shell = connection_session.rebuild_normal_main_menu_shell()
	end
	if options.clear_feedback and MP.CONNECTION_FEEDBACK and MP.CONNECTION_FEEDBACK.clear_all_countdowns then
		MP.CONNECTION_FEEDBACK.clear_all_countdowns()
	elseif options.clear_self_reconnect and MP.CONNECTION_FEEDBACK and MP.CONNECTION_FEEDBACK.clear_self_reconnect_countdown then
		MP.CONNECTION_FEEDBACK.clear_self_reconnect_countdown()
	end
	if not rebuilt_main_menu_shell and options.refresh_status ~= false then
		connection_session.refresh_connection_status_ui()
	end

	return {
		rebuilt_main_menu_shell = rebuilt_main_menu_shell,
	}
end

function lobby_session.apply_joined_lobby_state(code, gamemode_key, lobby_type, player_id)
	if MP.reset_lobby_config then
		MP.reset_lobby_config(false, lobby_type)
	end

	if MP.begin_lobby_session then
		MP.begin_lobby_session({
			code = code,
			gamemode = gamemode_key,
			lobby_type = lobby_type,
			player_id = player_id,
			is_host = false,
			match_in_progress = false,
			players = {},
		})
	end

	if MP.ACTIONS and MP.ACTIONS.sync_client then
		MP.ACTIONS.sync_client()
	end
	connection_session.refresh_connection_status_ui()
end

function lobby_session.apply_lobby_options(options)
	local applied, result = MP.apply_lobby_option_update(options)
	if not applied then
		return false, result
	end

	if MP.sync_lobby_run_deck_from_config then
		MP.sync_lobby_run_deck_from_config()
	end
	if MP.UI and MP.UI.refresh_lobby_options_tab then
		MP.UI.refresh_lobby_options_tab(options)
	end
	connection_session.request_lobby_main_menu_refresh()

	return true, result
end

function lobby_session.handle_lobby_option_failure(result)
	local failure_reason = get_lobby_option_failure_reason(result)
	local failure_message = localize({
		type = "variable",
		key = "k_failed_to_join_lobby",
		vars = { failure_reason },
	})

	request_lobby_option_failure(failure_message)
end

function lobby_session.apply_initial_lobby_snapshot(options, players, is_host, is_in_game)
	if type(options) == "table" then
		local applied, result = lobby_session.apply_lobby_options(options)
		if not applied then
			return false, result
		end
	end

	if type(players) == "table" then
		MP.STATE_APPLY.lobby_info(players, is_host, is_in_game)
	end

	return true
end

return session_runtime
