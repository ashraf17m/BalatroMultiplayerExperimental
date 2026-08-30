MP.UI = MP.UI or {}
MP.UI.PLAYERS_HUD_SHARED = MP.UI.PLAYERS_HUD_SHARED or {}

local shared = MP.UI.PLAYERS_HUD_SHARED
local create_text_label = shared.create_text_label
local create_stat_text_label = shared.create_stat_text_label or create_text_label
local create_rank_label = shared.create_rank_label
local create_player_blind_icon_object = shared.create_player_blind_icon_object
local create_stake_score_box = shared.create_stake_score_box
local create_blind_style_palette = shared.create_blind_style_palette
local get_eased_score_display = shared.get_eased_score_display
local get_standings_stat_display = shared.get_standings_stat_display
local create_blind_style_row = shared.create_blind_style_row

shared.PVP_HUD_LAYOUT_REVISION = "pvp_hud_2026_07_27_row_click_no_press"

local COMPACT_SCORE_ROW_DEFAULTS = {
	minw = 5.2,
	minh = 1.12,
	padding = 0.012,
	left_w = 0.68,
	center_w = 0.62,
	right_w = 0.62,
	right_minw = 0.62,
	far_right_w = 3.12,
	right_padding = 0.01,
	header_minh = 0.42,
	body_minh = 0.66,
	outer_inset = 0.0,
	inner_inset = 0.0,
	header_left_w = 0.62,
}

local COMPACT_STANDINGS_STYLE = {
	panel_minw = 5.2,
	visible_limit = 3,
	rank_text_scale = 0.36,
	title_text_scale = 0.38,
	stat_text_scale = 0.36,
	score_text_scale = 0.56,
	score_box_w = 3.06,
	full_list_column_size = 8,
	full_list_column_gap = 0.08,
	full_list_page_columns = 4,
}

local function create_compact_score_row(config)
	config = config or {}
	for key, value in pairs(COMPACT_SCORE_ROW_DEFAULTS) do
		if config[key] == nil then
			config[key] = value
		end
	end
	return create_blind_style_row(config)
end

local function get_entry_stat_display(entry, stat_key, value)
	if not get_standings_stat_display then
		return nil
	end

	local bucket = tostring(entry.stat_bucket or "standings") .. "_" .. tostring(stat_key)
	local key = entry.stat_key or entry.id or entry.title or entry.rank or "default"
	return get_standings_stat_display(bucket, key, value)
end

local function create_compact_average_score_row(config)
	config = config or {}
	local pvp_col = config.pvp_col or G.C.MULTIPLAYER or HEX("AC3232")
	local palette = create_blind_style_palette and create_blind_style_palette(darken(pvp_col, 0.16)) or {}
	local average_score_display = get_eased_score_display(
		"average_standings_scores",
		config.average_key,
		config.average_score,
		{ delay = shared.PVP_SCORE_EASE_DELAY }
	)

	return create_compact_score_row({
		header_colour = palette.header or darken(pvp_col, config.header_darken or 0.22),
		body_colour = palette.body or mix_colours(G.C.GREY, G.C.BLACK, 0.64),
		left_slot_colour = G.C.CLEAR,
		left_slot_no_fill = true,
		center_slot_colour = G.C.BLACK,
		right_slot_colour = G.C.BLACK,
		far_right_slot_colour = palette.right_slot or darken(G.C.GREY, 0.45),
		header_left_nodes = {
			create_text_label(config.tag or "AVG", config.tag_scale or 0.3, G.C.UI.TEXT_LIGHT),
		},
		header_center_align = "cm",
		header_center_nodes = {
			create_text_label(config.title or "AVERAGE SCORE", config.title_scale or 0.36, G.C.UI.TEXT_LIGHT),
		},
		left_nodes = {
			create_text_label("-", config.placeholder_scale or 0.34, G.C.UI.TEXT_LIGHT),
		},
		center_nodes = {
			create_text_label("-", config.stat_scale or 0.36, G.C.RED, false),
		},
		right_nodes = {
			create_stat_text_label(
				get_standings_stat_display
						and get_standings_stat_display("average_standings_hands", config.average_key, config.total_hands)
					or nil,
				tostring(config.total_hands or 0),
				config.stat_scale or 0.36,
				G.C.BLUE,
				false
			),
		},
		far_right_nodes = {
			create_stake_score_box(
				average_score_display.text,
				config.score_box_w or COMPACT_STANDINGS_STYLE.score_box_w,
				config.score_scale or 0.56,
				G.C.WHITE,
				config.score_minh or 0.52,
				config.stake_scale or 0.44,
				average_score_display
			),
		},
	})
end

