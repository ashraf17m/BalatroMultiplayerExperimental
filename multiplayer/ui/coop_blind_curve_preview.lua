-- Co-op Blind Curve Preview UI Component
-- Renders a visual bar graph matching Balatro's Blind UI aesthetic when hovering over co-op scaling options.

MP.UI = MP.UI or {}
MP.UI.COOP_GRAPH_CHIPS = MP.UI.COOP_GRAPH_CHIPS or {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function get_curve_meta(exp)
	local val = tonumber(exp) or 1.4
	local is_default = math.abs(val - 1.4) < 0.05
	return {
		title = string.format("CURVE %.1f%s", val, is_default and " (Default)" or ""),
		desc = "Ante 1 to 8 blind scaling preview",
	}
end

local VANILLA_STAKE_NAMES = {
	white = 1,
	red = 2,
	green = 3,
	black = 4,
	blue = 5,
	purple = 6,
	orange = 7,
	gold = 8,
}

local function get_stake_index(stake)
	if type(stake) == "number" then
		return math.max(1, math.floor(stake))
	end
	if type(stake) == "string" then
		local num = tonumber(stake)
		if num then
			return math.max(1, math.floor(num))
		end
		local clean_key = string.lower(stake)
		if clean_key:sub(1, 6) == "stake_" then
			clean_key = clean_key:sub(7)
		end
		if VANILLA_STAKE_NAMES[clean_key] then
			return VANILLA_STAKE_NAMES[clean_key]
		end
		if G and G.P_STAKES then
			local s = G.P_STAKES[stake] or G.P_STAKES["stake_" .. clean_key] or G.P_STAKES[clean_key]
			if s then
				if s.order then return s.order end
				if s.stake_level then return s.stake_level end
				if s.vanilla_index then return s.vanilla_index end
			end
		end
		if G and G.P_CENTER_POOLS and G.P_CENTER_POOLS.Stake then
			for idx, center in ipairs(G.P_CENTER_POOLS.Stake) do
				if center and (center.key == stake or center.key == "stake_" .. clean_key or center.key == clean_key) then
					return idx
				end
			end
		end
	end
	return 1
end

local function get_stake_scaling(stake)
	if G and G.GAME and G.GAME.modifiers then
		local live = tonumber(G.GAME.modifiers.scaling)
		if live and live > 0 then
			return live
		end
	end

	local idx = get_stake_index(stake)
	if SMODS and type(SMODS.setup_stake) == "function" and G and G.P_CENTER_POOLS and G.P_CENTER_POOLS.Stake and G.P_CENTER_POOLS.Stake[idx] then
		local old_game = G.GAME
		G.GAME = {
			modifiers = { scaling = 1 },
			starting_params = {
				discards = 4,
				hands = 4,
				dollars = 4,
				ante_scaling = 1,
			},
		}
		local ok = pcall(SMODS.setup_stake, idx)
		local scaling = ok and tonumber(G.GAME.modifiers and G.GAME.modifiers.scaling)
		G.GAME = old_game
		if scaling and scaling > 0 then
			return scaling
		end
	end

	-- Modded stakes (Cryptid, etc.) with order/index beyond Gold (8)
	if idx > 8 then
		return 3 + (idx - 8)
	end

	-- SMODS vanilla chain: Green +1, Purple +1 (White/Red = 1).
	if idx >= 6 then
		return 3
	elseif idx >= 3 then
		return 2
	end
	return 1
end

local function get_lobby_deck_context()
	local lobby_context = (MP.get_lobby_state_context and MP.get_lobby_state_context()) or {}
	local config = (MP.LOBBY and MP.LOBBY.config) or {}
	local effective = lobby_context.effective_deck or {}
	local run_deck = lobby_context.run_deck or {}
	local stake
	if config.different_decks then
		stake = run_deck.stake or effective.stake or config.stake
	else
		stake = config.stake or effective.stake or run_deck.stake
	end
	return {
		back = effective.back or run_deck.back,
		stake = stake,
	}
end

local function get_active_coop_stake()
	if MP.LOBBY and MP.LOBBY.match_in_progress and G and G.GAME and G.GAME.stake then
		return G.GAME.stake
	end
	local deck = get_lobby_deck_context()
	return deck.stake or 1
end

local function get_preview_deck_ante_scaling()
	if MP.LOBBY and MP.LOBBY.match_in_progress and G and G.GAME and G.GAME.starting_params then
		local live = tonumber(G.GAME.starting_params.ante_scaling)
		if live and live > 0 then
			return live
		end
	end

	local back = get_lobby_deck_context().back
	if back and back ~= "" then
		local key = back
		if MP.UTILS and MP.UTILS.get_deck_key_from_name then
			key = MP.UTILS.get_deck_key_from_name(back) or back
		end
		local center = ((G and G.P_CENTERS and G.P_CENTERS[key]))
			or (G and G.P_CENTERS and (G.P_CENTERS[key] or G.P_CENTERS[back]))
			or nil
		local from_deck = tonumber(center and center.config and center.config.ante_scaling)
		if from_deck and from_deck > 0 then
			return from_deck
		end
	end

	if G and G.GAME and G.GAME.starting_params then
		local live = tonumber(G.GAME.starting_params.ante_scaling)
		if live and live > 0 then
			return live
		end
	end

	return 1
end

local function calculate_boss_blinds_for_scale(scale)
	scale = tonumber(scale) or 1
	if scale == 1 then
		return { 600, 1600, 4000, 10000, 22000, 40000, 70000, 100000 }
	elseif scale == 2 then
		return { 600, 1800, 5200, 16000, 40000, 72000, 120000, 200000 }
	elseif scale == 3 then
		return { 600, 2000, 6400, 18000, 50000, 120000, 220000, 400000 }
	else
		local amounts = {
			300,
			700 + 100 * scale,
			1400 + 600 * scale,
			2100 + 2900 * scale,
			15000 + 5000 * scale * (scale > 0 and math.log(scale) or 0),
			12000 + 8000 * (scale + 1) * (0.4 * scale),
			10000 + 25000 * (scale + 1) * ((scale / 4) ^ 2),
			50000 * (scale + 1) ^ 2 * ((scale / 7) ^ 2),
		}
		local blinds = {}
		for ante = 1, 8 do
			local amt = amounts[ante]
			if amt > 0 then
				amt = amt - amt % (10 ^ math.floor(math.log10(amt) - 1))
			end
			blinds[ante] = math.floor(amt * 2)
		end
		return blinds
	end
end

local function get_coop_base_boss_blinds(custom_stake)
	local scale = tonumber(get_stake_scaling(custom_stake or get_active_coop_stake())) or 1
	if scale <= 0 then
		scale = 1
	end
	local ante_scaling = tonumber(get_preview_deck_ante_scaling()) or 1
	if ante_scaling <= 0 then
		ante_scaling = 1
	end

	local blinds = calculate_boss_blinds_for_scale(scale)
	if ante_scaling ~= 1 then
		for ante = 1, 8 do
			blinds[ante] = blinds[ante] * ante_scaling
		end
	end
	return blinds
end

MP.get_stake_index = get_stake_index
MP.get_stake_scaling = get_stake_scaling
MP.get_coop_base_boss_blinds = get_coop_base_boss_blinds

local function to_preview_number(value)
	if type(value) == "number" then
		return value
	end
	if BALATRO.to_score_number then
		local numeric = BALATRO.to_score_number(value)
		if type(numeric) == "number" then
			return numeric
		end
	end
	return tonumber(value)
end

local function format_preview_chips(chips)
	local num = to_preview_number(chips) or 0
	if num >= 1000000 then
		local m = num / 1000000
		if m == math.floor(m) then
			return string.format("%dM", m)
		elseif m >= 10 then
			return string.format("%.0fM", m)
		else
			return string.format("%.1fM", m)
		end
	elseif num >= 1000 then
		local k = num / 1000
		if k == math.floor(k) then
			return string.format("%dk", k)
		elseif k >= 10 then
			return string.format("%.0fk", k)
		else
			return string.format("%.1fk", k)
		end
	end
	return tostring(num)
end

local function get_active_coop_player_count()
	if MP.get_coop_player_count then
		return MP.get_coop_player_count()
	end
	return 1
end

local function get_coop_graph_model()
	local player_count = get_active_coop_player_count()
	local target_mult, per_player
	if MP.get_coop_target_multiplier then
		target_mult, _, per_player = MP.get_coop_target_multiplier(player_count)
	else
		per_player = tonumber(MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.coop_blind_scaling_per_player) or 1
		target_mult = player_count * math.max(0, per_player)
	end

	local bases = get_coop_base_boss_blinds()
	local antes = {}
	local max_chips = 1
	for ante = 1, 8 do
		local base = bases[ante] or 0
		local chips = to_preview_number(base) or 0
		if MP.get_coop_blind_multiplier then
			local coop_mult = MP.get_coop_blind_multiplier(ante)
			if coop_mult and coop_mult > 1 then
				local unit = chips / 2
				if MP.round_coop_blind_amount then
					unit = MP.round_coop_blind_amount(unit * coop_mult, ante)
				else
					unit = unit * coop_mult
				end
				chips = unit * 2
			end
		end
		antes[ante] = chips
		if chips > max_chips then
			max_chips = chips
		end
	end

	return {
		player_count = player_count,
		per_player = per_player or 1,
		target_mult = target_mult,
		antes = antes,
		max_chips = max_chips,
	}
end



local function graph_bar_h(chips, max_chips, min_h, max_h, min_chips)
	local n = tonumber(chips) or 0
	min_chips = tonumber(min_chips) or 0
	if max_chips <= min_chips then
		return min_h
	end
	return min_h + (max_h - min_h) * math.max(0, math.min(1, (n - min_chips) / (max_chips - min_chips)))
end


local function get_column_color(ante_index)
	if ante_index <= 2 then
		return G.C.BLUE
	elseif ante_index <= 5 then
		return G.C.ORANGE
	elseif ante_index <= 7 then
		return G.C.RED
	else
		return G.C.PURPLE
	end
end

local DEMO_MIN_BAR_H = 0.21
local DEMO_MAX_BAR_H = 1.82

local function place_coop_graph_stake(e, icon_uie)
	local uibox = (e and e.UIBox) or (G and G.OVERLAY_MENU)
	local icon = icon_uie or (uibox and uibox.get_UIE_by_ID and uibox:get_UIE_by_ID("coop_graph_stake_icon"))
	if not icon then return end
	if e and e.config then
		e.config.func = nil
	end
	local sprite = icon.config and icon.config.object
	if not (sprite and sprite.set_alignment and e) then return end
	sprite.parent = e
	sprite:set_alignment({
		major = e,
		type = "tli",
		bond = "Strong",
		offset = { x = 0.12, y = 0.10 },
	})
	if sprite.align_to_major then
		sprite:align_to_major()
	end
	if sprite.hard_set_VT then
		sprite:hard_set_VT()
	elseif sprite.T and sprite.VT then
		sprite.VT.x = sprite.T.x
		sprite.VT.y = sprite.T.y
	end
	if sprite.move_with_major then
		sprite:move_with_major(0)
	end
end

if BALATRO.set_ui_function then
	BALATRO.set_ui_function("mp_place_coop_graph_stake", place_coop_graph_stake)
else
	G.FUNCS = G.FUNCS or {}
	G.FUNCS.mp_place_coop_graph_stake = place_coop_graph_stake
end

function MP.UI.create_coop_blind_curve_demonstration_node()
	local model = get_coop_graph_model()
	local min_bar_h = DEMO_MIN_BAR_H
	local max_bar_h = DEMO_MAX_BAR_H
	local bar_w = 0.55
	local col_minw = 0.75
	local chip_scale = 0.32
	local badge_scale = 0.32
	local badge_minw = 0.60
	local panel_padding = 0.08
	local panel_minh = 2.73

	local bar_columns = {}

	for ante = 1, 8 do
		local scaled_boss = model.antes[ante]
		local chip_text = format_preview_chips(scaled_boss)
		MP.UI.COOP_GRAPH_CHIPS[ante] = chip_text
		local bar_h = graph_bar_h(scaled_boss, model.max_chips, min_bar_h, max_bar_h, model.antes[1])
		local bar_color = get_column_color(ante)
		local is_final_boss = ante == 8

		bar_columns[#bar_columns + 1] = {
			n = G.UIT.C,
			config = {
				align = "bm",
				padding = 0.025,
				minw = col_minw,
			},
			nodes = {
				-- 1. Chip amount text at top of bar
				{
					n = G.UIT.R,
					config = { align = "cm", padding = 0.015, minh = 0.36 },
					nodes = {
						{
							n = G.UIT.T,
							config = {
								id = "coop_graph_chips_" .. ante,
								text = chip_text,
								ref_table = MP.UI.COOP_GRAPH_CHIPS,
								ref_value = ante,
								scale = chip_scale,
								colour = is_final_boss and G.C.GOLD or G.C.WHITE,
								shadow = true,
							},
						},
					},
				},
				-- 2. Visual meter bar
				{
					n = G.UIT.R,
					config = { align = "cm", padding = 0.015 },
					nodes = {
						{
							n = G.UIT.B,
							config = {
								id = "coop_graph_bar_" .. ante,
								w = bar_w,
								h = bar_h,
								r = 0.06,
								colour = bar_color,
								emboss = 0.05,
							},
						},
					},
				},
				-- 3. Ante label badge at the base
				{
					n = G.UIT.R,
					config = {
						align = "cm",
						padding = 0.025,
						r = 0.05,
						colour = G.C.L_BLACK,
						emboss = 0.03,
						minw = badge_minw,
					},
					nodes = {
						{
							n = G.UIT.T,
							config = {
								text = "A" .. ante,
								scale = badge_scale,
								colour = is_final_boss and G.C.GOLD or G.C.UI.TEXT_LIGHT,
							},
						},
					},
				},
			},
		}
	end

	local stake_sprite = BALATRO.get_stake_sprite and BALATRO.get_stake_sprite(get_stake_index(get_active_coop_stake()), 0.75)
	if stake_sprite then
		bar_columns[#bar_columns + 1] = {
			n = G.UIT.O,
			config = {
				id = "coop_graph_stake_icon",
				object = stake_sprite,
				w = 0,
				h = 0,
				can_collide = false,
				no_role = true,
			},
		}
	end

	return {
		n = G.UIT.R,
		config = {
			id = "coop_blind_curve_graph_panel",
			align = "bm",
			padding = panel_padding,
			colour = darken(G.C.BLACK, 0.2),
			r = 0.12,
			outline = 1.4,
			outline_colour = G.C.L_BLACK,
			emboss = 0.05,
			minh = panel_minh,
			func = "mp_place_coop_graph_stake",
			insta_func = true,
		},
		nodes = bar_columns,
	}
end

function MP.UI.update_coop_blind_curve_demonstration()
	local overlay = G and G.OVERLAY_MENU
	if not (overlay and overlay.get_UIE_by_ID) then return false end

	local panel = overlay:get_UIE_by_ID("coop_blind_curve_graph_panel")
	if not panel then return false end

	local model = get_coop_graph_model()

	for ante = 1, 8 do
		local scaled_boss = model.antes[ante]
		local chip_text = format_preview_chips(scaled_boss)
		local bar_h = graph_bar_h(scaled_boss, model.max_chips, DEMO_MIN_BAR_H, DEMO_MAX_BAR_H, model.antes[1])

		MP.UI.COOP_GRAPH_CHIPS[ante] = chip_text

		local text_uie = overlay:get_UIE_by_ID("coop_graph_chips_" .. ante)
		if text_uie and text_uie.config then
			text_uie.config.text = chip_text
			if text_uie.config.text_drawable and text_uie.config.text_drawable.set then
				text_uie.config.text_drawable:set(chip_text)
			end
		end

		local bar_uie = overlay:get_UIE_by_ID("coop_graph_bar_" .. ante)
		if bar_uie and bar_uie.config then
			bar_uie.config.h = bar_h
			if bar_uie.T then bar_uie.T.h = bar_h end
			if bar_uie.VT then bar_uie.VT.h = bar_h end
		end
	end

	local stake_icon = overlay:get_UIE_by_ID("coop_graph_stake_icon")
	if stake_icon and stake_icon.config and BALATRO.get_stake_sprite then
		if stake_icon.config.object and stake_icon.config.object.remove then
			stake_icon.config.object:remove()
		end
		local new_sprite = BALATRO.get_stake_sprite(get_stake_index(get_active_coop_stake()), 0.75)
		stake_icon.config.object = new_sprite
		if panel and new_sprite then place_coop_graph_stake(panel, stake_icon) end
	end

	local num_fmt = number_format or tostring
	local ante8_boss = model.antes[8]
	local player_count = model.player_count
	local per_player = model.per_player
	local target_mult = model.target_mult
	local popup_ante8 = overlay:get_UIE_by_ID("coop_preview_popup_ante8_boss")
	if popup_ante8 and popup_ante8.config then
		local mult_str = string.format("%.1fx", target_mult)
		local txt = "Ante 8 Boss: " .. num_fmt(ante8_boss) .. " (" .. mult_str .. ")"
		popup_ante8.config.text = txt
		if popup_ante8.config.text_drawable and popup_ante8.config.text_drawable.set then
			popup_ante8.config.text_drawable:set(txt)
		end
	end

	local popup_scaling = overlay:get_UIE_by_ID("coop_preview_popup_player_scaling")
	if popup_scaling and popup_scaling.config then
		local txt
		if player_count <= 1 and per_player <= 1 then
			txt = "1 Player: Base Stake Blinds (Vanilla 1.0x)"
		elseif player_count <= 1 then
			txt = string.format("1 Player: Ante 1 (1.0x) -> Ante 8 (%.1fx)", target_mult)
		else
			txt = string.format(
				"%d Players: Ante 1 (1.0x) -> Ante 8 (%.1fx)",
				player_count,
				target_mult
			)
		end
		popup_scaling.config.text = txt
		if popup_scaling.config.text_drawable and popup_scaling.config.text_drawable.set then
			popup_scaling.config.text_drawable:set(txt)
		end
	end

	local uibox = panel.UIBox or overlay
	if uibox and uibox.recalculate then
		uibox:recalculate()
	end
	if panel and stake_icon and stake_icon.config and stake_icon.config.object then
		place_coop_graph_stake(panel, stake_icon)
	end
	return true
end

function MP.UI.create_coop_blind_scaling_section()
	local scale_spec = {
		kind = "cycle",
		spec_id = "coop_blind_scaling_per_player",
		control_id = "coop_blind_scaling_per_player_option",
		label_key = "k_opts_coop_blind_scaling",
		option_key = "coop_blind_scaling_per_player",
		scale = 0.82,
		option_values = MP.UI.coop_blind_scaling_values,
		display_options = MP.UI.build_coop_blind_scaling_display_options and MP.UI.build_coop_blind_scaling_display_options() or nil,
		ui_args = { w = 2.5 },
		on_change = function(next_value, args, spec)
			if MP.LOBBY and MP.LOBBY.config then
				MP.LOBBY.config[spec.option_key] = next_value
			end
			if MP.UI.send_lobby_option_update then
				MP.UI.send_lobby_option_update(spec.option_key, next_value)
			end
			if MP.UI.update_coop_blind_curve_demonstration then
				MP.UI.update_coop_blind_curve_demonstration()
			end
		end,
	}

	local curve_spec = {
		kind = "cycle",
		spec_id = "coop_blind_scaling_curve",
		control_id = "coop_blind_scaling_curve_option",
		label_key = "k_opts_coop_blind_curve",
		option_key = "coop_blind_scaling_curve",
		scale = 0.82,
		option_values = MP.UI.coop_blind_curve_values,
		display_options = MP.UI.build_coop_blind_curve_display_options and MP.UI.build_coop_blind_curve_display_options() or nil,
		ui_args = { w = 2.5 },
		on_change = function(next_value, args, spec)
			if MP.LOBBY and MP.LOBBY.config then
				MP.LOBBY.config[spec.option_key] = next_value
			end
			if MP.UI.send_lobby_option_update then
				MP.UI.send_lobby_option_update(spec.option_key, next_value)
			end
			if MP.UI.update_coop_blind_curve_demonstration then
				MP.UI.update_coop_blind_curve_demonstration()
			end
		end,
	}

	local scale_node = MP.UI.create_bound_lobby_option_cycle and MP.UI.create_bound_lobby_option_cycle(scale_spec) or nil
	local curve_node = MP.UI.create_bound_lobby_option_cycle and MP.UI.create_bound_lobby_option_cycle(curve_spec) or nil

	local graph_node = MP.UI.create_coop_blind_curve_demonstration_node()

	return {
		n = G.UIT.R,
		config = {
			id = "coop_blind_scaling_section",
			align = "cm",
			padding = 0.04,
		},
		nodes = {
			{
				n = G.UIT.C,
				config = {
					align = "cm",
					padding = 0.04,
				},
				nodes = {
					scale_node,
					curve_node,
				},
			},
			{
				n = G.UIT.C,
				config = {
					id = "coop_blind_graph_container",
					align = "cm",
					padding = 0.04,
				},
				nodes = {
					graph_node,
				},
			},
		},
	}
end

function MP.UI.create_UIBox_coop_blind_curve_preview()
	local config = (MP.LOBBY and MP.LOBBY.config) or {}
	local exponent = tonumber(config.coop_blind_scaling_curve) or 1.4
	local model = get_coop_graph_model()
	local player_count = model.player_count
	local per_player = model.per_player
	local target_mult = model.target_mult

	local meta = get_curve_meta(exponent)

	local min_bar_h = 0.18
	local max_bar_h = 1.35
	local bar_columns = {}

	for ante = 1, 8 do
		local scaled_boss = model.antes[ante]
		local chip_text = format_preview_chips(scaled_boss)
		local bar_h = graph_bar_h(scaled_boss, model.max_chips, min_bar_h, max_bar_h, model.antes[1])
		local bar_color = get_column_color(ante)
		local is_final_boss = ante == 8

		bar_columns[#bar_columns + 1] = {
			n = G.UIT.C,
			config = {
				align = "bm",
				padding = 0.02,
				minw = 0.44,
			},
			nodes = {
				-- Chip amount text at top of bar
				{
					n = G.UIT.R,
					config = { align = "cm", padding = 0.01, minh = 0.24 },
					nodes = {
						{
							n = G.UIT.T,
							config = {
								text = chip_text,
								scale = 0.20,
								colour = is_final_boss and G.C.GOLD or G.C.RED,
								shadow = true,
							},
						},
					},
				},
				-- Visual meter bar
				{
					n = G.UIT.R,
					config = { align = "cm", padding = 0.01 },
					nodes = {
						{
							n = G.UIT.B,
							config = {
								w = 0.36,
								h = bar_h,
								r = 0.06,
								colour = bar_color,
								emboss = 0.04,
							},
						},
					},
				},
				-- Ante label badge at the base
				{
					n = G.UIT.R,
					config = {
						align = "cm",
						padding = 0.02,
						r = 0.04,
						colour = G.C.L_BLACK,
						emboss = 0.02,
						minw = 0.38,
					},
					nodes = {
						{
							n = G.UIT.T,
							config = {
								text = "A" .. ante,
								scale = 0.22,
								colour = is_final_boss and G.C.GOLD or G.C.UI.TEXT_LIGHT,
							},
						},
					},
				},
			},
		}
	end

	local ante8_boss = model.antes[8]
	local num_fmt = number_format or tostring

	return {
		n = G.UIT.ROOT,
		config = {
			align = "cm",
			r = 0.12,
			padding = 0.08,
			colour = darken(G.C.BLACK, 0.2),
			outline = 1.2,
			outline_colour = G.C.L_BLACK,
			emboss = 0.06,
		},
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm", padding = 0.04 },
				nodes = {
					-- Header Banner (Balatro Blind Card style)
					{
						n = G.UIT.R,
						config = { align = "cm", padding = 0.03 },
						nodes = {
							{
								n = G.UIT.R,
								config = {
									align = "cm",
									r = 0.08,
									outline = 1,
									outline_colour = G.C.ORANGE,
									colour = darken(G.C.ORANGE, 0.3),
									emboss = 0.06,
									padding = 0.05,
									minw = 3.9,
								},
								nodes = {
									{
										n = G.UIT.T,
										config = {
											text = "CO-OP BLIND: " .. meta.title,
											scale = 0.32,
											colour = G.C.WHITE,
											shadow = true,
										},
									},
								},
							},
						},
					},
					-- Subtitle explanation
					{
						n = G.UIT.R,
						config = { align = "cm", padding = 0.02 },
						nodes = {
							{
								n = G.UIT.T,
								config = {
									text = meta.desc,
									scale = 0.22,
									colour = lighten(G.C.JOKER_GREY, 0.4),
									shadow = true,
								},
							},
						},
					},
					-- Graph Area (8 columns bottom-aligned)
					{
						n = G.UIT.R,
						config = {
							align = "bm",
							padding = 0.04,
							colour = darken(G.C.BLACK, 0.2),
							r = 0.08,
							emboss = 0.04,
							minh = 1.95,
						},
						nodes = bar_columns,
					},
					-- Footer 1: Ante 8 Boss target chips
					{
						n = G.UIT.R,
						config = {
							align = "cm",
							padding = 0.02,
						},
						nodes = {
							{
								n = G.UIT.R,
								config = {
									align = "cm",
									r = 0.06,
									padding = 0.04,
									colour = G.C.BLACK,
									emboss = 0.04,
									minw = 3.9,
								},
								nodes = {
									{
										n = G.UIT.T,
										config = {
											id = "coop_preview_popup_ante8_boss",
											text = "Ante 8 Boss: " .. num_fmt(ante8_boss) .. " (" .. string.format("%.1fx", target_mult) .. ")",
											scale = 0.26,
											colour = G.C.GOLD,
											shadow = true,
										},
									},
								},
							},
						},
					},
					-- Footer 2: Scaling breakdown (player count x rate = target)
					{
						n = G.UIT.R,
						config = { align = "cm", padding = 0.01 },
						nodes = {
							{
								n = G.UIT.T,
								config = {
									id = "coop_preview_popup_player_scaling",
									text = (player_count <= 1 and per_player <= 1) and "1 Player: Base Stake Blinds (Vanilla 1.0x)"
										or (player_count <= 1 and string.format("1 Player: Ante 1 (1.0x) -> Ante 8 (%.1fx)", target_mult))
										or string.format(
											"%d Players: Ante 1 (1.0x) -> Ante 8 (%.1fx)",
											player_count,
											target_mult
										),
									scale = 0.20,
									colour = G.C.UI.TEXT_LIGHT,
									shadow = true,
								},
							},
						},
					},
				},
			},
		},
	}
