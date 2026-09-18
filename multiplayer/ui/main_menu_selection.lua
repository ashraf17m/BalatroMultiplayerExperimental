-- Consolidated Main Menu Selection Module (Gamemode & Ruleset Selection)
-- Replaces 5 fragmented files with a unified, cohesive vertical module.

G = G or {}
G.UIDEF = G.UIDEF or {}
G.FUNCS = G.FUNCS or {}
MP = MP or {}
MP.UI = MP.UI or {}
MP.UI.MAIN_MENU_SELECTION = MP.UI.MAIN_MENU_SELECTION or {}

local selection = MP.UI.MAIN_MENU_SELECTION
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY or {}
local selection_utils = MP.UTILS or {}

-- ============================================================================
-- SECTION 1: BANS, REWORKS & CARDAREA VIEWS
-- (Consolidated from main_menu_selection_cardarea_view.lua)
-- ============================================================================

local function merge_lists(lists)
	local seen = {}
	local merged = {}

	for _, entries in pairs(lists) do
		entries = entries or {}
		for _, entry in ipairs(entries) do
			if not seen[entry] then
				seen[entry] = true
				table.insert(merged, entry)
			end
		end
	end

	return merged
end

local function build_tab_entries(ruleset_or_gamemode, is_banned_tab)
	local forced_gamemode = {}
	if ruleset_or_gamemode.forced_gamemode then
		forced_gamemode = MP.Gamemodes[ruleset_or_gamemode.forced_gamemode]
	end

	local loc_keys = {
		jokers = "b_jokers",
		consumables = "b_stat_consumables",
		vouchers = "b_vouchers",
		enhancements = "b_enhanced_cards",
		other = "k_other",
	}

	local function copy_list(key)
		local lists = nil
		if is_banned_tab then
			lists = {
				MP.DECK["BANNED_" .. string.upper(key)],
				ruleset_or_gamemode["banned_" .. key],
				forced_gamemode["banned_" .. key],
			}
			for _, modifier_name in ipairs(MP.MODIFIERS or {}) do
				local layer = MP.Layers and MP.Layers[modifier_name] or nil
				if layer then
					lists[#lists + 1] = layer["banned_" .. key]
				end
			end
			return merge_lists(lists)
		end

		lists = {
			ruleset_or_gamemode["reworked_" .. key],
			forced_gamemode["reworked_" .. key],
		}
		for _, modifier_name in ipairs(MP.MODIFIERS or {}) do
			local layer = MP.Layers and MP.Layers[modifier_name] or nil
			if layer then
				lists[#lists + 1] = layer["reworked_" .. key]
			end
		end
		return merge_lists(lists)
	end

	local tabs = {}
	for _, key in ipairs({ "jokers", "consumables", "vouchers", "enhancements", "other" }) do
		local entry = { type = localize(loc_keys[key]) }
		if key ~= "other" then
			entry.obj_ids = copy_list(key)
		else
			entry.obj_ids = {
				blinds = copy_list("blinds"),
				tags = copy_list("tags"),
			}
		end
		tabs[#tabs + 1] = entry
	end

	return tabs
end

function selection.build_bans_and_reworks_tabs(ruleset_or_gamemode, is_banned_tab, chosen_tab_idx)
	local tab_definitions = {}

	for idx, entry in ipairs(build_tab_entries(ruleset_or_gamemode, is_banned_tab)) do
		entry.idx = idx
		entry.is_banned_tab = is_banned_tab
		tab_definitions[#tab_definitions + 1] = {
			label = entry.type,
			chosen = idx == chosen_tab_idx,
			tab_definition_function = G.UIDEF.ruleset_cardarea_definition,
			tab_definition_function_args = entry,
		}
	end

	return {
		n = G.UIT.ROOT,
		config = { align = "cm", colour = G.C.CLEAR },
		nodes = {
			create_tabs({
				tab_h = 4.2,
				padding = 0,
				scale = 0.8,
				text_scale = 0.36,
				no_shoulders = true,
				no_loop = true,
				tabs = tab_definitions,
			}),
		},
	}
end

local function build_card_rows(obj_ids, width, height)
	local rows = {}

	if #obj_ids == 0 then
		return rows
	end

	local card_rows = {}
	local row_count = math.max(1, 1 + math.floor(#obj_ids / 10) - math.floor(math.log(6, #obj_ids)))
	local max_width = 1

	for idx, obj_id in ipairs(obj_ids) do
		local row = math.ceil(row_count * (idx / #obj_ids))
		card_rows[row] = card_rows[row] or {}
		card_rows[row][#card_rows[row] + 1] = obj_id
		if #card_rows[row] > max_width then
			max_width = #card_rows[row]
		end
	end

	local card_size = math.max(0.3, 0.8 - 0.01 * (max_width * row_count))
	for _, card_row in ipairs(card_rows) do
		local card_area = CardArea(0, 0, width, height / row_count, {
			card_limit = nil,
			type = "title_2",
			view_deck = true,
			highlight_limit = 0,
			card_w = G.CARD_W * card_size,
		})

		for _, obj_id in ipairs(card_row) do
			local card = Card(
				0,
				0,
				G.CARD_W * card_size,
				G.CARD_H * card_size,
				nil,
				(G and G.P_CENTERS and G.P_CENTERS[obj_id] or nil),
				{ bypass_discovery_center = true, bypass_discovery_ui = true }
			)
			card_area:emplace(card)
		end

		rows[#rows + 1] = {
			n = G.UIT.R,
			config = { align = "cm" },
			nodes = {
				{ n = G.UIT.O, config = { object = card_area } },
			},
		}
	end

	return rows
end

local function resolve_object(object_source, obj_id)
	if type(object_source) == "function" then
		return object_source(obj_id)
	end

	return object_source and object_source[obj_id] or nil
end

local function build_object_grid(obj_ids, object_source, objects_per_row, object_constructor, wrap_as_object)
	local grid = {}
	local row_nodes = {}

	for idx, obj_id in ipairs(obj_ids) do
		local row_index = math.ceil(idx / objects_per_row)
		local object_spec = resolve_object(object_source, obj_id)
		row_nodes[row_index] = row_nodes[row_index] or {}
		table.insert(row_nodes[row_index], {
			n = G.UIT.C,
			config = { align = "cm", padding = 0.1 },
			nodes = {
				wrap_as_object and { n = G.UIT.O, config = { object = object_constructor(object_spec) } }
					or object_constructor(object_spec),
			},
		})
	end

	for _, row in ipairs(row_nodes) do
		grid[#grid + 1] = {
			n = G.UIT.R,
			config = { align = "cm" },
			nodes = row,
		}
	end

	return grid
end

local function build_localized_label(args, objs, obj_type)
	local key = (#objs > 0) and "k_banned_objs" or "k_no_banned_objs"
	if not args.is_banned_tab then
		key = (#objs > 0) and "k_reworked_objs" or "k_no_reworked_objs"
	end

	return {
		n = G.UIT.T,
		config = {
			text = localize({
				type = "variable",
				key = key,
				vars = { obj_type },
			}),
			colour = lighten(G.C.L_BLACK, 0.5),
			scale = 0.33,
		},
	}
end

local function build_ruleset_tab_root(args, nodes)
	return {
		n = G.UIT.ROOT,
		config = { id = "ruleset_active_tab", tab_idx = args.idx, align = "cm", colour = G.C.CLEAR },
		nodes = nodes,
	}
end

local function build_labeled_cardarea_panel(content_node, label_node, minw)
	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.05, r = 0.1, minw = minw, minh = 4.8, maxh = 4.8 },
		nodes = {
			content_node,
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.05 },
				nodes = { label_node },
			},
		},
	}
end

local function build_other_tab_grid(args)
	local function tag_constructor(tag_spec)
		return Tag(tag_spec.key):generate_UI(1 - 0.1 * math.sqrt(#args.obj_ids.tags))
	end

	local function blind_constructor(blind_spec)
		local blind = AnimatedSprite(
			0,
			0,
			1.1,
			1.1,
			BALATRO.get_animation_atlas(blind_spec.atlas) or BALATRO.get_animation_atlas("blind_chips"),
			blind_spec.pos
		)
		blind:define_draw_steps({
			{ shader = "dissolve", shadow_height = 0.05 },
			{ shader = "dissolve" },
		})
		blind.float = true
		blind.states.hover.can = true
		blind.states.drag.can = false
		blind.states.collide.can = true
		blind.config = { blind = blind_spec, force_focus = true }
		blind.hover = function()
			if not (BALATRO.is_controller_mouse_dragging and BALATRO.is_controller_mouse_dragging()) then
				if not blind.hovering and blind.states.visible then
					blind.hovering = true
					blind.hover_tilt = 3
					MP.UI.MAIN_MENU.juice_up(blind, 0.05, 0.02)
					blind.config.h_popup = create_UIBox_blind_popup(blind_spec, true)
					blind.config.h_popup_config = {
						align = "cl",
						offset = { x = -0.1, y = 0 },
						parent = blind,
					}
					Node.hover(blind)
				end
			end
		end
		blind.stop_hover = function()
			blind.hovering = false
			Node.stop_hover(blind)
			blind.hover_tilt = 0
		end

		return blind
	end

	local tag_grid = build_object_grid(args.obj_ids.tags, function(key) return G and G.P_TAGS and G.P_TAGS[key] or nil end, 4, tag_constructor)
	local blind_grid = build_object_grid(args.obj_ids.blinds, function(key) return G and G.P_BLINDS and G.P_BLINDS[key] or nil end, 3, blind_constructor, true)

	return build_ruleset_tab_root(args, {
		build_labeled_cardarea_panel(
			{ n = G.UIT.R, config = { align = "cm", minh = 4 }, nodes = tag_grid },
			build_localized_label(args, args.obj_ids.tags, localize("b_tags")),
			5.4
		),
		build_labeled_cardarea_panel(
			{ n = G.UIT.R, config = { align = "cm", minh = 4 }, nodes = blind_grid },
			build_localized_label(args, args.obj_ids.blinds, localize("b_blinds")),
			5.4
		),
	})
end

function selection.build_ruleset_cardarea_definition(args)
	if args.type == localize("k_other") then
		return build_other_tab_grid(args)
	end

	return build_ruleset_tab_root(args, {
		build_labeled_cardarea_panel(
			{ n = G.UIT.R, config = { align = "cm" }, nodes = build_card_rows(args.obj_ids, 10, 4) },
			build_localized_label(args, args.obj_ids, args.type),
			10.8
		),
	})
end

-- ============================================================================
-- SECTION 2: SELECTION INFO & ACCESS MODE TOOLTIPS
-- (Consolidated from main_menu_selection_info_view.lua)
-- ============================================================================

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

-- ============================================================================
-- SECTION 3: SELECTION OPTIONS & TABS
-- (Consolidated from main_menu_selection_option_view.lua)
-- ============================================================================

local TOURNAMENT_RULESET_KEYS = {
	speedlatro = true,
	badlatro = true,
	chaos = true,
}

local EXPERIMENTAL_RULESET_KEYS = {
	experimental = true,
	experimental_legacy = true,
}

local RULESET_SELECTION_TABS = {
	{
		label_key = "k_mp_ruleset_tab_general",
		fallback_label = "General",
		include_ruleset = function(ruleset, selection_key)
			local group_key = ruleset.selection_group_key
			return (group_key == "k_matchmaking" or group_key == "k_custom")
				and not TOURNAMENT_RULESET_KEYS[selection_key]
				and not EXPERIMENTAL_RULESET_KEYS[selection_key]
		end,
	},
	{
		label_key = "k_mp_ruleset_tab_tournaments",
		fallback_label = "Tournaments",
		include_ruleset = function(ruleset, selection_key)
			return ruleset.selection_group_key == "k_tournament" or TOURNAMENT_RULESET_KEYS[selection_key]
		end,
		group_key = function(ruleset, selection_key)
			return TOURNAMENT_RULESET_KEYS[selection_key] and "k_custom" or (ruleset.selection_group_key or "k_tournament")
		end,
		group_order = function(_, _, group_key)
			return group_key == "k_tournament" and 1 or 2
		end,
	},
	{
		label_key = "k_mp_ruleset_tab_experimental",
		fallback_label = "Experimental",
		include_ruleset = function(ruleset, selection_key)
			return ruleset.selection_group_key == "k_experimental" or EXPERIMENTAL_RULESET_KEYS[selection_key]
		end,
		group_key = function()
			return "k_experimental"
		end,
		group_order = function()
			return 1
		end,
	},
}

local function localize_or_fallback(key, fallback)
	local ok, localized = pcall(localize, key)
	if ok and type(localized) == "string" and localized ~= "" and localized ~= key and localized ~= "ERROR" then
		return localized
	end
	return fallback
end

local function compare_selection_entries(a, b)
	if a.group_order ~= b.group_order then
		return a.group_order < b.group_order
	end
	if a.selection_order ~= b.selection_order then
		return a.selection_order < b.selection_order
	end
	return a.selection_key < b.selection_key
end

local function build_default_area(definition)
	return UIBox({
		definition = definition,
		config = { align = "cm" },
	})
end

local function get_gamemode_selection_name(gamemode_key)
	if selection_utils and selection_utils.strip_selection_prefix then
		return selection_utils.strip_selection_prefix(gamemode_key, "gamemode_mp_")
	end
	local key = tostring(gamemode_key or "")
	return key:gsub("^gamemode_mp_", "")
end

function selection.get_gamemode_selection_button_id(gamemode_key)
	return get_gamemode_selection_name(gamemode_key) .. "_gamemode_button"
end

function selection.build_gamemode_selection_buttons_data()
	if not selection_utils or not selection_utils.build_grouped_selection_buttons_data then
		return {}
	end
	return selection_utils.build_grouped_selection_buttons_data(MP.Gamemodes, {
		key_prefix = "gamemode_mp_",
		default_group_key = "k_challenge",
		get_button_id = function(gamemode)
			return selection.get_gamemode_selection_button_id(gamemode.key)
		end,
	})
end

local function get_ruleset_selection_name(ruleset_key)
	if selection_utils and selection_utils.strip_selection_prefix then
		return selection_utils.strip_selection_prefix(ruleset_key, "ruleset_mp_")
	end
	local key = tostring(ruleset_key or "")
	return key:gsub("^ruleset_mp_", "")
end

function selection.get_ruleset_selection_button_id(ruleset_key)
	return get_ruleset_selection_name(ruleset_key) .. "_ruleset_button"
end

local function build_ruleset_buttons_data_for_tab(tab_spec)
	local grouped_categories = {}
	local category_order = {}
	local ordered_entries = {}

	for _, ruleset in pairs(MP.Rulesets or {}) do
		local selection_key = get_ruleset_selection_name(ruleset.key)
		if tab_spec.include_ruleset(ruleset, selection_key) then
			local group_key = tab_spec.group_key and tab_spec.group_key(ruleset, selection_key)
				or ruleset.selection_group_key
				or "k_custom"
			local group_order = tab_spec.group_order and tab_spec.group_order(ruleset, selection_key, group_key)
				or tonumber(ruleset.selection_group_order)
				or 99

			ordered_entries[#ordered_entries + 1] = {
				ruleset = ruleset,
				selection_key = selection_key,
				group_key = group_key,
				group_order = group_order,
				selection_order = tonumber(ruleset.selection_order) or 999,
			}
		end
	end

	table.sort(ordered_entries, compare_selection_entries)

	for _, entry in ipairs(ordered_entries) do
		local category = grouped_categories[entry.group_key]
		if not category then
			category = {
				name = entry.group_key,
				buttons = {},
			}
			grouped_categories[entry.group_key] = category
			category_order[#category_order + 1] = category
		end

		category.buttons[#category.buttons + 1] = {
			button_id = selection.get_ruleset_selection_button_id(entry.ruleset.key),
			button_localize_key = entry.ruleset.selection_localize_key or ("k_" .. entry.selection_key),
			button_col = entry.ruleset.selection_button_colour,
		}
	end

	return category_order
end

local function first_ruleset_key_from_buttons_data(buttons_data)
	for _, category in ipairs(buttons_data or {}) do
		for _, button in ipairs(category.buttons or {}) do
			local selection_key = string.match(button.button_id or "", "(.+)_ruleset_button$")
			if selection_key then
				return "ruleset_mp_" .. selection_key
			end
		end
	end
	return nil
end

local function ruleset_key_belongs_to_tab(ruleset_key, tab_spec)
	local ruleset = MP.Rulesets and MP.Rulesets[ruleset_key] or nil
	if not ruleset then
		return false
	end
	return tab_spec.include_ruleset(ruleset, get_ruleset_selection_name(ruleset_key))
end

function selection.set_ruleset_selection_mode(mode)
	selection.ruleset_selection_mode = "lobby"
	return selection.ruleset_selection_mode
end

function selection.get_ruleset_selection_mode()
	return selection.ruleset_selection_mode or "lobby"
end

function selection.build_ruleset_selection_buttons_data(args)
	args = args or {}
	if args.tab_spec then
		return build_ruleset_buttons_data_for_tab(args.tab_spec)
	end

	return selection_utils.build_grouped_selection_buttons_data(MP.Rulesets, {
		key_prefix = "ruleset_mp_",
		default_group_key = "k_custom",
		get_button_id = function(ruleset)
			return selection.get_ruleset_selection_button_id(ruleset.key)
		end,
	})
end

-- ============================================================================
-- MAIN MENU SELECTION 2-COLUMN LAYOUT (Gamemode & Ruleset Selection)
-- ============================================================================

local function create_main_lobby_options_title(info_area_id)
	local title_colour = mix_colours(G.C.RED, G.C.BLACK, 0.6)
	local title = "ERROR"

	if info_area_id == "ruleset_area" then
		title_colour = mix_colours(G.C.BLUE, G.C.BLACK, 0.6)
		title = localize("k_rulesets") or "ERROR"
	end

	if info_area_id == "gamemode_area" then
		title_colour = mix_colours(G.C.ORANGE, G.C.BLACK, 0.6)
		title = localize("k_gamemodes") or "ERROR"
	end

	if title == "ERROR" then return nil end

	return MP.UI.UTILS.create_row({ id = "ruleset_name", align = "cm", padding = 0.07 }, {
		MP.UI.UTILS.create_row({
			align = "cm",
			r = 0.1,
			outline = 1,
			outline_colour = title_colour,
			colour = darken(title_colour, 0.3),
			minw = 2.9,
			emboss = 0.1,
			padding = 0.07,
			line_emboss = 1,
		}, {
			MP.UI.UTILS.create_object_node(DynaText({
				string = { { string = title } },
				colours = { G.C.WHITE },
				float = true,
				y_offset = -4,
				scale = 0.45,
				maxw = 2.8,
			})),
		}),
	})
end

local function build_main_lobby_options_columns(info_area_id, default_info_area, button_func, buttons_data, selected_button_id)
	local categories = {
		create_main_lobby_options_title(info_area_id),
	}
	for cat_idx, category in ipairs(buttons_data) do
		local buttons = {}
		for btn_idx, data in ipairs(category.buttons) do
			local col = data.button_col or G.C.RED
			if data.button_id == "weekly_ruleset_button" then
				if (not MP.LOBBY.config.weekly) or (MP.LOBBY.config.weekly ~= MP.LOBBY.setup.fetched_weekly) then
					col = G.C.DARK_EDITION
				end
			end
			local button = UIBox_button({
				id = data.button_id,
				col = true,
				chosen = (
					(selected_button_id and data.button_id == selected_button_id)
					or (not selected_button_id and cat_idx == 1 and btn_idx == 1)
				) and "vert" or false,
				label = { localize(data.button_localize_key) },
				button = button_func,
				colour = col,
				minw = 4,
				scale = 0.4,
				minh = 0.6,
			})
			buttons[#buttons + 1] = MP.UI.UTILS.create_row({ align = "cm", padding = 0.05 }, { button })
		end
		categories[#categories + 1] = MP.UI.BackgroundGrouping(localize(category.name), buttons)
	end

	return {
		{ n = G.UIT.C, config = { align = "tm", minh = 8, minw = 4, padding = 0.1 }, nodes = categories },
		{
			n = G.UIT.C,
			config = { align = "cm", minh = 8, maxh = 8, minw = 11, maxw = 11 },
			nodes = {
				{ n = G.UIT.O, config = { id = info_area_id, object = default_info_area } },
			},
		},
	}
end

function MP.UI.Main_Lobby_Options(info_area_id, default_info_area, button_func, buttons_data, selected_button_id, args)
	args = args or {}
	local columns = build_main_lobby_options_columns(
		info_area_id,
		default_info_area,
		button_func,
		buttons_data,
		selected_button_id
	)

	if args.raw then
		return {
			n = G.UIT.ROOT,
			config = { colour = G.C.CLEAR },
			nodes = columns,
		}
	end

	return create_UIBox_generic_options({
		back_func = args.back_func or "play_options",
		contents = columns,
	})
end
selection.Main_Lobby_Options = MP.UI.Main_Lobby_Options

function MP.UI.Change_Main_Lobby_Options(e, info_area_id, info_area_func, default_button_id, update_lobby_config_func)
	if not G.OVERLAY_MENU then return end

	local info_area = G.OVERLAY_MENU:get_UIE_by_ID(info_area_id)
	if not info_area then return end

	-- Switch 'chosen' status from the previously-chosen button to this one:
	if info_area.config.prev_chosen then
		info_area.config.prev_chosen.config.chosen = nil
	else -- The previously-chosen button should be the default one here:
		local default_button = G.OVERLAY_MENU:get_UIE_by_ID(default_button_id)
		if default_button then default_button.config.chosen = nil end
	end
	e.config.chosen = "vert" -- Special setting to show 'chosen' indicator on the side

	local info_obj_name = string.match(e.config.id, "(.+)_%w+_button")
	update_lobby_config_func(info_obj_name)

	MP.UI.UTILS.replace_config_object(info_area, UIBox({
		definition = info_area_func(info_obj_name),
		config = { align = "cm", parent = info_area },
	}), {
		recalculate_target = G.OVERLAY_MENU,
	})

	info_area.config.prev_chosen = e
end
selection.Change_Main_Lobby_Options = MP.UI.Change_Main_Lobby_Options

function selection.build_gamemode_selection_options(initial_gamemode_key, options)
	options = options or {}
	local fallback_gamemode_key = MP.DEFAULT_LOBBY_CREATION_GAMEMODE or "gamemode_mp_attrition"
	local gamemode_key = initial_gamemode_key or fallback_gamemode_key
	if not (MP.Gamemodes and MP.Gamemodes[gamemode_key]) then
		gamemode_key = fallback_gamemode_key
	end
	lobby_domain.set_creation_gamemode(gamemode_key)
	local gamemode_name = get_gamemode_selection_name(gamemode_key)

	local gamemode_buttons_data = selection.build_gamemode_selection_buttons_data()
		or {}

	return MP.UI.Main_Lobby_Options(
		"gamemode_area",
		build_default_area(G.UIDEF.gamemode_info(gamemode_name)),
		"change_gamemode_selection",
		gamemode_buttons_data,
		selection.get_gamemode_selection_button_id(gamemode_key),
		{
			raw = options.raw,
			back_func = options.back_func or "return_to_ruleset_selection",
		}
	)
end

function selection.build_gamemode_selection_tabs(initial_gamemode_key, options)
	options = options or {}
	return create_UIBox_generic_options({
		back_func = options.back_func or "return_to_ruleset_selection",
		contents = {
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0 },
				nodes = {
					create_tabs({
						tabs = {
							{
								label = localize("k_gamemodes"),
								chosen = true,
								tab_definition_function = function()
									return selection.build_gamemode_selection_options(initial_gamemode_key, {
										raw = true,
									})
								end,
							},
						},
						colour = G.C.BOOSTER,
					}),
				},
			},
		},
	})
end

function selection.apply_ruleset_selection(ruleset_name)
	if MP.CUSTOM and MP.CUSTOM.clear_pending_lobby_options then
		MP.CUSTOM.clear_pending_lobby_options()
	end
	lobby_domain.set_creation_ruleset("ruleset_mp_" .. ruleset_name)
	if MP.apply_default_modifiers then
		MP.apply_default_modifiers(ruleset_name)
	end
	MP.LoadReworks(ruleset_name)
end

local function apply_default_ruleset(ruleset_name)
	if lobby_domain.set_setup_fetched_weekly then
		lobby_domain.set_setup_fetched_weekly("smallworld")
	end

	selection.apply_ruleset_selection(ruleset_name)
end

function selection.build_ruleset_selection_options(initial_ruleset_key, options)
	options = options or {}
	local mode = selection.set_ruleset_selection_mode(options.mode)
	local default_ruleset_key = initial_ruleset_key or MP.DEFAULT_LOBBY_CREATION_RULESET
	if not (MP.Rulesets and MP.Rulesets[default_ruleset_key]) then
		default_ruleset_key = MP.DEFAULT_LOBBY_CREATION_RULESET
	end
	local default_ruleset = string.sub(default_ruleset_key, 12, -1)

	if options.preserve_modifiers then
		if MP.CUSTOM and MP.CUSTOM.clear_pending_lobby_options then
			MP.CUSTOM.clear_pending_lobby_options()
		end
		lobby_domain.set_creation_ruleset(default_ruleset_key)
		MP.LoadReworks(default_ruleset)
	else
		apply_default_ruleset(default_ruleset)
	end

	local ruleset_buttons_data = options.buttons_data or selection.build_ruleset_selection_buttons_data() or {}

	return MP.UI.Main_Lobby_Options(
		"ruleset_area",
		build_default_area(G.UIDEF.ruleset_info(default_ruleset)),
		"change_ruleset_selection",
		ruleset_buttons_data,
		selection.get_ruleset_selection_button_id(default_ruleset_key),
		{
			raw = options.raw,
			back_func = options.back_func or "play_options",
		}
	)
end

function selection.build_ruleset_selection_tabs(initial_ruleset_key, options)
	if type(options) == "string" then
		options = { chosen_label = options }
	end
	options = options or {}
	if initial_ruleset_key == "mp" or initial_ruleset_key == "lobby" then
		options.mode = "lobby"
		initial_ruleset_key = nil
	elseif initial_ruleset_key == "sp" then
		initial_ruleset_key = nil
	end

	local requested_ruleset_key = initial_ruleset_key
		or MP.DEFAULT_LOBBY_CREATION_RULESET
	local tabs = {}
	local has_chosen_tab = false

	for _, tab_spec in ipairs(RULESET_SELECTION_TABS) do
		local buttons_data = selection.build_ruleset_selection_buttons_data({ tab_spec = tab_spec })
		local tab_ruleset_key = first_ruleset_key_from_buttons_data(buttons_data)
		if tab_ruleset_key then
			local requested_key_belongs_here = ruleset_key_belongs_to_tab(requested_ruleset_key, tab_spec)
			local tab_label = localize_or_fallback(tab_spec.label_key, tab_spec.fallback_label)
			local chosen_by_label = options.chosen_label and tab_label == options.chosen_label
			if requested_key_belongs_here then
				tab_ruleset_key = requested_ruleset_key
			end

			local tab = {
				label = tab_label,
				chosen = chosen_by_label or (requested_key_belongs_here and not options.chosen_label),
				tab_definition_function = function()
					return selection.build_ruleset_selection_options(tab_ruleset_key, {
						mode = options.mode,
						preserve_modifiers = options.preserve_modifiers and requested_key_belongs_here,
						buttons_data = buttons_data,
						raw = true,
					})
				end,
			}

			if tab.chosen then
				has_chosen_tab = true
			end
			tabs[#tabs + 1] = tab
		end
	end

	if MP.UI.build_custom_ruleset_editor then
		local custom_label = "Custom"
		local custom_chosen = options.chosen_label == custom_label
		tabs[#tabs + 1] = {
			label = custom_label,
			chosen = custom_chosen,
			tab_definition_function = function()
				return MP.UI.build_custom_ruleset_editor(options.mode or "lobby")
			end,
		}
		if custom_chosen then
			has_chosen_tab = true
		end
	end

	if not has_chosen_tab and tabs[1] then
		tabs[1].chosen = true
	end

	if #tabs == 0 then
		return selection.build_ruleset_selection_options(requested_ruleset_key, options)
	end

	return create_UIBox_generic_options({
		back_func = options.back_func or "play_options",
		contents = {
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0 },
				nodes = {
					create_tabs({
						tabs = tabs,
						colour = G.C.BOOSTER,
					}),
				},
			},
		},
	})
end

-- ============================================================================
-- SECTION 4: G.UIDEF SELECTION BINDINGS
-- (Consolidated from main_menu_selection_view_model.lua)
-- ============================================================================

G.UIDEF.gamemode_selection_options = selection.build_gamemode_selection_options
G.UIDEF.gamemode_selection_tabs = selection.build_gamemode_selection_tabs
G.UIDEF.gamemode_info = selection.build_gamemode_info
G.UIDEF.gamemode_tabs = selection.build_gamemode_tabs
G.UIDEF.ruleset_selection_options = selection.build_ruleset_selection_options
G.UIDEF.ruleset_selection_tabs = selection.build_ruleset_selection_tabs
G.UIDEF.ruleset_info = selection.build_ruleset_info
G.UIDEF.ruleset_tabs = selection.build_ruleset_tabs
G.UIDEF.lobby_setup_tabs_definition = selection.build_lobby_setup_tabs_definition
G.UIDEF.ruleset_cardarea_definition = selection.build_ruleset_cardarea_definition

-- ============================================================================
-- SECTION 5: SELECTION CONTROLLER & ACTION CALLBACKS
-- (Consolidated from main_menu_selection_controller.lua)
-- ============================================================================

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

