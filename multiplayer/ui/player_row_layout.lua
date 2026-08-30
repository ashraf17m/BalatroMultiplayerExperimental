MP.UI = MP.UI or {}
MP.UI.ROW_LAYOUT = MP.UI.ROW_LAYOUT or {}

local ROW_LAYOUT = MP.UI.ROW_LAYOUT
local Disableable_Button = MP.UI and MP.UI.Disableable_Button

local function get_hand_level_colour(level, fallback)
	return G.C.HAND_LEVELS and G.C.HAND_LEVELS[level] or fallback
end

function ROW_LAYOUT.append_node(nodes, node)
	if node then
		table.insert(nodes, node)
	end
end

function ROW_LAYOUT.create_row_chip(text, colour, minw, scale, text_colour, outlined)
	return {
		n = G.UIT.C,
		config = {
			align = "cm",
			padding = 0.02,
			r = 0.1,
			colour = colour,
			minw = minw or 1.1,
			maxw = minw or 1.1,
			outline = outlined and 0.8 or nil,
			outline_colour = outlined and G.C.WHITE or nil,
		},
		nodes = {
			{
				n = G.UIT.T,
				config = {
					text = text,
					scale = scale or 0.28,
					colour = text_colour or G.C.UI.TEXT_LIGHT,
					shadow = true,
				},
			},
		},
	}
end

local function create_compact_row_chip(text, colour, minw, scale, text_colour)
	return {
		n = G.UIT.C,
		config = {
			align = "cm",
			padding = 0.02,
			r = 0.1,
			colour = colour,
			minw = minw,
			maxw = minw,
		},
		nodes = {
			{
				n = G.UIT.T,
				config = {
					text = tostring(text or ""),
					scale = scale or 0.45,
					colour = text_colour or G.C.UI.TEXT_LIGHT,
					shadow = true,
					maxw = math.max(0.4, minw - 0.06),
				},
			},
		},
	}
end

function ROW_LAYOUT.create_lives_skips_lane(spec)
	local minw = spec.minw or 1.95
	local skip_minw = spec.skip_minw or 0.42
	local gap = spec.skip_gap or 0.03
	local lives_minw = math.max(0.8, minw - skip_minw - gap)

	return {
		n = G.UIT.C,
		config = {
			align = "cm",
			padding = 0,
			colour = G.C.CLEAR,
			minw = minw,
			maxw = minw,
			no_fill = true,
		},
		nodes = {
			create_compact_row_chip(
				spec.lives_text or spec.text,
				spec.colour or G.C.RED,
				lives_minw,
				spec.lives_scale or spec.scale or 0.45,
				spec.text_colour
			),
			{ n = G.UIT.B, config = { w = gap, h = 0.01 } },
			create_compact_row_chip(
				spec.skip_text,
				spec.skip_colour or G.C.PURPLE,
				skip_minw,
				spec.skip_scale or spec.scale or 0.45,
				spec.text_colour
			),
		},
	}
end

function ROW_LAYOUT.create_fixed_row_slot(node, minw, minh)
	local config = {
		align = "cm",
		padding = 0,
		colour = G.C.CLEAR,
		minw = minw,
		maxw = minw,
	}

	if minh then
		config.minh = minh
		config.maxh = minh
	end

	return {
		n = G.UIT.C,
		config = config,
		nodes = node and { node } or nil,
	}
end

function ROW_LAYOUT.append_row_slot(nodes, node, minw, minh)
	ROW_LAYOUT.append_node(nodes, { n = G.UIT.B, config = { w = 0.08, h = 0.01 } })
	ROW_LAYOUT.append_node(nodes, ROW_LAYOUT.create_fixed_row_slot(node, minw, minh))
end

function ROW_LAYOUT.create_player_row_shell(model, row_nodes, options)
	local opts = options or {}
	local config = {
		align = "cm",
		padding = 0.05,
		r = 0.1,
		colour = model.row_colour,
		emboss = 0.05,
	}

	if opts.tooltip_player_id then
		config.hover = true
		config.force_focus = opts.force_focus
		if config.force_focus == nil then
			config.force_focus = true
		end
		config.on_demand_tooltip = {
			text = { localize("k_mods_list") },
			filler = { func = MP.UI.create_UIBox_mods_list, args = opts.tooltip_player_id },
		}
	end

	return {
		n = G.UIT.R,
		config = config,
		nodes = row_nodes,
	}
end

function ROW_LAYOUT.create_name_lane(model)
	local name = tostring(model.username or model.player_name or "Guest")
	local lane_width = model.name_lane_minw or 4.0
	local name_maxw = math.max(0.4, lane_width - 0.18)
	local name_level = model.is_self and 5 or 1
	local name_colour = model.is_duels_nemesis and G.C.RED
		or get_hand_level_colour(name_level, model.is_self and G.C.ORANGE or G.C.BLUE)
	local name_text_colour = model.name_text_colour or G.C.UI.TEXT_DARK

	return {
		n = G.UIT.C,
		config = {
			align = "cm",
			padding = 0.01,
			r = 0.1,
			colour = name_colour,
			minw = lane_width,
			maxw = lane_width,
			minh = model.name_lane_minh or 0.42,
			outline = 0.8,
			outline_colour = G.C.WHITE,
		},
		nodes = {
			{
				n = G.UIT.T,
				config = {
					text = name,
					scale = 0.45,
					colour = name_text_colour,
					maxw = name_maxw,
				},
			},
		},
	}
