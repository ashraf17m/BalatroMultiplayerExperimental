MP.UI = MP.UI or {}

local ui_api = MP.UI
local has_required_methods = MP.UTILS.has_required_methods

local END_GAME_VIEW_METHODS = {
	"get_end_game_view_runtime",
	"reset_end_game_view_runtime",
	"get_viewable_players",
	"get_end_game_standings_participants",
	"capture_end_game_view_players",
	"get_view_target_state",
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

local loaded = MP.PLATFORM.SMODS.load_mod_file("multiplayer/runtime/end_game_view_runtime.lua", { required = true })
if loaded == nil then
	return nil
end
local end_game_view_runtime = has_required_methods(loaded, END_GAME_VIEW_METHODS) and loaded or nil

if not end_game_view_runtime then
	sendWarnMessage("Multiplayer end-game view runtime service is missing.", "MULTIPLAYER")
	return nil
end

for _, method_name in ipairs(END_GAME_VIEW_METHODS) do
	local name = method_name
	ui_api[name] = function(...)
		return end_game_view_runtime[name](...)
	end
end
