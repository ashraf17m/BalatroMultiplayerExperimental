MP.UI = MP.UI or {}
MP.UI.MAIN_MENU_SELECTION = MP.UI.MAIN_MENU_SELECTION or {}

local selection = MP.UI.MAIN_MENU_SELECTION
local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY or {}
local LOBBY_ACCESS_MODE_VALUES = { "public", "ask_first", "private" }
local LOBBY_ACCESS_MODE_LABEL_KEYS = {
	public = "k_lobby_access_public",
	ask_first = "k_lobby_access_ask_first",
	private = "k_lobby_access_private",
}
local LOBBY_ACCESS_MODE_DESCRIPTION_KEYS = {
	public = "k_lobby_access_public_desc",
	ask_first = "k_lobby_access_ask_first_desc",
	private = "k_lobby_access_private_desc",
}
selection.LOBBY_ACCESS_MODE_VALUES = LOBBY_ACCESS_MODE_VALUES
selection.LOBBY_ACCESS_MODE_LABEL_KEYS = LOBBY_ACCESS_MODE_LABEL_KEYS

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

function selection.get_lobby_access_mode_index()
	local access_mode = lobby_domain.get_creation_access_mode
		and lobby_domain.get_creation_access_mode()
		or "private"
	for index, value in ipairs(LOBBY_ACCESS_MODE_VALUES) do
		if value == access_mode then
			return index
		end
	end
	return 3
end

function selection.get_lobby_access_mode_label(index)
	local access_mode = LOBBY_ACCESS_MODE_VALUES[index] or "private"
	return localize(LOBBY_ACCESS_MODE_LABEL_KEYS[access_mode])
end

function selection.get_lobby_access_mode_description(index)
	local access_mode = LOBBY_ACCESS_MODE_VALUES[index] or "private"
	return localize(LOBBY_ACCESS_MODE_DESCRIPTION_KEYS[access_mode])
end

function selection.get_lobby_access_mode_colour(index)
	local access_mode = LOBBY_ACCESS_MODE_VALUES[index] or "private"
	if access_mode == "public" then
		return G.C.GREEN
	elseif access_mode == "ask_first" then
		return G.C.BLUE
	end
	return G.C.PURPLE
end

local function build_lobby_access_mode_labels()
	local labels = {}
	for index, _ in ipairs(LOBBY_ACCESS_MODE_VALUES) do
		labels[#labels + 1] = selection.get_lobby_access_mode_label(index)
	end
	return labels
end

function selection.build_lobby_access_mode_tooltip(index)
	return { selection.get_lobby_access_mode_description(index or selection.get_lobby_access_mode_index()) }
end

function selection.build_lobby_access_mode_tab_cycle(colour, width)
	local current_index = selection.get_lobby_access_mode_index()
	return create_option_cycle({
		id = "lobby_access_mode_tab_cycle",
		options = build_lobby_access_mode_labels(),
		current_option = current_index,
		opt_callback = "change_lobby_access_mode",
		mode_values = LOBBY_ACCESS_MODE_VALUES,
		w = width or 5,
		colour = selection.get_lobby_access_mode_colour(current_index),
		cycle_shoulders = false,
		on_demand_tooltip = { text = selection.build_lobby_access_mode_tooltip(current_index) },
	})
end

local function build_coop_save_tooltip(save)
	local player_names = {}
	for _, player in ipairs(save.players or {}) do
		player_names[#player_names + 1] = tostring(player.name or "Guest")
	end

	return {
		"Players: " .. table.concat(player_names, ", "),
		"Ante: " .. tostring(save.ante or "?"),
		"Blind: " .. tostring(save.blind or "?"),
		"Max Score: " .. tostring(save.maxScore or "0"),
	}
end

local function build_coop_save_resume_button(save, index)
	return {
		n = G.UIT.C,
		config = {
			id = "coop_save_" .. tostring(index),
			button = "resume_coop_save",
			save_id = save.saveId,
			align = "cm",
			padding = 0.05,
			r = 0.1,
			minw = 6.6,
			minh = 0.65,
			colour = G.C.PURPLE,
			hover = true,
			shadow = true,
			on_demand_tooltip = { text = build_coop_save_tooltip(save) },
		},
		nodes = {
			{
				n = G.UIT.T,
				config = {
					text = "Save " .. tostring(index),
					scale = 0.45,
					colour = G.C.UI.TEXT_LIGHT,
				},
			},
		},
	}
end

local function build_coop_save_delete_button(save, index)
	return {
		n = G.UIT.C,
		config = {
			id = "delete_coop_save_" .. tostring(index),
			button = "delete_coop_save",
			save_id = save.saveId,
			align = "cm",
			padding = 0.05,
			r = 0.1,
			minw = 1.2,
			minh = 0.65,
			colour = G.C.RED,
			hover = true,
			shadow = true,
			on_demand_tooltip = { text = { "Remove save" } },
		},
		nodes = {
			{
				n = G.UIT.T,
				config = {
					text = "X",
					scale = 0.45,
					colour = G.C.UI.TEXT_LIGHT,
				},
			},
		},
	}
end

local function build_coop_save_row(save, index)
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.03 },
		nodes = {
			build_coop_save_resume_button(save, index),
			build_coop_save_delete_button(save, index),
		},
	}