end

local function setup_coop_curve_popup(e)
	if not (e and e.config) then return end
	e.config.func = nil
	if e.config.mp_curve_popup_installed then return end
	e.config.mp_curve_popup_installed = true

	if e.states then
		if e.states.collide then e.states.collide.can = true end
		if e.states.hover then e.states.hover.can = true end
	end

	local old_hover = e.hover
	function e:hover(...)
		if old_hover then old_hover(self, ...) end
		local is_dragging = BALATRO.is_controller_mouse_dragging and BALATRO.is_controller_mouse_dragging()
		if not is_dragging then
			self.config.h_popup = MP.UI.create_UIBox_coop_blind_curve_preview()
			self.config.h_popup_config = {
				align = self.T.y > G.ROOM.T.h / 2 and "tm" or "bm",
				offset = { x = 0, y = self.T.y > G.ROOM.T.h / 2 and -0.12 or 0.12 },
				parent = self,
			}
			Node.hover(self)
		end
	end

	local old_stop = e.stop_hover
	function e:stop_hover(...)
		if old_stop then old_stop(self, ...) end
		Node.stop_hover(self)
		self.config.h_popup = nil
	end
end

if BALATRO.set_ui_function then
	BALATRO.set_ui_function("mp_place_coop_graph_stake", place_coop_graph_stake)
	BALATRO.set_ui_function("mp_setup_coop_blind_curve_popup", setup_coop_curve_popup)
else
	G.FUNCS = G.FUNCS or {}
	G.FUNCS.mp_place_coop_graph_stake = place_coop_graph_stake
	G.FUNCS.mp_setup_coop_blind_curve_popup = setup_coop_curve_popup
end