end

function ROW_LAYOUT.create_skip_chip(spec)
	if not spec then
		return nil
	end

	return ROW_LAYOUT.create_row_chip(
		spec.text,
		spec.colour or G.C.PURPLE,
		spec.minw or 1.55,
		spec.scale or 0.38,
		spec.text_colour
	)
end

function ROW_LAYOUT.create_row_badge(model)
	local badge_colour = G.C.HAND_LEVELS and G.C.HAND_LEVELS[1] or G.C.BLUE

	return {
		n = G.UIT.C,
		config = {
			align = "cm",
			padding = 0.01,
			r = 0.1,
			colour = badge_colour,
			minw = 0.9,
			outline = 0.8,
			outline_colour = G.C.WHITE,
		},
		nodes = {
			{
				n = G.UIT.T,
				config = {
					text = tostring(model.index),
					scale = 0.5,
					colour = G.C.UI.TEXT_DARK,
				},
			},
		},
	}
end

function ROW_LAYOUT.create_host_chip(is_owner)
	if not is_owner then
		return nil
	end

	return ROW_LAYOUT.create_row_chip("HOST", G.C.ORANGE, 1.05, 0.45)
end

function ROW_LAYOUT.create_spectator_chip(is_spectator)
	if not is_spectator then
		return nil
	end

	return ROW_LAYOUT.create_row_chip("SPEC", G.C.PURPLE, 1.05, 0.45)
end

function ROW_LAYOUT.create_mod_lane(model)
	return {
		n = G.UIT.C,
		config = {
			align = "cm",
			padding = 0.05,
			colour = G.C.L_BLACK,
			r = 0.1,
			minw = 0.9,
		},
		nodes = {
			{
				n = G.UIT.T,
				config = {
					text = tostring(model.mod_count),
					scale = 0.42,
					colour = G.C.WHITE,
					shadow = true,
				},
			},
		},
	}
end

function ROW_LAYOUT.create_text_lane(text, minw, scale, text_colour)
	return {
		n = G.UIT.C,
		config = {
			align = "cm",
			padding = 0.05,
			colour = G.C.L_BLACK,
			r = 0.1,
			minw = minw,
			maxw = minw,
		},
		nodes = {
			{
				n = G.UIT.T,
				config = {
					text = tostring(text or ""),
					scale = scale or 0.45,
					colour = text_colour or G.C.UI.TEXT_LIGHT,
					shadow = true,
				},
			},
		},
	}
end

function ROW_LAYOUT.create_score_text_lane(spec)
	local shared = MP.UI and MP.UI.PLAYERS_HUD_SHARED or {}
	local minw = spec.minw
	if spec.show_stake_icon and shared.create_stake_score_box then
		return shared.create_stake_score_box(
			spec.text,
			minw,
			spec.scale,
			spec.text_colour,
			spec.minh,
			spec.stake_scale,
			spec.score_display
		)
	end

	local score_label = shared.create_score_text_label
		and shared.create_score_text_label(
			spec.score_display,
			spec.text,
			spec.scale,
			spec.text_colour,
			nil,
			math.max(0.6, (minw or 1) - 0.2)
		)
		or {
			n = G.UIT.T,
			config = {
				text = tostring(spec.text or ""),
				scale = spec.scale or 0.45,
				colour = spec.text_colour or G.C.UI.TEXT_LIGHT,
				shadow = true,
			},
		}

	return {
		n = G.UIT.C,
		config = {
			align = "cm",
			padding = 0.05,
			colour = G.C.L_BLACK,
			r = 0.1,
			minw = minw,
			maxw = minw,
		},
		nodes = {
			score_label,
		},
	}
end

function ROW_LAYOUT.create_location_lane(spec)
	local minw = spec.minw or 4.05
	local display = spec.display
		or (MP.UI and MP.UI.UTILS and MP.UI.UTILS.resolve_location_display
			and MP.UI.UTILS.resolve_location_display(spec.raw_location, spec.text))
		or {
			text = spec.text,
			full_text = spec.text,
		}
	local icon_size = spec.icon_size or 0.38
	local icon_object = (display.icon_kind or display.blind_key)
		and MP.UI
		and MP.UI.UTILS
		and MP.UI.UTILS.create_location_blind_icon_object
		and MP.UI.UTILS.create_location_blind_icon_object(display, icon_size)
		or nil
	local has_icon = icon_object ~= nil
	local text = has_icon and (display.text or "") or (display.full_text or display.text or spec.text or "")
	local scale = spec.scale or 0.45

	if not has_icon then
		return ROW_LAYOUT.create_text_lane(text, minw, scale, spec.text_colour)
	end

	return {
		n = G.UIT.C,
		config = {
			align = "cm",
			padding = 0.05,
			colour = G.C.L_BLACK,
			r = 0.1,
			minw = minw,
			maxw = minw,
		},
		nodes = {
			{
				n = G.UIT.R,
				config = {
					align = "cm",
					padding = 0,
					colour = G.C.CLEAR,
					minw = minw - 0.12,
					maxw = minw - 0.12,
					no_fill = true,
				},
				nodes = {
					{
						n = G.UIT.T,
						config = {
							text = tostring(text),
							scale = scale,
							colour = spec.text_colour or G.C.UI.TEXT_LIGHT,
							shadow = true,
							maxw = math.max(0.8, minw - icon_size - 0.3),
						},
					},
					{ n = G.UIT.B, config = { w = spec.icon_gap or 0.05, h = 0.01 } },
					{
						n = G.UIT.C,
						config = {
							align = "cm",
							padding = 0,
							colour = G.C.CLEAR,
							minw = icon_size,
							maxw = icon_size,
							minh = icon_size,
							maxh = icon_size,
							no_fill = true,
						},
						nodes = {
							{
								n = G.UIT.O,
								config = {
									object = icon_object,
									w = icon_size,
									h = icon_size,
									focus_with_object = false,
									can_collide = false,
								},
							},
						},
					},
				},
			},
		},
	}
