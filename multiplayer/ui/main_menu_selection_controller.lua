MP.UI = MP.UI or {}
MP.UI.MAIN_MENU_SELECTION = MP.UI.MAIN_MENU_SELECTION or {}

local selection = MP.UI.MAIN_MENU_SELECTION
local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY or {}

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
	local default_gamemode_key = lobby_domain.get_creation_gamemode and lobby_domain.get_creation_gamemode()
		or MP.DEFAULT_LOBBY_CREATION_GAMEMODE
	local default_button = selection.get_gamemode_selection_button_id
		and selection.get_gamemode_selection_button_id(default_gamemode_key)
		or "attrition_gamemode_button"

	MP.UI.Change_Main_Lobby_Options(
		e,
		"gamemode_area",
		G.UIDEF.gamemode_info,
		default_button,
		function(gamemode_name)
			lobby_domain.set_creation_gamemode("gamemode_mp_" .. gamemode_name)
			if gamemode_name == "coop" and MP.ACTIONS and MP.ACTIONS.request_coop_saves then
				MP.ACTIONS.request_coop_saves()
			end
		end
	)
end

function G.FUNCS.resume_coop_save(e)
	local save_id = e and e.config and e.config.save_id
	if MP.ACTIONS and MP.ACTIONS.resume_coop_save then
		MP.ACTIONS.resume_coop_save(save_id)
	end
end

function G.FUNCS.delete_coop_save(e)
	local save_id = e and e.config and e.config.save_id
	if not (MP.ACTIONS and MP.ACTIONS.delete_coop_save and save_id) then
		return
	end

	MP.ACTIONS.delete_coop_save(save_id)
end

function G.FUNCS.gamemode_switch_tabs(args)
	switch_selection_tabs(args, "gamemode_active_tab", "gamemode", lobby_domain.set_setup_gamemode_preview, false)
end

local function get_lobby_access_mode_values()
	return selection.LOBBY_ACCESS_MODE_VALUES or { "public", "ask_first", "private" }
end

local function get_lobby_access_mode_index()
	if selection.get_lobby_access_mode_index then
		return selection.get_lobby_access_mode_index()
	end

	local values = get_lobby_access_mode_values()
	local current_mode = lobby_domain.get_creation_access_mode and lobby_domain.get_creation_access_mode() or "private"
	for index, value in ipairs(values) do
		if value == current_mode then
			return index
		end
	end
	return #values
end

local function refresh_lobby_access_mode_cycle_style(index)
	local overlay = G.OVERLAY_MENU
	if not (
		overlay
		and overlay.get_UIE_by_ID
		and selection.get_lobby_access_mode_colour
		and selection.build_lobby_access_mode_tooltip
	) then
		return
	end

	local cycle = overlay:get_UIE_by_ID("lobby_access_mode_tab_cycle")
	if not cycle then
		return
	end

	local colour = selection.get_lobby_access_mode_colour(index)
	for _, child in ipairs(cycle.children or {}) do
		if child.config and (child.config.button == "option_cycle" or child.config.id == "cycle_main") then
			child.config.colour = colour
		end
	end

	local cycle_main = overlay:get_UIE_by_ID("cycle_main", cycle)
	if cycle_main and cycle_main.config then
		cycle_main.config.colour = colour
		cycle_main.config.on_demand_tooltip = {
			text = selection.build_lobby_access_mode_tooltip(index),
		}
		if cycle_main.config.h_popup and cycle_main.stop_hover and cycle_main.hover and G.E_MANAGER then
			cycle_main:stop_hover()
			G.E_MANAGER:add_event(Event({
				func = function()
					cycle_main:hover()
					return true
				end,
			}))
		end
	end
end

function G.FUNCS.change_lobby_access_mode(e)
	local values = get_lobby_access_mode_values()
	if #values == 0 then
		return
	end

	local next_index = e and e.to_key
	if not next_index then
		local direction = tonumber(e and e.config and e.config.direction) or 1
		next_index = get_lobby_access_mode_index() + direction
		if next_index < 1 then
			next_index = #values
		elseif next_index > #values then
			next_index = 1
		end
	end

	local callback_values = e and e.cycle_config and e.cycle_config.mode_values or values
	local access_mode = callback_values[next_index]
	if not access_mode then return end

	if lobby_domain.set_creation_access_mode then
		lobby_domain.set_creation_access_mode(access_mode)
	end
	refresh_lobby_access_mode_cycle_style(next_index)
end

function G.FUNCS.change_ruleset_selection(e)
	if e.config.id == "weekly_ruleset_button" and G.FUNCS.weekly_interrupt(e) then
		return
	end

	local default_ruleset_key = lobby_domain.get_creation_ruleset and lobby_domain.get_creation_ruleset()
		or MP.DEFAULT_LOBBY_CREATION_RULESET
	local default_button = selection.get_ruleset_selection_button_id
		and selection.get_ruleset_selection_button_id(default_ruleset_key)
		or "standard_ranked_ruleset_button"

	MP.UI.Change_Main_Lobby_Options(
		e,
		"ruleset_area",
		function(ruleset_name)
			return G.UIDEF.ruleset_info(ruleset_name)
		end,
		default_button,
		function(ruleset_name)
			selection.apply_ruleset_selection(ruleset_name)
		end
	)

	if lobby_domain.set_setup_ruleset_preview then
		lobby_domain.set_setup_ruleset_preview(false)
	end
end

function G.FUNCS.ruleset_switch_tabs(args)
	switch_selection_tabs(args, "ruleset_active_tab", "ruleset", lobby_domain.set_setup_ruleset_preview, true)
end
