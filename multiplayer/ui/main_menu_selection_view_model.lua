MP.UI = MP.UI or {}
MP.UI.MAIN_MENU_SELECTION = MP.UI.MAIN_MENU_SELECTION or {}

local selection = MP.UI.MAIN_MENU_SELECTION

function G.UIDEF.gamemode_selection_options()
	return selection.build_gamemode_selection_options()
end

function G.UIDEF.gamemode_info(gamemode_name)
	return selection.build_gamemode_info(gamemode_name)
end

function G.UIDEF.gamemode_tabs(gamemode)
	return selection.build_gamemode_tabs(gamemode)
end

function G.UIDEF.ruleset_selection_options(mode)
	return selection.build_ruleset_selection_options(mode)
end

function G.UIDEF.ruleset_info(ruleset_name, mode)
	return selection.build_ruleset_info(ruleset_name, mode)
end

function G.UIDEF.ruleset_tabs(ruleset)
	return selection.build_ruleset_tabs(ruleset)
end

function G.UIDEF.lobby_setup_tabs_definition(ruleset_or_gamemode, tab_type, chosen_tab_idx)
	return selection.build_lobby_setup_tabs_definition(ruleset_or_gamemode, tab_type, chosen_tab_idx)
end

function G.UIDEF.ruleset_cardarea_definition(args)
	return selection.build_ruleset_cardarea_definition(args)
end