end

function ROW_LAYOUT.create_button_from_spec(spec)
	if not spec then
		return nil
	end

	local button_args = {
		id = spec.id,
		button = spec.button,
		label = type(spec.label) == "table" and spec.label or { spec.label },
		disabled_text = spec.disabled_text
			and (type(spec.disabled_text) == "table" and spec.disabled_text or { spec.disabled_text })
			or nil,
		minw = spec.minw,
		minh = spec.minh,
		scale = spec.scale,
		colour = spec.colour,
		text_colour = spec.text_colour,
		shadow = spec.shadow == nil and false or spec.shadow,
		tooltip = spec.tooltip,
		chosen = spec.chosen,
		col = spec.col == nil and true or spec.col,
		enabled_ref_table = spec.enabled_ref_table,
		enabled_ref_value = spec.enabled_ref_value,
	}

	if spec.disableable and Disableable_Button then
		return Disableable_Button(button_args)
	end

	return UIBox_button(button_args)
end

function ROW_LAYOUT.create_action_button_from_spec(action)
	if not action then
		return nil
	end

	return ROW_LAYOUT.create_button_from_spec({
		id = action.id,
		button = action.button,
		label = action.label,
		minw = action.minw or 0.65,
		minh = action.minh or 0.42,
		scale = action.scale or 0.45,
		colour = action.colour,
		text_colour = action.text_colour,
		disabled_text = action.disabled_text,
		shadow = action.shadow,
		tooltip = action.tooltip,
		chosen = action.chosen,
		col = action.col,
		disableable = action.disableable,
		enabled_ref_table = action.enabled_ref_table,
		enabled_ref_value = action.enabled_ref_value,
	})
end

function ROW_LAYOUT.create_surface_lane_from_spec(spec)
	if not spec then
		return nil
	end

	if spec.kind == "action" then
		return ROW_LAYOUT.create_action_button_from_spec(spec)
	end

	if spec.kind == "text_lane" then
		return ROW_LAYOUT.create_text_lane(
			spec.text,
			spec.minw,
			spec.scale,
			spec.text_colour
		)
	end

	if spec.kind == "lives_skips_lane" then
		return ROW_LAYOUT.create_lives_skips_lane(spec)
	end

	if spec.kind == "score_lane" then
		return ROW_LAYOUT.create_score_text_lane(spec)
	end

	if spec.kind == "location_lane" then
		return ROW_LAYOUT.create_location_lane(spec)
	end

	return ROW_LAYOUT.create_row_chip(
		spec.text,
		spec.colour,
		spec.minw,
		spec.scale,
		spec.text_colour,
		spec.outlined
	)
end

function ROW_LAYOUT.append_surface_lane_slot(nodes, spec, default_minw, default_minh)
	if not spec then
		if default_minw then
			ROW_LAYOUT.append_row_slot(nodes, nil, default_minw, default_minh)
		end
		return
	end

	ROW_LAYOUT.append_row_slot(
		nodes,
		ROW_LAYOUT.create_surface_lane_from_spec(spec),
		spec.slot_minw or spec.minw or default_minw,
		spec.slot_minh or default_minh
	)
end

function ROW_LAYOUT.create_button_rows_from_specs(row_specs)
	local rows = {}

	for _, row_spec in ipairs(row_specs or {}) do
		local row_nodes = {}
		local buttons = row_spec.buttons or {}
		local gap = row_spec.gap or 0.08

		for button_idx, button_spec in ipairs(buttons) do
			ROW_LAYOUT.append_node(row_nodes, ROW_LAYOUT.create_button_from_spec(button_spec))
			if button_idx < #buttons then
				ROW_LAYOUT.append_node(row_nodes, { n = G.UIT.B, config = { w = gap, h = 0.01 } })
			end
		end

		ROW_LAYOUT.append_node(rows, {
			n = G.UIT.R,
			config = { align = "cm", padding = row_spec.padding or 0.05 },
			nodes = row_nodes,
		})
	end

	return rows
end
