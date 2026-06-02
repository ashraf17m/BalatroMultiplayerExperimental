local load_required_service = MP.UTILS.load_required_service

local LOBBY_MENU_RUNTIME_METHODS = {
	"get_lobby_main_menu_ui",
	"display_lobby_main_menu_ui",
	"refresh_lobby_main_menu",
	"set_main_menu_ui",
	"update_game_runtime",
	"update_after_game",
	"update_connection_status",
}

local lobby_menu_runtime = load_required_service(
	"multiplayer/ui/lobby_menu_runtime.lua",
	LOBBY_MENU_RUNTIME_METHODS,
	"Multiplayer lobby menu runtime service is missing."
)
if not lobby_menu_runtime then
	return nil
end

G.FUNCS.get_lobby_main_menu_UI = lobby_menu_runtime.get_lobby_main_menu_ui
G.FUNCS.display_lobby_main_menu_UI = lobby_menu_runtime.display_lobby_main_menu_ui

MP.UI.refresh_lobby_main_menu = lobby_menu_runtime.refresh_lobby_main_menu

local set_main_menu_UI_ref = set_main_menu_UI
---@diagnostic disable-next-line: lowercase-global
function set_main_menu_UI()
	return lobby_menu_runtime.set_main_menu_ui(set_main_menu_UI_ref)
end

MP.GAME_UPDATE_CYCLE.register_before("mp.ui.lobby_runtime", function(ctx, self)
	return lobby_menu_runtime.update_game_runtime(self)
end, 10)

MP.GAME_UPDATE_CYCLE.register_after("mp.ui.lobby_runtime", function()
	return lobby_menu_runtime.update_after_game()
end, 30)

MP.UI.update_connection_status = lobby_menu_runtime.update_connection_status

MP.HOOKS.register_method_hook(Game, "Game", "main_menu", "mp.ui.lobby_menu_connection_status", {
	after = function(ctx)
		lobby_menu_runtime.update_connection_status()
		ctx.results = { n = 0 }
	end,
})
