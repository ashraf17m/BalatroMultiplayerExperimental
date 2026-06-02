local ui_state_store = {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

function ui_state_store.get_runtime_store()
	MP.UI.RUNTIME = MP.UI.RUNTIME or {}
	return MP.UI.RUNTIME
end

function ui_state_store.get_lobby_overlay_runtime()
	local runtime = ui_state_store.get_runtime_store()
	runtime.lobby_overlay = runtime.lobby_overlay or {
		pending_surface = nil,
		active_surface = nil,
		active_team_picker_player_id = nil,
		suppress_next_team_picker_refresh = nil,
	}
	return runtime.lobby_overlay
end

function ui_state_store.get_match_lobby_info_runtime()
	local runtime = ui_state_store.get_runtime_store()
	runtime.match_lobby_info = runtime.match_lobby_info or {
		pending_refresh = false,
		active = false,
		players_page = 1,
	}
	return runtime.match_lobby_info
end

function ui_state_store.get_lobby_session_runtime()
	local runtime = ui_state_store.get_runtime_store()
	runtime.lobby_session = runtime.lobby_session or {
		pending_option_failure_message = nil,
	}
	return runtime.lobby_session
end

function ui_state_store.close_active_overlay_menu()
	if BALATRO.get_overlay_menu and BALATRO.get_overlay_menu() then
		return not not (BALATRO.exit_overlay_menu and BALATRO.exit_overlay_menu())
	end

	return false
end

function ui_state_store.get_player_list_runtime()
	local runtime = ui_state_store.get_runtime_store()
	runtime.player_list = runtime.player_list or {
		ui = nil,
		ui_boxes = nil,
		saved_theme = nil,
		ui_signature = nil,
		ui_mode = nil,
		ui_major = nil,
		ffa_standings = {
			scroll_index = 1,
		},
	}
	return runtime.player_list
end

return ui_state_store
