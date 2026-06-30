local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local ACTION_BUTTON_WIDTH = 2.15
local ACTION_BUTTON_HEIGHT = 0.7
local ACTION_TEXT_SCALE = 0.42
local TARGET_CYCLE_NAME_WIDTH = 2.4
local TARGET_CYCLE_ARROW_WIDTH = 0.6
local TARGET_CYCLE_GAP = 0.08
local TARGET_CYCLE_TEXT_SCALE = 0.42
local VOUCHER_POPUP_CARD_SCALE = 0.48
local VOUCHER_POPUP_OVERLAP = 0.82
local VOUCHER_POPUP_MAX_PER_ROW = 8
local VOUCHER_POPUP_ROW_GAP = 0.08

local function create_end_game_action_spacer(has_won)
	local width = has_won and 0.4 or 0.5
	return {
		n = G.UIT.C,
		config = {
			maxw = width,
			minw = width,
			minh = 0.7,
			colour = G.C.CLEAR,
			no_fill = false,
		},
	}
end

local function create_end_game_action_text_button(button, text, id, focus_args)
	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.02, colour = G.C.CLEAR },
		nodes = {
			{
				n = G.UIT.R,
				config = {
					id = id,
					button = button,
					align = "cm",
					padding = 0.05,
					colour = G.C.BLUE,
					emboss = 0.1,
					minw = ACTION_BUTTON_WIDTH,
					maxw = ACTION_BUTTON_WIDTH,
					minh = ACTION_BUTTON_HEIGHT,
					maxh = ACTION_BUTTON_HEIGHT,
					r = 0.1,
					shadow = true,
					hover = true,
					can_collide = true,
					focus_args = focus_args,
				},
				nodes = {
					{
						n = G.UIT.O,
						config = {
							object = DynaText({
								string = { text },
								colours = { G.C.UI.TEXT_LIGHT },
								pop_in = 0,
								pop_in_rate = 8,
								reset_pop_in = true,
								shadow = true,
								float = true,
								silent = true,
								bump = true,
								scale = ACTION_TEXT_SCALE,
								maxw = ACTION_BUTTON_WIDTH - 0.1,
								non_recalc = true,
							}),
						},
					},
				},
			},
		},
	}
end

local function create_end_game_action_button(button, label_key, id, focus_args)
	return create_end_game_action_text_button(button, localize(label_key), id, focus_args)
end

local function create_end_game_named_action_button(button, label, id, focus_args)
	local text = tostring(label or "")
	if text == "" then text = "You" end

	return create_end_game_action_text_button(button, text, id, focus_args)
end

local function create_end_game_cycle_gap()
	return {
		n = G.UIT.C,
		config = {
			align = "cm",
			minw = TARGET_CYCLE_GAP,
			maxw = TARGET_CYCLE_GAP,
			colour = G.C.CLEAR,
		},
	}
end

