local has_required_methods = MP.UTILS.has_required_methods

local LOBBY_MENU_RUNTIME_METHODS = {
	"get_lobby_main_menu_ui",
	"display_lobby_main_menu_ui",
	"refresh_lobby_main_menu",
	"set_main_menu_ui",
	"update_game_runtime",
	"update_after_game",
	"update_connection_status",
}

local loaded = MP.PLATFORM.SMODS.load_mod_file("multiplayer/runtime/lobby_menu_runtime.lua", { required = true })
if loaded == nil then
	return nil
end
local lobby_menu_runtime = has_required_methods(loaded, LOBBY_MENU_RUNTIME_METHODS) and loaded or nil

if not lobby_menu_runtime then
	sendWarnMessage("Multiplayer lobby menu runtime service is missing.", "MULTIPLAYER")
	return nil
end

G.FUNCS.get_lobby_main_menu_UI = lobby_menu_runtime.get_lobby_main_menu_ui
G.FUNCS.display_lobby_main_menu_UI = lobby_menu_runtime.display_lobby_main_menu_ui

function MP.refresh_lobby_main_menu()
	return lobby_menu_runtime.refresh_lobby_main_menu()
end

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

function MP.UI.update_connection_status()
	return lobby_menu_runtime.update_connection_status()
end

MP.HOOKS.register_method_hook(Game, "Game", "main_menu", "mp.ui.lobby_menu_connection_status", {
	after = function(ctx)
		lobby_menu_runtime.update_connection_status()
		ctx.results = { n = 0 }
	end,
})
