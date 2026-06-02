MP.UI = MP.UI or {}
MP.UI.MAIN_MENU_SELECTION = MP.UI.MAIN_MENU_SELECTION or {}

local selection = MP.UI.MAIN_MENU_SELECTION
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

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
		if is_banned_tab then
			return merge_lists({
				MP.DECK["BANNED_" .. string.upper(key)],
				ruleset_or_gamemode["banned_" .. key],
				forced_gamemode["banned_" .. key],
			})
		end

		return merge_lists({
			ruleset_or_gamemode["reworked_" .. key],
			forced_gamemode["reworked_" .. key],
		})
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
				BALATRO.get_center(obj_id),
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

	local tag_grid = build_object_grid(args.obj_ids.tags, BALATRO.get_tag_def, 4, tag_constructor)
	local blind_grid = build_object_grid(args.obj_ids.blinds, BALATRO.get_blind_def, 3, blind_constructor, true)

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