end

local function build_gamemode_action_node(gamemode_name)
	local nodes = {
		build_action_button({
			id = "start_lobby_button",
			button = "start_lobby",
			text = localize("b_create_lobby"),
			colour = G.C.BLUE,
		}),
	}

	if gamemode_name == "coop" then
		for index, save in ipairs((MP.COOP_SAVE and MP.COOP_SAVE.saves) or {}) do
			nodes[#nodes + 1] = build_coop_save_row(save, index)
		end
	end

	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.03 },
		nodes = nodes,
	}
end

local function should_show_lobby_access_cycle(is_ruleset)
	return true
end

local function build_selection_tabs_panel(default_tabs, callback_name, opt_args, colour, is_ruleset)
	local show_access_cycle = should_show_lobby_access_cycle(is_ruleset)
	local cycle_width = show_access_cycle and 3.6 or 5
	local cycle_columns = {
		{
			n = G.UIT.C,
			config = { align = "cm", padding = 0.02 },
			nodes = {
				create_option_cycle({
					options = { localize("k_info"), localize("k_bans"), localize("k_reworks") },
					current_option = 1,
					opt_callback = callback_name,
					opt_args = opt_args,
					w = cycle_width,
					colour = colour,
					cycle_shoulders = false,
				}),
			},
		},
	}

	if show_access_cycle then
		cycle_columns[#cycle_columns + 1] = {
			n = G.UIT.C,
			config = { align = "cm", padding = 0.02 },
			nodes = {
				selection.build_lobby_access_mode_tab_cycle(colour, cycle_width),
			},
		}
	end

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
						nodes = cycle_columns,
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
		colour,
		is_ruleset
	)
end

function selection.build_gamemode_info(gamemode_name)
	local gamemode = MP.Gamemodes["gamemode_mp_" .. gamemode_name]
	local gamemode_info_tabs = UIBox({
		definition = G.UIDEF.gamemode_tabs(gamemode),
		config = { align = "cm" },
	})

	return build_selection_info_panel(gamemode_info_tabs, build_gamemode_action_node(gamemode_name))
end

function selection.build_gamemode_tabs(gamemode)
	return build_selection_tabs(gamemode, "gamemode_switch_tabs", "gamemode", G.C.ORANGE, false)
end

local function get_ruleset_selection_mode(mode)
	if mode then
		return mode
	end
	return selection.get_ruleset_selection_mode and selection.get_ruleset_selection_mode() or "lobby"
end

