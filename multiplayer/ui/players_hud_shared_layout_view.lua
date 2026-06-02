MP.UI = MP.UI or {}
MP.UI.PLAYERS_HUD_SHARED = MP.UI.PLAYERS_HUD_SHARED or {}

local shared = MP.UI.PLAYERS_HUD_SHARED
local create_text_label = shared.create_text_label
local create_rank_label = shared.create_rank_label
local create_player_blind_icon_object = shared.create_player_blind_icon_object
local create_stake_score_box = shared.create_stake_score_box
local create_blind_style_palette = shared.create_blind_style_palette
local get_eased_score_display = shared.get_eased_score_display
local create_view_all_button_row = shared.create_view_all_button_row
local create_blind_style_row = shared.create_blind_style_row

shared.PVP_HUD_LAYOUT_REVISION = "pvp_hud_2026_05_21_shared_compact_selection"

local COMPACT_SCORE_ROW_DEFAULTS = {
	minw = 4.95,
	minh = 1.08,
	padding = 0.012,
	left_w = 0.72,
	center_w = 0.62,
	right_w = 0.62,
	right_minw = 0.62,
	far_right_w = 2.91,
	right_padding = 0.01,
	header_minh = 0.38,
	body_minh = 0.62,
	outer_inset = 0.0,
	inner_inset = 0.0,
	header_left_w = 0.64,
}

local COMPACT_STANDINGS_STYLE = {
	panel_minw = 4.95,
	visible_limit = 3,
	rank_text_scale = 0.29,
	stat_text_scale = 0.28,
	score_text_scale = 0.44,
	score_box_w = 2.87,
	full_list_column_size = 8,
	full_list_column_gap = 0.08,
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
			create_text_label(config.tag or "AVG", config.tag_scale or 0.22, G.C.UI.TEXT_LIGHT),
		},
		header_center_align = "cm",
		header_center_nodes = {
			create_text_label(config.title or "AVERAGE SCORE", config.title_scale or 0.3, G.C.UI.TEXT_LIGHT),
		},
		left_nodes = {
			create_text_label("-", config.placeholder_scale or 0.27, G.C.UI.TEXT_LIGHT),
		},
		center_nodes = {
			create_text_label("-", config.stat_scale or 0.28, G.C.RED, false),
		},
		right_nodes = {
			create_text_label(tostring(config.total_hands or 0), config.stat_scale or 0.28, G.C.BLUE, false),
		},
		far_right_nodes = {
			create_stake_score_box(
				average_score_display.text,
				config.score_box_w or 2.87,
				config.score_scale or 0.44,
				G.C.WHITE,
				config.score_minh or 0.46,
				config.stake_scale or 0.38,
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

local function calculate_standings_average(entries, config)
	local show_average = MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.ffa_scoring_beat_average
	local average_score = MP.INSANE_INT.empty()
	local total_hands = 0
	local score_key = config and config.score_key or "score_int"
	local hands_key = config and config.hands_key or "hands"

	if show_average and #entries > 0 then
		local total_score = MP.INSANE_INT.empty()
		for _, entry in ipairs(entries) do
			total_score = MP.INSANE_INT.add(total_score, entry[score_key] or MP.INSANE_INT.empty())
			total_hands = total_hands + (entry[hands_key] or 0)
		end
		average_score = MP.INSANE_INT.divide_floor(total_score, #entries)
	end

	return {
		show_average = show_average and #entries > 0,
		average_score = average_score,
		total_hands = total_hands,
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
		center_slot_colour = G.C.BLACK,
		right_slot_colour = G.C.BLACK,
		far_right_slot_colour = palette.right_slot or mix_colours(far_right_source, G.C.BLACK, 0.72),
		header_left_nodes = {
			create_rank_label(entry.rank, COMPACT_STANDINGS_STYLE.rank_text_scale, entry.rank_colour),
		},
		header_center_align = "cm",
		header_center_nodes = {
			create_text_label(entry.title or "Unknown", 0.3, entry.title_colour or G.C.UI.TEXT_LIGHT),
		},
		left_nodes = create_compact_blind_icon_nodes(entry.blind_player),
		center_nodes = {
			create_text_label(tostring(entry.lives or 0), COMPACT_STANDINGS_STYLE.stat_text_scale, G.C.RED, false),
		},
		right_nodes = {
			create_text_label(tostring(entry.hands or 0), COMPACT_STANDINGS_STYLE.stat_text_scale, G.C.BLUE, false),
		},
		far_right_nodes = {
			create_stake_score_box(
				entry.score_text or "0",
				COMPACT_STANDINGS_STYLE.score_box_w,
				COMPACT_STANDINGS_STYLE.score_text_scale,
				G.C.WHITE,
				0.46,
				0.38,
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

	if average_data and average_data.show_average then
		rows[#rows + 1] = create_compact_average_score_row({
			pvp_col = pvp_col,
			title = config.average_title,
			average_key = config.average_key,
			total_hands = average_data.total_hands,
			average_score = average_data.average_score,
			header_darken = config.average_header_darken,
		})
		rows[#rows + 1] = { n = G.UIT.R, config = { minh = 0.014 } }
	end

	if config.full_list then
		rows[#rows + 1] = create_full_list_columns(
			display_entries,
			config.create_entry,
			config.full_list_column_size or COMPACT_STANDINGS_STYLE.full_list_column_size,
			panel_minw
		)
	else
		append_spaced_stack_nodes(rows, display_entries, config.create_entry)
	end

	if not config.full_list and create_view_all_button_row then
		if #rows > 0 then
			rows[#rows + 1] = { n = G.UIT.R, config = { minh = 0.035 } }
		end
		rows[#rows + 1] = create_view_all_button_row(config.panel_minw or COMPACT_STANDINGS_STYLE.panel_minw)
	end

	local column_count = config.full_list
		and math.max(1, math.ceil(#display_entries / (config.full_list_column_size or COMPACT_STANDINGS_STYLE.full_list_column_size)))
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
shared.calculate_standings_average = calculate_standings_average
shared.get_compact_standings_visible_limit = get_compact_standings_visible_limit
shared.select_compact_standings_entries = select_compact_standings_entries
shared.COMPACT_STANDINGS_STYLE = COMPACT_STANDINGS_STYLE