local function create_end_game_target_cycle(screen_state, view_target_index, viewable_players)
	local has_compare_target = #viewable_players > 0
	local cycle_config = {
		options = screen_state.target_options,
		current_option = view_target_index or 1,
		opt_callback = has_compare_target and "change_end_game_view_target" or nil,
	}
	cycle_config.current_option_val = cycle_config.options[cycle_config.current_option]
	local arrows_disabled = #cycle_config.options < 2

	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.02, colour = G.C.CLEAR },
		nodes = {
			{
				n = G.UIT.R,
				config = { id = "end_game_view_target_cycle", align = "cm", colour = G.C.CLEAR, padding = 0 },
				nodes = {
					{
						n = G.UIT.C,
						config = {
							align = "cm",
							r = 0.1,
							minw = TARGET_CYCLE_ARROW_WIDTH,
							maxw = TARGET_CYCLE_ARROW_WIDTH,
							minh = ACTION_BUTTON_HEIGHT,
							maxh = ACTION_BUTTON_HEIGHT,
							hover = not arrows_disabled,
							colour = not arrows_disabled and G.C.BLUE or G.C.BLACK,
							shadow = not arrows_disabled,
							button = not arrows_disabled and "option_cycle" or nil,
							ref_table = cycle_config,
							ref_value = "l",
							focus_args = { type = "none" },
						},
						nodes = {
							{
								n = G.UIT.T,
								config = {
									text = "<",
									scale = TARGET_CYCLE_TEXT_SCALE,
									colour = not arrows_disabled and G.C.UI.TEXT_LIGHT or G.C.UI.TEXT_INACTIVE,
								},
							},
						},
					},
					create_end_game_cycle_gap(),
					{
						n = G.UIT.C,
						config = {
							id = "cycle_main",
							align = "cm",
							minw = TARGET_CYCLE_NAME_WIDTH,
							maxw = TARGET_CYCLE_NAME_WIDTH,
							minh = ACTION_BUTTON_HEIGHT,
							maxh = ACTION_BUTTON_HEIGHT,
							r = 0.1,
							padding = 0.05,
							colour = has_compare_target and G.C.BLUE or G.C.BLACK,
							emboss = 0.1,
							hover = has_compare_target,
							shadow = has_compare_target,
							can_collide = has_compare_target,
							button = has_compare_target and "return_to_end_game_compare_target" or nil,
						},
						nodes = {
							{
								n = G.UIT.O,
								config = {
									object = DynaText({
										string = { { ref_table = cycle_config, ref_value = "current_option_val" } },
										colours = { G.C.UI.TEXT_LIGHT },
										pop_in = 0,
										pop_in_rate = 8,
										reset_pop_in = true,
										shadow = true,
										float = true,
										silent = true,
										bump = true,
										scale = TARGET_CYCLE_TEXT_SCALE,
										maxw = TARGET_CYCLE_NAME_WIDTH - 0.1,
										non_recalc = true,
									}),
								},
							},
						},
					},
					create_end_game_cycle_gap(),
					{
						n = G.UIT.C,
						config = {
							align = "cm",
							r = 0.1,
							minw = TARGET_CYCLE_ARROW_WIDTH,
							maxw = TARGET_CYCLE_ARROW_WIDTH,
							minh = ACTION_BUTTON_HEIGHT,
							maxh = ACTION_BUTTON_HEIGHT,
							hover = not arrows_disabled,
							colour = not arrows_disabled and G.C.BLUE or G.C.BLACK,
							shadow = not arrows_disabled,
							button = not arrows_disabled and "option_cycle" or nil,
							ref_table = cycle_config,
							ref_value = "r",
							focus_args = { type = "none" },
						},
						nodes = {
							{
								n = G.UIT.T,
								config = {
									text = ">",
									scale = TARGET_CYCLE_TEXT_SCALE,
									colour = not arrows_disabled and G.C.UI.TEXT_LIGHT or G.C.UI.TEXT_INACTIVE,
								},
							},
						},
					},
				},
			},
		},
	}
end

local function create_end_game_stat_gap(row)
	return {
		n = row and G.UIT.R or G.UIT.C,
		config = row
			and { align = "cm", minh = 0.08, maxh = 0.08, colour = G.C.CLEAR }
			or { align = "cm", minw = 0.08, maxw = 0.08, colour = G.C.CLEAR },
		nodes = {},
	}
end

local function resolve_voucher_center_key(value)
	local raw_key = tostring(value or "")
	if raw_key == "" then return nil end

	if G.P_CENTERS and G.P_CENTERS[raw_key] then
		return raw_key
	end

	local prefixed_key = raw_key:sub(1, 2) == "v_" and raw_key or "v_" .. raw_key
	if G.P_CENTERS and G.P_CENTERS[prefixed_key] then
		return prefixed_key
	end

	local lower_key = raw_key:lower()
	for center_key, center in pairs(G.P_CENTERS or {}) do
		if center and center.set == "Voucher" then
			local center_name = tostring(center.name or "")
			local center_label = tostring(center.label or "")
			if center_name == raw_key or center_label == raw_key then
				return center_key
			end
			if center_name:lower() == lower_key or center_label:lower() == lower_key then
				return center_key
			end
		end
	end

	return nil
end

