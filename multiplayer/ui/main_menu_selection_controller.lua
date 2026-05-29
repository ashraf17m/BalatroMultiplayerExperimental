MP.UI = MP.UI or {}
MP.UI.MAIN_MENU_SELECTION = MP.UI.MAIN_MENU_SELECTION or {}

local selection = MP.UI.MAIN_MENU_SELECTION

local function rebuild_selection_tabs(tab_wrap, definition)
	MP.UI.UTILS.replace_config_object(tab_wrap, UIBox({
		definition = definition,
		config = { align = "cm", parent = tab_wrap },
	}), {
		recalculate_target = tab_wrap.UIBox,
	})
end

local function switch_selection_tabs(args, active_tab_id, subject_key, preview_setter, is_ruleset)
	if not args or not args.cycle_config then
		return
	end

	local callback_args = args.cycle_config.opt_args
	local tabs_object = callback_args.ui
	local tabs_wrap = tabs_object.parent
	local active_tab = tabs_wrap.UIBox:get_UIE_by_ID(active_tab_id)
	local active_tab_idx = active_tab and active_tab.config.tab_idx or 1
	local tab_type = (args.to_key == 2 and "banned") or (args.to_key == 3 and "rework") or "info"
	local definition = G.UIDEF.lobby_setup_tabs_definition(
		callback_args[subject_key],
		tab_type,
		active_tab_idx,
		is_ruleset
	)

	tabs_object.config.tab_type = tab_type
	if preview_setter then
		preview_setter(tab_type == "rework")
	end

	rebuild_selection_tabs(tabs_wrap, definition)
end

function G.FUNCS.change_gamemode_selection(e)
	local default_gamemode_key = MP.get_lobby_creation_gamemode and MP.get_lobby_creation_gamemode()
		or MP.DEFAULT_LOBBY_CREATION_GAMEMODE
	local default_button = MP.get_gamemode_selection_button_id
		and MP.get_gamemode_selection_button_id(default_gamemode_key)
		or "attrition_gamemode_button"

	MP.UI.Change_Main_Lobby_Options(
		e,
		"gamemode_area",
		G.UIDEF.gamemode_info,
		default_button,
		function(gamemode_name)
			MP.set_lobby_creation_gamemode("gamemode_mp_" .. gamemode_name)
		end
	)
end

function G.FUNCS.gamemode_switch_tabs(args)
	switch_selection_tabs(args, "gamemode_active_tab", "gamemode", MP.set_lobby_setup_gamemode_preview, false)
end

function G.FUNCS.change_ruleset_selection(e)
	local mode = selection.get_ruleset_selection_mode and selection.get_ruleset_selection_mode()
		or MP.UI.ruleset_selection_mode
		or "mp"

	if e.config.id == "weekly_ruleset_button" and G.FUNCS.weekly_interrupt(e) then
		return
	end

	local default_ruleset_key = mode == "sp"
		and (MP.SP and MP.SP.ruleset or MP.DEFAULT_LOBBY_CREATION_RULESET)
		or (MP.get_lobby_creation_ruleset and MP.get_lobby_creation_ruleset() or MP.DEFAULT_LOBBY_CREATION_RULESET)
	local default_button = MP.get_ruleset_selection_button_id
		and MP.get_ruleset_selection_button_id(default_ruleset_key)
		or "standard_ranked_ruleset_button"

	MP.UI.Change_Main_Lobby_Options(
		e,
		"ruleset_area",
		function(ruleset_name)
			return G.UIDEF.ruleset_info(ruleset_name, mode)
		end,
		default_button,
		function(ruleset_name)
			selection.apply_ruleset_selection(mode, ruleset_name)
		end
	)

	if MP.set_lobby_setup_ruleset_preview then
		MP.set_lobby_setup_ruleset_preview(false)
	end
end

function G.FUNCS.ruleset_switch_tabs(args)
	switch_selection_tabs(args, "ruleset_active_tab", "ruleset", MP.set_lobby_setup_ruleset_preview, true)
end