local function create_compact_blind_icon_nodes(player, icon_size)
	local size = icon_size or 0.6
	return {
		{
			n = G.UIT.R,
			config = { align = "cm", padding = 0.005 },
			nodes = {
				{
					n = G.UIT.O,
					config = {
						object = create_player_blind_icon_object(player, size),
						w = size,
						h = size,
						focus_with_object = false,
					},
				},
			},
		},
	}
end

local function append_spaced_stack_nodes(rows, entries, create_node)
	for index, entry in ipairs(entries) do
		rows[#rows + 1] = create_node(entry)
		if index < #entries then
			rows[#rows + 1] = { n = G.UIT.R, config = { minh = 0.014 } }
		end
	end
end

local function create_full_list_columns(entries, create_entry, column_size, column_minw)
	local columns = {}
	local max_per_column = math.max(1, column_size or COMPACT_STANDINGS_STYLE.full_list_column_size)

	for start_index = 1, #entries, max_per_column do
		local column_rows = {}
		local end_index = math.min(#entries, start_index + max_per_column - 1)
		for entry_index = start_index, end_index do
			column_rows[#column_rows + 1] = create_entry(entries[entry_index])
			if entry_index < end_index then
				column_rows[#column_rows + 1] = { n = G.UIT.R, config = { minh = 0.014 } }
			end
		end

		columns[#columns + 1] = {
			n = G.UIT.C,
			config = {
				align = "tm",
				minw = column_minw,
				padding = 0.0,
				colour = G.C.CLEAR,
			},
			nodes = column_rows,
		}

		if end_index < #entries then
			columns[#columns + 1] = {
				n = G.UIT.C,
				config = {
					minw = COMPACT_STANDINGS_STYLE.full_list_column_gap,
					colour = G.C.CLEAR,
				},
				nodes = {},
			}
		end
	end

	return {
		n = G.UIT.R,
		config = { align = "tm", padding = 0.0, colour = G.C.CLEAR },
		nodes = columns,
	}
end

local function create_full_standings_pager(page, page_count)
	if not (page_count and page_count > 1) then
		return nil
	end

	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.02, colour = G.C.CLEAR },
		nodes = {
			MP.UI.ROW_LAYOUT.create_button_from_spec({
				label = "<",
				button = "mp_full_standings_prev_page",
				minw = 0.52,
				minh = 0.34,
				scale = 0.38,
				colour = G.C.RED,
			}),
			{ n = G.UIT.B, config = { w = 0.08, h = 0.01 } },
			{
				n = G.UIT.C,
				config = { align = "cm", minw = 1.0, padding = 0.02, colour = G.C.CLEAR },
				nodes = {
					create_text_label(tostring(page) .. "/" .. tostring(page_count), 0.35, G.C.UI.TEXT_LIGHT),
				},
			},
			{ n = G.UIT.B, config = { w = 0.08, h = 0.01 } },
			MP.UI.ROW_LAYOUT.create_button_from_spec({
				label = ">",
				button = "mp_full_standings_next_page",
				minw = 0.52,
				minh = 0.34,
				scale = 0.38,
				colour = G.C.GREEN,
			}),
		},
	}
end

local function create_compact_stack_panel(rows, minw, full_list)
	local panel_config = full_list
		and { align = "cm", padding = 0.02, minw = minw }
		or {
			align = "cm",
			padding = 0.0,
			minw = minw,
			r = 0.0,
			colour = G.C.CLEAR,
			shadow = false,
			emboss = 0,
			no_fill = true,
		}

	return {
		{
			n = G.UIT.C,
			config = panel_config,
			nodes = rows,
		},
	}
end

local function get_compact_standings_visible_limit(average_data, limit)
	local visible_limit = limit or COMPACT_STANDINGS_STYLE.visible_limit
	if average_data and average_data.show_average then
		visible_limit = visible_limit - 1
	end
	return math.max(0, visible_limit)
end

local function select_compact_standings_entries(entries, average_data, config)
	config = config or {}
	local visible_limit = get_compact_standings_visible_limit(average_data, config.visible_limit)
	local display_entries = {}
	local pinned_entry = nil

	for index, entry in ipairs(entries or {}) do
		if config.pin_entry and not pinned_entry and config.pin_entry(entry) then
			pinned_entry = entry
		end
		if index <= visible_limit then
			display_entries[#display_entries + 1] = entry
		end
	end

	if pinned_entry and visible_limit > 0 then
		local pinned_visible = false
		for _, entry in ipairs(display_entries) do
			if entry == pinned_entry then
				pinned_visible = true
				break
			end
		end
		if not pinned_visible and #display_entries > 0 then
			display_entries[#display_entries] = pinned_entry
		end
	end

	return display_entries
end

local function get_pvp_score_rule()
	local config = MP.LOBBY and MP.LOBBY.config or {}
	local score_rule = config.pvp_score_rule
	if score_rule == "average" or score_rule == "median" or score_rule == "geometric" or score_rule == "custom" then
		return score_rule
	end
	return "highest"
end

local function get_score_rule_target_label(score_rule, is_team)
	if score_rule == "average" then
		return "AVERAGE", "AVG"
	elseif score_rule == "median" then
		return "MEDIAN", "MED"
	elseif score_rule == "geometric" then
		return "GEOMETRIC", "GEO"
	elseif score_rule == "custom" then
		return "CUSTOM", "TOP"
	end
	return nil, nil
end

local function calculate_median_score(scores)
	table.sort(scores, function(a, b)
		return MP.INSANE_INT.greater_than(b, a)
	end)

	local count = #scores
	if count <= 0 then
		return MP.INSANE_INT.empty()
	end

	local upper_middle = math.floor(count / 2) + 1
	if count % 2 == 1 then
		return scores[upper_middle]
	end

	return MP.INSANE_INT.divide_floor(MP.INSANE_INT.add(scores[upper_middle - 1], scores[upper_middle]), 2)
end

local function calculate_custom_cutoff_score(scores)
	table.sort(scores, function(a, b)
		return MP.INSANE_INT.greater_than(a, b)
	end)

	local winner_count = MP.UI.get_custom_winner_count and MP.UI.get_custom_winner_count() or math.ceil(#scores / 2)
	local cutoff_index = math.max(1, math.min(#scores, winner_count))
	return scores[cutoff_index] or MP.INSANE_INT.empty()
end

local function calculate_standings_score_target(entries, config)
	local score_rule = get_pvp_score_rule()
	local show_target = score_rule ~= "highest"
	local target_score = MP.INSANE_INT.empty()
	local total_hands = 0
	local score_key = config and config.score_key or "score_int"
	local hands_key = config and config.hands_key or "hands"
	local scores = {}

	if show_target and #entries > 0 then
		local total_score = MP.INSANE_INT.empty()
		for _, entry in ipairs(entries) do
			local score = entry[score_key] or MP.INSANE_INT.empty()
			scores[#scores + 1] = score
			total_score = MP.INSANE_INT.add(total_score, score)
			total_hands = total_hands + (entry[hands_key] or 0)
		end

		if score_rule == "average" then
			target_score = MP.INSANE_INT.divide_floor(total_score, #entries)
		elseif score_rule == "median" then
			target_score = calculate_median_score(scores)
		elseif score_rule == "geometric" then
			target_score = MP.INSANE_INT.geometric_mean(scores)
		elseif score_rule == "custom" then
			target_score = calculate_custom_cutoff_score(scores)
		end
	end

	local title, tag = get_score_rule_target_label(score_rule, config and config.is_team)
	return {
		show_average = show_target and #entries > 0,
		average_score = target_score,
		total_hands = total_hands,
		title = title,
		tag = tag,
		score_rule = score_rule,
	}
end

local function create_compact_standings_entry(entry, pvp_col)
	local palette_source = entry.palette_colour or pvp_col
	local palette = create_blind_style_palette and create_blind_style_palette(palette_source) or {}
	local body_source = entry.body_colour or pvp_col
	local far_right_source = entry.far_right_colour or body_source

	return create_compact_score_row({
		header_colour = palette.header or mix_colours(pvp_col, G.C.DYN_UI.MAIN, 0.35),
		body_colour = palette.body or mix_colours(body_source, G.C.BLACK, 0.62),
		left_slot_colour = G.C.CLEAR,
		left_slot_no_fill = true,
		left_align = "tm",
		left_padding = 0.0,
		header_left_colour = G.C.CLEAR,
		header_left_emboss = 0,
		header_left_no_fill = true,
		center_slot_colour = G.C.BLACK,
		right_slot_colour = G.C.BLACK,
		far_right_slot_colour = palette.right_slot or mix_colours(far_right_source, G.C.BLACK, 0.72),
		header_left_nodes = {
			create_rank_label(entry.rank, COMPACT_STANDINGS_STYLE.rank_text_scale, entry.rank_colour),
		},
		header_center_align = "cm",
		header_center_nodes = {
			create_text_label(entry.title or "Unknown", COMPACT_STANDINGS_STYLE.title_text_scale, entry.title_colour or G.C.UI.TEXT_LIGHT, nil, {
				outline_colour = entry.title_outline_colour,
				outline_offset = entry.title_outline_offset,
			}),
		},
		left_nodes = create_compact_blind_icon_nodes(entry.blind_player),
		center_nodes = {
			create_stat_text_label(
				get_entry_stat_display(entry, "lives", entry.lives),
				tostring(entry.lives or 0),
				COMPACT_STANDINGS_STYLE.stat_text_scale,
				G.C.RED,
				false
			),
		},
		right_nodes = {
			create_stat_text_label(
				get_entry_stat_display(entry, "hands", entry.hands),
				tostring(entry.hands or 0),
				COMPACT_STANDINGS_STYLE.stat_text_scale,
				G.C.BLUE,
				false
			),
		},
		far_right_nodes = {
			create_stake_score_box(
				entry.score_text or "0",
				COMPACT_STANDINGS_STYLE.score_box_w,
				COMPACT_STANDINGS_STYLE.score_text_scale,
				G.C.WHITE,
				0.52,
				0.44,
				entry.score_display
			),
		},
	})
end

local function create_compact_standings_nodes(config)
	local rows = {}
	local pvp_col = config.pvp_col or G.C.MULTIPLAYER or HEX("AC3232")
	local entries = config.entries or {}
	local average_data = config.average_data
	local panel_minw = config.panel_minw or COMPACT_STANDINGS_STYLE.panel_minw
	local display_entries = config.full_list and entries
		or config.display_entries
		or select_compact_standings_entries(entries, average_data, config)

	local page_entries = display_entries
	local page = 1
	local page_count = 1
	if config.full_list then
		local column_size = config.full_list_column_size or COMPACT_STANDINGS_STYLE.full_list_column_size
		local page_columns = config.full_list_page_columns or COMPACT_STANDINGS_STYLE.full_list_page_columns
		local page_size = math.max(1, page_columns * math.max(1, column_size))
		page_count = math.max(1, math.ceil(#display_entries / page_size))
		local runtime = MP.UI.get_player_list_runtime and MP.UI.get_player_list_runtime() or nil
		page = runtime and math.max(1, math.min(math.floor(tonumber(runtime.full_standings_page) or 1), page_count)) or 1
		if runtime then
			runtime.full_standings_page = page
			runtime.full_standings_page_count = page_count
		end
		local first_index = ((page - 1) * page_size) + 1
		local last_index = math.min(#display_entries, first_index + page_size - 1)
		page_entries = {}
		for idx = first_index, last_index do
			page_entries[#page_entries + 1] = display_entries[idx]
		end
	end

	local function mark_open_standings_row(row)
		if not config.full_list and row and row.config then
			row.config.mp_open_full_standings_row = true
		end
		return row
	end

	if average_data and average_data.show_average then
		rows[#rows + 1] = mark_open_standings_row(create_compact_average_score_row({
			pvp_col = pvp_col,
			title = average_data.title or config.average_title,
			tag = average_data.tag,
			average_key = config.average_key,
			total_hands = average_data.total_hands,
			average_score = average_data.average_score,
			header_darken = config.average_header_darken,
		}))
		rows[#rows + 1] = { n = G.UIT.R, config = { minh = 0.014 } }
	end

	if config.full_list then
		rows[#rows + 1] = create_full_list_columns(
			page_entries,
			config.create_entry,
			config.full_list_column_size or COMPACT_STANDINGS_STYLE.full_list_column_size,
			panel_minw
		)
		local pager = create_full_standings_pager(page, page_count)
		if pager then
			rows[#rows + 1] = pager
		end
	else
		append_spaced_stack_nodes(rows, display_entries, function(entry)
			return mark_open_standings_row(config.create_entry(entry))
		end)
	end

	local column_count = config.full_list
		and math.max(1, math.ceil(#page_entries / (config.full_list_column_size or COMPACT_STANDINGS_STYLE.full_list_column_size)))
		or 1
	local full_list_minw = panel_minw * column_count
		+ (COMPACT_STANDINGS_STYLE.full_list_column_gap * math.max(0, column_count - 1))

	return create_compact_stack_panel(
		rows,
		config.full_list and full_list_minw or panel_minw,
		not not config.full_list
	)
end

shared.create_compact_score_row = create_compact_score_row
shared.create_compact_average_score_row = create_compact_average_score_row
shared.create_compact_standings_entry = create_compact_standings_entry
shared.create_compact_standings_nodes = create_compact_standings_nodes
shared.create_compact_blind_icon_nodes = create_compact_blind_icon_nodes
shared.append_spaced_stack_nodes = append_spaced_stack_nodes
shared.create_compact_stack_panel = create_compact_stack_panel
shared.calculate_standings_average = calculate_standings_score_target
shared.get_compact_standings_visible_limit = get_compact_standings_visible_limit
shared.select_compact_standings_entries = select_compact_standings_entries
shared.COMPACT_STANDINGS_STYLE = COMPACT_STANDINGS_STYLE
