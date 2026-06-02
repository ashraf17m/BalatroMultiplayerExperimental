MP.UI = MP.UI or {}

local ui_api = MP.UI
local load_required_service = MP.UTILS.load_required_service

local END_GAME_VIEW_METHODS = {
	"get_end_game_view_runtime",
	"reset_end_game_view_runtime",
	"get_viewable_players",
	"get_end_game_standings_participants",
	"capture_end_game_view_players",
	"get_view_target_state",
	"get_target_jokers_label",
	"get_target_deck_label",
	"get_end_game_view_cache",
	"load_end_game_view_cache",
	"clear_end_game_view_request_error",
	"fail_end_game_view_request",
	"resolve_end_game_view_response_target",
	"apply_end_game_view_response",
	"clear_end_game_target_preview",
	"prefetch_end_game_view_players",
	"request_end_game_view_target",
}

local end_game_view_runtime = load_required_service(
	"multiplayer/runtime/end_game_view_runtime.lua",
	END_GAME_VIEW_METHODS,
	"Multiplayer end-game view runtime service is missing."
)
if not end_game_view_runtime then
	return nil
end

for _, method_name in ipairs(END_GAME_VIEW_METHODS) do
	local name = method_name
	ui_api[name] = function(...)
		return end_game_view_runtime[name](...)
	end
end