local function get_valid_voucher_keys(vouchers)
	local keys = {}
	for _, key in ipairs(vouchers or {}) do
		local resolved_key = resolve_voucher_center_key(key)
		if resolved_key then keys[#keys + 1] = resolved_key end
	end
	return keys
end

local function get_voucher_card_dimensions()
	local card_w = G.CARD_W * VOUCHER_POPUP_CARD_SCALE
	local card_h = G.CARD_H * VOUCHER_POPUP_CARD_SCALE
	return card_w, card_h
end

local function get_voucher_row_width(voucher_count)
	local card_w = G.CARD_W * VOUCHER_POPUP_CARD_SCALE
	return card_w + math.max(voucher_count - 1, 0) * card_w * VOUCHER_POPUP_OVERLAP
end

local function get_voucher_popup_dimensions(voucher_count)
	local _, card_h = get_voucher_card_dimensions()
	local row_count = math.max(math.ceil(math.max(voucher_count, 1) / VOUCHER_POPUP_MAX_PER_ROW), 1)
	local widest_row_count = math.min(math.max(voucher_count, 1), VOUCHER_POPUP_MAX_PER_ROW)
	local width = get_voucher_row_width(widest_row_count)
	local height = row_count * card_h + math.max(row_count - 1, 0) * VOUCHER_POPUP_ROW_GAP
	return width, height
end

local function get_voucher_popup_rows(vouchers)
	local valid_vouchers = get_valid_voucher_keys(vouchers)
	local rows = {}

	for index, key in ipairs(valid_vouchers) do
		local row_index = math.floor((index - 1) / VOUCHER_POPUP_MAX_PER_ROW) + 1
		rows[row_index] = rows[row_index] or {}
		rows[row_index][#rows[row_index] + 1] = key
	end

	return rows, valid_vouchers
end

local function create_end_game_mp_stat_row(id, label_key, value, text_colour, args)
	args = args or {}
	local value_text = tostring(value or "")
	local ref_table = args.ref_table
	local ref_value = args.ref_value
	local value_scale = args.value_scale or math.max(0.32, math.min(0.5, 0.62 - 0.018 * #value_text))
	local label_width = args.label_width or 2.9
	local value_width = args.value_width or 1
	local value_maxw = args.value_maxw or math.max(value_width - 0.05, 0.95)
	local value_nodes = {}
	for _, node in ipairs(args.value_prefix_nodes or {}) do
		value_nodes[#value_nodes + 1] = node
	end
	value_nodes[#value_nodes + 1] = {
		n = G.UIT.O,
		config = {
			object = DynaText({
				string = { ref_table and ref_value and { ref_table = ref_table, ref_value = ref_value } or value_text },
				colours = { text_colour or G.C.FILTER },
				shadow = true,
				float = true,
				scale = value_scale,
				maxw = value_maxw,
			}),
		},
	}
	local row_config = {
		align = "cm",
		padding = 0.05,
		r = 0.1,
		colour = darken(G.C.JOKER_GREY, 0.1),
		emboss = 0.05,
		id = id,
	}

	return {
		n = G.UIT.R,
		config = row_config,
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm", padding = 0.02, minw = label_width, maxw = label_width },
				nodes = {
					{
						n = G.UIT.T,
						config = {
							text = localize(label_key),
							scale = 0.4,
							maxw = math.max(label_width - 0.1, 0.9),
							colour = G.C.UI.TEXT_LIGHT,
							shadow = true,
						},
					},
				},
			},
			{
				n = G.UIT.C,
				config = { align = "cr" },
				nodes = {
					{
						n = G.UIT.C,
						config = {
							align = "cm",
							minh = 0.5,
							r = 0.1,
							minw = value_width,
							maxw = value_width,
							colour = G.C.BLACK,
							emboss = 0.05,
						},
						nodes = {
							{
								n = G.UIT.C,
								config = { align = "cm", padding = 0.05, r = 0.1, minw = value_width, maxw = value_width },
								nodes = value_nodes,
							},
						},
					},
				},
			},
		},
	}
end

local function create_end_game_summary_stat_row(score, display, text_colour, args)
	args = args or {}
	local label_key = args.label_key or "ph_score_" .. score
	return create_end_game_mp_stat_row(score, label_key, display and display[score] or "", text_colour, {
		ref_table = display,
		ref_value = score,
		label_width = args.label_width,
		value_width = args.value_width,
		value_scale = args.value_scale,
		value_maxw = args.value_maxw,
		value_prefix_nodes = args.value_prefix_nodes,
	})
end

local function create_end_game_chip_prefix_node()
	local chip_sprite = Sprite(0, 0, 0.3, 0.3, G.ASSET_ATLAS["ui_" .. (G.SETTINGS.colourblind_option and 2 or 1)], { x = 0, y = 0 })
	chip_sprite.states.drag.can = false
	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.02 },
		nodes = {
			{ n = G.UIT.O, config = { w = 0.3, h = 0.3, object = chip_sprite } },
		},
	}
end

local function create_end_game_voucher_card_area(vouchers)
	local valid_vouchers = get_valid_voucher_keys(vouchers)
	local card_w, card_h = get_voucher_card_dimensions()
	local width = get_voucher_row_width(#valid_vouchers)
	local card_area = CardArea(
		0,
		0,
		width,
		card_h,
		{
			card_limit = math.max(#valid_vouchers, 1),
			type = "title",
			highlight_limit = 0,
			card_w = card_w,
		}
	)

	for _, key in ipairs(valid_vouchers) do
		local center = G.P_CENTERS[key]
		local card = Card(
			card_area.T.x + card_area.T.w / 2,
			card_area.T.y,
			card_w,
			card_h,
			G.P_CARDS.empty,
			center,
			{ bypass_discovery_center = true, bypass_discovery_ui = true }
		)
		card.states.drag.can = false
		card.states.click.can = false
		card.states.hover.can = false
		card.states.collide.can = false
		card:hard_set_T()
		card_area:emplace(card)
	end

	return card_area
end

local function create_end_game_voucher_popup_definition(vouchers)
	local voucher_rows, valid_vouchers = get_voucher_popup_rows(vouchers)
	local width, height = get_voucher_popup_dimensions(#valid_vouchers)
	local _, card_h = get_voucher_card_dimensions()
	local row_nodes = {}

	if #voucher_rows == 0 then voucher_rows[1] = {} end

	for row_index, row_vouchers in ipairs(voucher_rows) do
		row_nodes[#row_nodes + 1] = {
			n = G.UIT.R,
			config = { align = "cm", padding = 0.01, colour = G.C.CLEAR, minw = width, minh = card_h },
			nodes = {
				{ n = G.UIT.O, config = { object = create_end_game_voucher_card_area(row_vouchers) } },
			},
		}

		if row_index < #voucher_rows then
			row_nodes[#row_nodes + 1] = {
				n = G.UIT.R,
				config = { align = "cm", colour = G.C.CLEAR, minw = width, minh = VOUCHER_POPUP_ROW_GAP, maxh = VOUCHER_POPUP_ROW_GAP },
				nodes = {},
			}
		end
	end

	return {
		n = G.UIT.ROOT,
		config = {
			align = "cm",
			padding = 0.08,
			r = 0.12,
			minw = width + 0.16,
			minh = height + 0.16,
			colour = darken(G.C.JOKER_GREY, 0.1),
			outline = 1.5,
			outline_colour = G.C.WHITE,
			line_emboss = 0.5,
			emboss = 0.05,
		},
		nodes = row_nodes,
	}
end

local function close_end_game_voucher_popup(anchor)
	local closed = false
	if anchor and anchor.children and anchor.children.h_popup then
		anchor.children.h_popup:remove()
		anchor.children.h_popup = nil
		closed = true
	end

	if anchor and anchor.config then
		anchor.config.h_popup = nil
		anchor.config.h_popup_config = nil
	end

	if G and G.mp_end_game_voucher_ui then
		if G.mp_end_game_voucher_ui.remove then G.mp_end_game_voucher_ui:remove() end
		G.mp_end_game_voucher_ui = nil
		G.mp_end_game_voucher_ui_anchor = nil
		closed = true
	end

	return closed
end

local function open_end_game_voucher_popup(anchor)
	local vouchers = anchor and anchor.config and anchor.config.mp_vouchers_bought or {}
	if not (anchor and UIBox and #get_valid_voucher_keys(vouchers) > 0) then
		close_end_game_voucher_popup(anchor)
		return false
	end

	if anchor.children and anchor.children.h_popup then return true end

	anchor.config.h_popup = create_end_game_voucher_popup_definition(vouchers)
	anchor.config.h_popup_config = {
		align = anchor.T.y > G.ROOM.T.h / 2 and "tm" or "bm",
		offset = { x = 0, y = anchor.T.y > G.ROOM.T.h / 2 and -0.12 or 0.12 },
		parent = anchor,
	}
	if Node and Node.hover then
		Node.hover(anchor)
	end
	return true
end

BALATRO.set_ui_function("mp_setup_end_game_voucher_popup", function(e)
	if not (e and e.config) then return end
	e.config.func = nil
	if e.config.mp_voucher_popup_installed then return end
	e.config.mp_voucher_popup_installed = true
	e.config.hover = true
	e.config.force_focus = true

	if e.states then
		if e.states.collide then e.states.collide.can = true end
		if e.states.hover then e.states.hover.can = true end
	end

	local old_hover = e.hover
	function e:hover(...)
		if old_hover then old_hover(self, ...) end
		open_end_game_voucher_popup(self)
	end

	local old_stop_hover = e.stop_hover
	function e:stop_hover(...)
		if old_stop_hover then old_stop_hover(self, ...) end
		close_end_game_voucher_popup(self)
	end

	local old_remove = e.remove
	function e:remove(...)
		close_end_game_voucher_popup(self)
		if old_remove then old_remove(self, ...) end
	end
end)

BALATRO.set_ui_function("mp_copy_end_game_seed", function()
	local end_game_view = MP.UI and MP.UI.get_end_game_view_runtime and MP.UI.get_end_game_view_runtime() or nil
	local seed = end_game_view
		and end_game_view.summary_display
		and end_game_view.summary_display.seed
		or G.GAME and G.GAME.pseudorandom and G.GAME.pseudorandom.seed
		or ""
	if G.F_LOCAL_CLIPBOARD then
		G.CLIPBOARD = seed
	else
		love.system.setClipboardText(seed)
	end
end)

local function create_end_game_vouchers_stat_row(display)
	local vouchers = display and display.vouchers_bought or {}
	local row = create_end_game_mp_stat_row(
		"mp_vouchers_bought",
		"k_mp_end_vouchers_bought",
		display and display.vouchers_bought_count or number_format(#get_valid_voucher_keys(vouchers)),
		G.C.SECONDARY_SET and G.C.SECONDARY_SET.Voucher or G.C.PURPLE,
		{
			ref_table = display,
			ref_value = "vouchers_bought_count",
		}
	)
	row.config.func = "mp_setup_end_game_voucher_popup"
	row.config.insta_func = true
	row.config.hover = true
	row.config.can_collide = true
	row.config.force_focus = true
	row.config.mp_vouchers_bought = vouchers
	return row
end

local function create_end_game_secondary_stats(display)
	return {
		n = G.UIT.R,
		config = { align = "cm" },
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm" },
				nodes = {
					create_end_game_summary_stat_row("cards_purchased", display, G.C.MONEY),
					create_end_game_stat_gap(true),
					create_end_game_vouchers_stat_row(display),
					create_end_game_stat_gap(true),
					create_end_game_summary_stat_row("times_rerolled", display, G.C.GREEN),
					create_end_game_stat_gap(true),
					create_end_game_mp_stat_row(
						"mp_total_money_spent",
						"k_mp_end_total_spend",
						display and display.total_money_spent or localize("$") .. "0",
						G.C.MONEY,
						{
							ref_table = display,
							ref_value = "total_money_spent",
						}
					),
				},
			},
			create_end_game_stat_gap(false),
			{
				n = G.UIT.C,
				config = { align = "cm" },
				nodes = {
					create_end_game_summary_stat_row("furthest_ante", display, G.C.FILTER, { label_key = "k_ante", label_width = 1.9 }),
					create_end_game_stat_gap(true),
					create_end_game_summary_stat_row("furthest_round", display, G.C.FILTER, { label_key = "k_round", label_width = 1.9 }),
					create_end_game_stat_gap(true),
					create_end_game_mp_stat_row(
						"mp_reroll_money_spent",
						"k_mp_end_reroll_spend",
						display and display.reroll_money_spent or localize("$") .. "0",
						G.C.GREEN,
						{
							ref_table = display,
							ref_value = "reroll_money_spent",
						}
					),
				},
			},
		},
	}
end

local function create_end_game_kofi_button()
	return {
		n = G.UIT.R,
		config = {
			id = "ko-fi_button",
			align = "cm",
			padding = 0.1,
			r = 0.1,
			hover = true,
			colour = HEX("72A5F2"),
			button = "open_kofi",
			shadow = true,
			minw = 4.8,
			maxw = 4.8,
		},
		nodes = {
			{
				n = G.UIT.R,
				config = {
					align = "cm",
					padding = 0,
					no_fill = true,
					maxw = 4.7,
				},
				nodes = {
					{
						n = G.UIT.O,
						config = {
							object = DynaText({
								string = { localize("b_mp_kofi_button") },
								colours = { G.C.UI.TEXT_LIGHT },
								shadow = true,
								float = true,
								silent = true,
								scale = 0.32,
								maxw = 4.6,
								non_recalc = true,
							}),
						},
					},
				},
			},
		},
	}
end

local function get_end_game_screen_style(has_won)
	local result = MP.GAME and MP.GAME.end_game_result
	local is_abandoned = result == "abandoned" or result == "alone"
	if is_abandoned then
		return {
			win_like = false,
			title = "MATCH ABANDONED",
			title_colour = G.C.BLUE,
			background_colour = G.C.BLUE,
			background_alpha = 0.55,
			panel_colour = nil,
			outline_colour = nil,
			spacing = 2,
			rotate = false,
		}
	end

	if has_won then
		return {
			win_like = true,
			title = localize("ph_you_win"),
			title_colour = G.C.EDITION,
			background_colour = G.C.GREEN,
			background_alpha = 0.5,
			panel_colour = G.C.BLACK,
			outline_colour = G.C.EDITION,
			spacing = 10,
			rotate = true,
		}
	end

	return {
		win_like = false,
		title = localize("ph_game_over"),
		title_colour = G.C.RED,
		background_colour = G.C.RED,
		background_alpha = 0.8,
		panel_colour = nil,
		outline_colour = nil,
		spacing = nil,
		rotate = nil,
	}
end

function MP.UI.create_UIBox_mp_game_end(has_won)
	local screen_state = MP.UI.END_GAME_VIEW_MODEL.prepare_screen_state()
	local end_game_view = screen_state.runtime
	local viewable_players = screen_state.players
	local view_target_index = screen_state.target_index
	local summary_display = end_game_view and end_game_view.summary_display or {}
	local screen_style = get_end_game_screen_style(has_won)

	if BALATRO.set_paused then
		BALATRO.set_paused(false)
	end

	local eased_bg_colour = copy_table(screen_style.background_colour)
	eased_bg_colour[4] = 0
	ease_value(eased_bg_colour, 4, screen_style.background_alpha, nil, nil, true)

	local t = create_UIBox_generic_options({
		padding = 0,
		bg_colour = eased_bg_colour,
		colour = screen_style.panel_colour,
		outline_colour = screen_style.outline_colour,
		no_back = true,
		no_esc = screen_style.win_like,
		contents = {
			{
				n = G.UIT.R,
				config = { align = "cm" },
				nodes = {
					{
						n = G.UIT.O,
						config = {
							object = DynaText({
								string = { screen_style.title },
								colours = { screen_style.title_colour },
								shadow = true,
								float = true,
								spacing = screen_style.spacing,
								rotate = screen_style.rotate,
								scale = 1.5,
								pop_in = 0.4,
								maxw = 6.5,
							}),
						},
					},
				},
			},
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.15 },
				nodes = {
					{
						n = G.UIT.C,
						config = { align = "cm" },
						nodes = {
							{
								n = G.UIT.R,
								config = { align = "cm", padding = 0.08 },
								nodes = {
									{
										n = G.UIT.T,
										config = {
											ref_table = end_game_view,
											ref_value = "jokers_text",
											scale = 0.8,
											maxw = 5,
											shadow = true,
										},
									},
								},
							},
							{
								n = G.UIT.R,
								config = { align = "cm", padding = 0.08 },
								nodes = {
									{ n = G.UIT.O, config = { object = end_game_view.jokers_area } },
								},
							},
							{
								n = G.UIT.R,
								config = { align = "cm", padding = 0.08 },
								nodes = {
									create_end_game_action_spacer(screen_style.win_like),
									create_end_game_named_action_button(
										"view_self_end_game_profile",
										screen_state.self_player and screen_state.self_player.username or "You",
										"view_self_end_game_profile_button"
									),
									create_end_game_target_cycle(screen_state, view_target_index, viewable_players),
									create_end_game_action_button(
										"view_nemesis_deck",
										"b_view_nemesis_deck",
										"view_nemesis_deck_button",
										screen_style.win_like and { nav = "wide" } or nil
									),
									create_end_game_action_spacer(screen_style.win_like),
								},
							},
							{
								n = G.UIT.R,
								config = { align = "cm" },
								nodes = {
									{
										n = G.UIT.C,
										config = { align = "cm", padding = 0.08 },
										nodes = {
											create_end_game_summary_stat_row("hand", summary_display, G.C.RED, {
												label_width = 3.5,
												value_width = 3.5,
												value_scale = 0.52,
												value_maxw = 3.2,
												value_prefix_nodes = { create_end_game_chip_prefix_node() },
											}),
											create_end_game_summary_stat_row("poker_hand", summary_display, G.C.WHITE, {
												label_width = 3.5,
												value_width = 3.5,
												value_scale = 0.45,
												value_maxw = 3.2,
											}),
											create_end_game_secondary_stats(summary_display),
											create_end_game_stat_gap(true),
											create_end_game_kofi_button(),
										},
									},
									{
										n = G.UIT.C,
										config = { align = "tr", padding = 0.08 },
										nodes = {
											create_end_game_summary_stat_row("seed", summary_display, G.C.WHITE, {
												label_key = "k_seed",
												label_width = 1.9,
												value_width = 1.9,
												value_scale = 0.45,
												value_maxw = 1.8,
											}),
											UIBox_button({
												id = "copy_seed_button",
												button = "mp_copy_end_game_seed",
												label = { localize("b_copy") },
												colour = G.C.BLUE,
												scale = 0.3,
												minw = 2.3,
												minh = 0.4,
											}),
											{
												n = G.UIT.R,
												config = { align = "cm", minh = 0.4, minw = 0.1 },
												nodes = {},
											},
											UIBox_button({
												id = "from_game_won",
												button = "mp_end_game_return_to_lobby",
												label = { localize("b_return_lobby") },
												minw = 2.5,
												maxw = 2.5,
												minh = 1,
												focus_args = { nav = "wide", snap_to = true },
											}),
											UIBox_button({
												button = "mp_end_game_leave_lobby",
												label = { localize("b_leave_lobby") },
												minw = 2.5,
												maxw = 2.5,
												minh = 1,
												focus_args = { nav = "wide" },
											}),
										},
									},
								},
							},
						},
					},
				},
			},
		},
	})

	t.nodes[1] = {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.1 },
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm", padding = 2 },
				nodes = {
					{
						n = G.UIT.O,
						config = {
							padding = 0,
							id = "jimbo_spot",
							object = Moveable(0, 0, G.CARD_W * 1.1, G.CARD_H * 1.1),
						},
					},
				},
			},
			{ n = G.UIT.C, config = { align = "cm", padding = 0.1 }, nodes = { t.nodes[1] } },
		},
	}

	if screen_style.win_like then t.config.id = "you_win_UI" end

	return t
end
