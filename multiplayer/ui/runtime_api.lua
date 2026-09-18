MP = MP or {}
MP.UI = MP.UI or {}
MP.UTILS = MP.UTILS or {}

local ui_api = MP.UI
local load_required_service = MP.UTILS.load_required_service
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local ui_state_store = {}

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
	if (G and G.OVERLAY_MENU) then
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
		hud_is_standings = false,
		ui_signature = nil,
		ui_mode = nil,
		ui_major = nil,
		ffa_standings = {
			scroll_index = 1,
		},
		full_standings_page = 1,
		full_standings_page_count = 1,
		teams_standings = {
			scroll_index = 1,
		},
		full_teams_standings_page = 1,
		full_teams_standings_page_count = 1,
	}
	return runtime.player_list
end

local state_store_api_methods = {
	"get_runtime_store",
	"get_lobby_overlay_runtime",
	"get_match_lobby_info_runtime",
	"get_lobby_session_runtime",
	"close_active_overlay_menu",
	"get_player_list_runtime",
}

local refresh_api_methods = {
	"get_refresh_runtime",
	"request_connection_status_refresh",
	"request_main_menu_multiplayer_buttons_refresh",
	"request_overlay_menu_close",
	"request_lobby_main_menu_refresh",
	"request_pending_lobby_overlay_refresh",
	"request_group_options_overlay_refresh",
	"request_lobby_option_failure",
	"request_pending_match_lobby_info_refresh",
	"request_shared_score_refresh",
	"request_player_list_refresh",
	"flush_requested_refreshes",
}

local function bind_ui_api_methods(source, method_names)
	for _, method_name in ipairs(method_names) do
		ui_api[method_name] = function(...)
			return source[method_name](...)
		end
	end
end

bind_ui_api_methods(ui_state_store, state_store_api_methods)

if load_required_service then
	local ui_refresh = load_required_service(
		"multiplayer/runtime/ui_refresh_queue.lua",
		refresh_api_methods,
		"Multiplayer UI refresh runtime service is missing."
	)
	if ui_refresh then
		bind_ui_api_methods(ui_refresh, refresh_api_methods)
	end
end

function ui_api.add_nemesis_info(info_queue)
	if not info_queue or not MP or not MP.LOBBY or not MP.LOBBY.code then
		return
	end

	local opponents = MP.OPPONENTS or {}
	local opponent = opponents.get_nemesis_lobby_player and opponents.get_nemesis_lobby_player() or nil
	info_queue[#info_queue + 1] = {
		set = "Other",
		key = "current_nemesis",
		vars = { (opponent and opponent.username) or "Unknown" },
	}
end

function ui_api.refresh_active_pvp_player_list()
	if
		MP.is_pvp_boss
		and MP.is_pvp_boss()
		and ui_api.refresh_player_list
	then
		ui_api.refresh_player_list()
		return true
	end

	return false
end

MP.UTILS.add_nemesis_info = ui_api.add_nemesis_info