local function build_ruleset_button_config(ruleset, mode)
	return {
		id = "select_gamemode_button",
		button = ruleset.forced_gamemode and "force_" .. ruleset.forced_gamemode or "select_gamemode",
		label = { ruleset.forced_gamemode and localize("b_create_lobby") or localize("b_next") },
		colour = G.C.BLUE,
	}
end

function selection.build_ruleset_continue_button(ruleset, minw, mode)
	local ruleset_disabled = ruleset.is_disabled()
	local button_config = build_ruleset_button_config(ruleset, mode)

	return MP.UI.Disableable_Button({
		id = button_config.id,
		button = button_config.button,
		align = "cm",
		padding = 0.05,
		r = 0.1,
		minw = minw or 8,
		minh = 0.8,
		colour = button_config.colour,
		hover = true,
		shadow = true,
		label = button_config.label,
		scale = 0.5,
		enabled_ref_table = { val = not ruleset_disabled },
		enabled_ref_value = "val",
		disabled_text = { ruleset_disabled },
	})
end

function selection.build_modifier_button(ruleset, mode)
	if ruleset.forced_lobby_options then
		return nil
	end
	if type(ruleset.get_modifiers_ui) == "function" then
		return ruleset:get_modifiers_ui(mode)
	end

	return MP.UI.Disableable_Button({
		button = "mp_open_modifiers_overlay",
		align = "cm",
		padding = 0.05,
		r = 0.1,
		minw = 3.5,
		minh = 0.8,
		colour = G.C.ORANGE,
		hover = true,
		shadow = true,
		label = { "Modifiers..." },
		scale = 0.4,
		enabled_ref_table = { val = true },
		enabled_ref_value = "val",
		ref_table = {
			ruleset = ruleset,
			mode = get_ruleset_selection_mode(mode),
		},
	})
end

local function build_ranked_smods_recommendation_node(ruleset)
	if
		not (
			ruleset
			and MP.UTILS
			and MP.UTILS.is_ranked_ruleset_key
			and MP.UTILS.is_ranked_ruleset_key(ruleset.key)
			and MP.UTILS.get_recommended_smods_version
		)
	then
		return nil
	end

	local recommended_version = MP.UTILS.get_recommended_smods_version()
	local text = localize({
		type = "variable",
		key = "k_ruleset_recommended_smods_version",
		vars = { recommended_version },
	})
	local is_recommended = MP.UTILS.is_recommended_smods_version and MP.UTILS.is_recommended_smods_version()

	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.02, minh = 0.35 },
		nodes = {
			{
				n = G.UIT.T,
				config = {
					text = text,
					scale = 0.34,
					colour = is_recommended and G.C.GREEN or G.C.ORANGE,
				},
			},
		},
	}
end

local function build_ruleset_action_node(ruleset)
	local columns = {}
	local function add_column(node)
		if node then
			columns[#columns + 1] = {
				n = G.UIT.C,
				config = { align = "cm", padding = 0.05 },
				nodes = { node },
			}
		end
	end

	local nodes = {}
	local smods_recommendation_node = build_ranked_smods_recommendation_node(ruleset)
	if smods_recommendation_node then
		nodes[#nodes + 1] = smods_recommendation_node
	end

	add_column(selection.build_modifier_button(ruleset))
	add_column(selection.build_ruleset_continue_button(ruleset, #columns > 0 and 5 or 8))

	nodes[#nodes + 1] = {
		n = G.UIT.R,
		config = { align = "cm" },
		nodes = columns,
	}

	return {
		n = G.UIT.C,
		config = { align = "cm" },
		nodes = nodes,
	}
end

function selection.build_ruleset_info(ruleset_name)
	local ruleset = MP.Rulesets["ruleset_mp_" .. ruleset_name]
	local ruleset_info_tabs = UIBox({
		definition = G.UIDEF.ruleset_tabs(ruleset),
		config = { align = "cm" },
	})

	return build_selection_info_panel(ruleset_info_tabs, build_ruleset_action_node(ruleset))
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
