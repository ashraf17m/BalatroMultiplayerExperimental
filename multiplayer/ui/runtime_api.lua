MP.UI = MP.UI or {}

local ui_api = MP.UI
local load_required_service = MP.UTILS.load_required_service

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

local ui_state_store = load_required_service(
	"multiplayer/ui/ui_state_store.lua",
	state_store_api_methods,
	"Multiplayer UI state runtime service is missing."
)
if not ui_state_store then
	return nil
end

local ui_refresh = load_required_service(
	"multiplayer/runtime/ui_refresh_queue.lua",
	refresh_api_methods,
	"Multiplayer UI refresh runtime service is missing."
)
if not ui_refresh then
	return nil
end

bind_ui_api_methods(ui_state_store, state_store_api_methods)
bind_ui_api_methods(ui_refresh, refresh_api_methods)

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
