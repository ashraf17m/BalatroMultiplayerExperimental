MP.UI = MP.UI or {}
MP.UI.PLAYERS_HUD_SHARED = MP.UI.PLAYERS_HUD_SHARED or {}

local shared = MP.UI.PLAYERS_HUD_SHARED
local create_text_label = shared.create_text_label
local create_player_blind_icon_object = shared.create_player_blind_icon_object

local function create_thin_button(button, label, colour, minw, disabled)
	local button_colour = disabled and darken(colour, 0.6) or colour
	return {
		n = G.UIT.R,
		config = {
			align = "cm",
			padding = 0.03,
			minw = minw or 1.65,
			minh = 0.34,
			r = 0.11,
			colour = button_colour,
			emboss = 0.06,
			shadow = true,
			hover = true,
			button = disabled and nil or button,
		},
		nodes = {
			create_text_label(label, 0.27, disabled and G.C.UI.TEXT_INACTIVE or G.C.WHITE, false),
		},
	}
end

local function create_view_all_button_row(row_minw)
	local pvp_col = G.C.MULTIPLAYER or HEX("AC3232")
	return {
		n = G.UIT.R,
		config = {
			align = "cm",
			minw = row_minw or 4.7,
			padding = 0,
			no_fill = true,
		},
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm", padding = 0, no_fill = true },
				nodes = {
					create_thin_button(
						"mp_open_full_standings",
						localize("b_view_all"),
						mix_colours(G.C.ORANGE, pvp_col, 0.42),
						2.18,
						false
					),
				},
			},
		},
	}
end

local function create_floating_icon_anchor(player, size, offset, id)
	local icon_size = size or 0.56
	return {
		n = G.UIT.C,
		config = {
			align = "cm",
			minw = math.max(0.46, icon_size * 0.9),
			minh = icon_size,
			padding = 0,
			offset = offset or { x = -0.1, y = -0.01 },
			no_fill = true,
		},
		nodes = {
			{
				n = G.UIT.O,
				config = {
					id = id,
					w = icon_size,
					h = icon_size,
					object = create_player_blind_icon_object(player, icon_size),
					focus_with_object = false,
				},
			},
		},
	}
end

local function create_blind_style_body_slot(align, minw, minh, padding, colour, nodes, no_fill)
	return {
		n = G.UIT.C,
		config = {
			align = align,
			minw = minw,
			minh = minh,
			padding = padding,
			r = 0.1,
			colour = colour,
			no_fill = no_fill,
			shadow = false,
		},
		nodes = nodes or {},
	}
end

local function create_blind_style_row(config)
	local header_colour = config.header_colour or (G.C.MULTIPLAYER or G.C.DYN_UI.MAIN)
	local body_colour = config.body_colour or mix_colours(header_colour, G.C.BLACK, 0.52)
	local left_slot_colour = config.left_slot_colour or G.C.BLACK
	local center_slot_colour = config.center_slot_colour or G.C.BLACK
	local right_slot_colour = config.right_slot_colour or G.C.BLACK
	local far_right_slot_colour = config.far_right_slot_colour or G.C.BLACK
	local left_align = config.left_align or "cm"
	local left_padding = config.left_padding or 0.01
	local left_slot_no_fill = config.left_slot_no_fill or false
	local title_text = config.title or "PLAYER"
	local title_scale = config.title_scale or 0.34
	local row_width = config.minw or 5.8
	local row_height = config.minh or 1.22
	local row_padding = config.padding or 0.015
	local outer_inset = config.outer_inset or 0.06
	local inner_inset = config.inner_inset or 0.08
	local inner_width = row_width - outer_inset
	local lane_width = inner_width - inner_inset
	local header_height = config.header_minh or 0.34
	local body_height = config.body_minh or (row_height - (header_height + 0.16))
	local body_slot_height = math.max(0.25, body_height - 0.04)
	local left_width = config.left_w or 1.05
	local center_width = config.center_w or 0.94
	local far_right_width = (config.far_right_nodes and (config.far_right_w or 0.68)) or 0
	local right_width = config.right_w or (row_width - left_width - center_width - far_right_width - 0.32)
	local right_minw = config.right_minw or 1.2
	local right_padding = config.right_padding or 0.015
	local header_left_w = (config.header_left_nodes and (config.header_left_w or 0.6)) or 0
	local header_right_w = (config.header_right_nodes and (config.header_right_w or 0.6)) or 0
	local header_center_nodes = config.header_center_nodes
		or {
			create_text_label(title_text, title_scale, G.C.UI.TEXT_LIGHT),
		}
	local header_nodes = config.header_nodes
	if not header_nodes and (config.header_left_nodes or config.header_right_nodes) then
		header_nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm", minw = header_left_w, padding = 0.005, no_fill = true },
				nodes = config.header_left_nodes or {},
			},
			{
				n = G.UIT.C,
				config = { align = config.header_center_align or "cl", minw = math.max(0.8, lane_width - header_left_w - header_right_w), padding = 0.005, no_fill = true },
				nodes = header_center_nodes,
			},
			{
				n = G.UIT.C,
				config = { align = "cr", minw = header_right_w, padding = 0.005, no_fill = true },
				nodes = config.header_right_nodes or {},
			},
		}
	elseif not header_nodes then
		header_nodes = header_center_nodes
	end

	return {
		n = G.UIT.R,
		config = {
			align = config.row_align or "cm",
			minw = row_width,
			minh = row_height,
			padding = row_padding,
			r = config.outer_r or 0.08,
			colour = config.outer_colour or G.C.BLACK,
			emboss = config.outer_emboss or 0.03,
			shadow = false,
			no_fill = false,
			outline = config.outer_outline,
			outline_colour = config.outer_outline_colour,
			on_demand_tooltip = config.on_demand_tooltip,
		},
		nodes = {
			{
				n = G.UIT.C,
				config = {
					align = "tm",
					minw = inner_width,
					padding = 0.005,
					no_fill = true,
				},
				nodes = {
					{
						n = G.UIT.R,
						config = {
							align = "cm",
							minw = lane_width,
							minh = header_height,
							padding = 0.008,
							r = 0.1,
							colour = header_colour,
							emboss = 0.05,
							shadow = false,
						},
						nodes = header_nodes,
					},
					{
						n = G.UIT.R,
						config = {
							align = "cm",
							minw = lane_width,
							minh = math.max(0.3, body_height),
							padding = 0.01,
							r = 0.1,
							colour = body_colour,
							shadow = false,
							emboss = 0.02,
						},
						nodes = {
							create_blind_style_body_slot(
								left_align,
								left_width,
								body_slot_height,
								left_padding,
								left_slot_colour,
								config.left_nodes or {},
								left_slot_no_fill
							),
							create_blind_style_body_slot(
								"cm",
								center_width,
								body_slot_height,
								0.01,
								center_slot_colour,
								config.center_nodes or {}
							),
							create_blind_style_body_slot(
								config.right_align or "cm",
								math.max(right_minw, right_width),
								body_slot_height,
								right_padding,
								right_slot_colour,
								config.right_nodes or {}
							),
							(config.far_right_nodes and create_blind_style_body_slot(
								"cm",
								far_right_width,
								body_slot_height,
								0.01,
								far_right_slot_colour,
								config.far_right_nodes
							)) or nil,
						},
					},
				},
			},
		},
	}
end

shared.create_thin_button = create_thin_button
shared.create_view_all_button_row = create_view_all_button_row
shared.create_floating_icon_anchor = create_floating_icon_anchor
shared.create_blind_style_row = create_blind_style_row
