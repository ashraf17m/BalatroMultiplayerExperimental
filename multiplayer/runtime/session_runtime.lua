local session_runtime = {}
MP.CONNECTION_SESSION = MP.CONNECTION_SESSION or {}
MP.LOBBY_SESSION = MP.LOBBY_SESSION or {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY or {}
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}

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
	call_action_if_present(MP.UI, "request_connection_status_refresh")
end

function connection_session.request_overlay_menu_close()
	call_action_if_present(MP.UI, "request_overlay_menu_close")
end

function connection_session.request_lobby_main_menu_refresh()
	call_action_if_present(MP.UI, "request_lobby_main_menu_refresh")
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
	local connected = lobby_domain.set_client_connected and lobby_domain.set_client_connected(is_connected)
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
	if match_domain.reset_state then
		match_domain.reset_state()
	end
	connection_session.refresh_connection_status_ui()
	return true
end

function connection_session.clear_local_lobby_session(opts)
	local options = opts or {}
	local rebuilt_main_menu_shell = false

	if lobby_domain.clear_session then
		lobby_domain.clear_session()
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
	if lobby_domain.reset_config then
		lobby_domain.reset_config(false, lobby_type)
	end

	if lobby_domain.begin_session then
		lobby_domain.begin_session({
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
	local applied, result = lobby_domain.apply_option_update(options)
	if not applied then
		return false, result
	end

	if MP.UI and MP.UI.refresh_lobby_options_tab then
		MP.UI.refresh_lobby_options_tab(options)
	end
	if
		MP.UI
		and MP.UI.request_group_options_overlay_refresh
		and MP.UI.should_refresh_group_options_for_lobby_options
		and MP.UI.should_refresh_group_options_for_lobby_options(options)
	then
		MP.UI.request_group_options_overlay_refresh()
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

function lobby_session.apply_initial_lobby_snapshot(options, players, is_host, is_in_game, is_coop_save_restore)
	if type(options) == "table" then
		local applied, result = lobby_session.apply_lobby_options(options)
		if not applied then
			return false, result
		end
	end

	if type(players) == "table" then
		MP.STATE_APPLY.lobby_info(players, is_host, is_in_game, nil, is_coop_save_restore)
	end

	return true
end

return session_runtime
