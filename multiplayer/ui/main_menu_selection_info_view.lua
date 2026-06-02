MP.UI = MP.UI or {}
MP.UI.MAIN_MENU_SELECTION = MP.UI.MAIN_MENU_SELECTION or {}

local selection = MP.UI.MAIN_MENU_SELECTION

local function build_selection_info_panel(tabs_object, action_node)
	return {
		n = G.UIT.ROOT,
		config = { align = "tm", minh = 8, maxh = 8, minw = 11, maxw = 11, colour = G.C.CLEAR },
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "tm", padding = 0.2, r = 0.1, colour = G.C.BLACK },
				nodes = {
					{
						n = G.UIT.R,
						config = { align = "cm" },
						nodes = {
							{ n = G.UIT.O, config = { object = tabs_object } },
						},
					},
					{
						n = G.UIT.R,
						config = { align = "cm" },
						nodes = {
							action_node,
						},
					},
				},
			},
		},
	}
end

local function build_action_button(config)
	return {
		n = G.UIT.R,
		config = {
			id = config.id,
			button = config.button,
			align = "cm",
			padding = 0.05,
			r = 0.1,
			minw = 8,
			minh = 0.8,
			colour = config.colour,
			hover = true,
			shadow = true,
		},
		nodes = {
			{
				n = G.UIT.T,
				config = {
					text = config.text,
					scale = 0.5,
					colour = G.C.UI.TEXT_LIGHT,
				},
			},
		},
	}
end

local function build_selection_tabs_panel(default_tabs, callback_name, opt_args, colour)
	return {
		n = G.UIT.ROOT,
		config = { align = "cm", colour = G.C.L_BLACK, r = 0.1 },
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm" },
				nodes = {
					{
						n = G.UIT.R,
						config = { align = "tm", colour = G.C.GREY, r = 0.1 },
						nodes = {
							{ n = G.UIT.O, config = { object = default_tabs } },
						},
					},
					{
						n = G.UIT.R,
						config = { align = "bm", padding = 0.05 },
						nodes = {
							create_option_cycle({
								options = { localize("k_info"), localize("k_bans"), localize("k_reworks") },
								current_option = 1,
								opt_callback = callback_name,
								opt_args = opt_args,
								w = 5,
								colour = colour,
								cycle_shoulders = false,
							}),
						},
					},
				},
			},
		},
	}
end

local function build_selection_tabs(subject, callback_name, subject_key, colour, is_ruleset)
	local default_tabs = UIBox({
		definition = G.UIDEF.lobby_setup_tabs_definition(subject, "info", 1, is_ruleset),
		config = { align = "cm", tab_type = "info", chosen_tab = 1 },
	})

	return build_selection_tabs_panel(
		default_tabs,
		callback_name,
		{ ui = default_tabs, [subject_key] = subject },
		colour
	)
end

function selection.build_gamemode_info(gamemode_name)
	local gamemode = MP.Gamemodes["gamemode_mp_" .. gamemode_name]
	local gamemode_info_tabs = UIBox({
		definition = G.UIDEF.gamemode_tabs(gamemode),
		config = { align = "cm" },
	})

	return build_selection_info_panel(gamemode_info_tabs, build_action_button({
		id = "start_lobby_button",
		button = "start_lobby",
		text = localize("b_create_lobby"),
		colour = G.C.BLUE,
	}))
end

function selection.build_gamemode_tabs(gamemode)
	return build_selection_tabs(gamemode, "gamemode_switch_tabs", "gamemode", G.C.ORANGE, false)
end

local function build_ruleset_button_config(ruleset, mode)
	if mode == "sp" then
		return {
			id = "start_sp_button",
			button = "start_sp_run",
			label = { localize("b_play_cap") },
			colour = G.C.GREEN,
		}
	end

	return {
		id = "select_gamemode_button",
		button = ruleset.forced_gamemode and "force_" .. ruleset.forced_gamemode or "select_gamemode",
		label = { ruleset.forced_gamemode and localize("b_create_lobby") or localize("b_next") },
		colour = G.C.BLUE,
	}
end

function selection.build_ruleset_info(ruleset_name, mode)
	mode = mode or "mp"

	local ruleset = MP.Rulesets["ruleset_mp_" .. ruleset_name]
	local ruleset_info_tabs = UIBox({
		definition = G.UIDEF.ruleset_tabs(ruleset),
		config = { align = "cm" },
	})
	local ruleset_disabled = ruleset.is_disabled()
	local button_config = build_ruleset_button_config(ruleset, mode)

	return build_selection_info_panel(ruleset_info_tabs, MP.UI.Disableable_Button({
		id = button_config.id,
		button = button_config.button,
		align = "cm",
		padding = 0.05,
		r = 0.1,
		minw = 8,
		minh = 0.8,
		colour = button_config.colour,
		hover = true,
		shadow = true,
		label = button_config.label,
		scale = 0.5,
		enabled_ref_table = { val = not ruleset_disabled },
		enabled_ref_value = "val",
		disabled_text = { ruleset_disabled },
	}))
end

function selection.build_ruleset_tabs(ruleset)
	return build_selection_tabs(ruleset, "ruleset_switch_tabs", "ruleset", G.C.RED, true)
end

function selection.build_lobby_setup_tabs_definition(ruleset_or_gamemode, tab_type, chosen_tab_idx)
	if tab_type == "banned" or tab_type == "rework" then
		return selection.build_bans_and_reworks_tabs(ruleset_or_gamemode, tab_type == "banned", chosen_tab_idx)
	end

	local tab_id = ruleset_or_gamemode.key:find("ruleset") and "ruleset_active_tab" or "gamemode_active_tab"
	return {
		n = G.UIT.ROOT,
		config = { id = tab_id, align = "cm", colour = G.C.CLEAR },
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "tm", padding = 0.2, r = 0.1, minw = 10.7, maxw = 10.7, minh = 5.75, maxh = 5.75 },
				nodes = ruleset_or_gamemode.create_info_menu(),
			},
		},
	}
end
