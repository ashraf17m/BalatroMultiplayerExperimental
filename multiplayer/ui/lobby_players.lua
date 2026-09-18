-- Consolidated Lobby Players & Row Layouts Module
-- Replaces 6 fragmented files with a unified, cohesive vertical module.

MP.UI = MP.UI or {}
MP.UI.PLAYER_ROW_VIEW_MODEL = MP.UI.PLAYER_ROW_VIEW_MODEL or {}
MP.UI.ROW_LAYOUT = MP.UI.ROW_LAYOUT or {}
MP.UI.LOBBY_PLAYERS = MP.UI.LOBBY_PLAYERS or {}
local ROW_VIEW_MODEL = MP.UI.PLAYER_ROW_VIEW_MODEL
local ROW_LAYOUT = MP.UI.ROW_LAYOUT
local lobby_players_ui = MP.UI.LOBBY_PLAYERS
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

-- ============================================================================
-- SECTION 1: PLAYER ROW VIEW MODEL
-- (Consolidated from player_row_view_model.lua)
-- ============================================================================

local TEAMS_DOMAIN = MP.DOMAIN and MP.DOMAIN.TEAMS or {}

local function build_lobby_team_picker_choice_rows(player_id, current_team)
	local rows = {}
	local current_row = nil

	for team_idx = 1, MP.MAX_TEAMS do
		if not current_row or #current_row.buttons >= 4 then
			current_row = {
				padding = 0.05,
				gap = 0.08,
				buttons = {},
			}
			rows[#rows + 1] = current_row
		end

		current_row.buttons[#current_row.buttons + 1] = {
			id = "team_choice_" .. tostring(player_id) .. "_" .. tostring(team_idx),
			button = "choose_player_team",
			label = TEAMS_DOMAIN.get_short_display_name(team_idx),
			minw = 1.75,
			minh = 0.62,
			scale = 0.45,
			colour = MP.TEAM_COLORS[team_idx] or G.C.WHITE,
			text_colour = G.C.WHITE,
			chosen = team_idx == current_team,
		}
	end

	return rows
end

local function count_player_mods(player)
	local mods = player and player.config and player.config.Mods or nil
	if not mods then
		return 0
	end

	local count = 0
	for _ in pairs(mods) do
		count = count + 1
	end
	return count
end

local function create_kick_action(row_model, suffix, button)
	return {
		id = row_model.id .. suffix,
		button = button,
		label = "K",
		colour = G.C.RED,
		tooltip = { localize("b_kick") },
		minw = 0.65,
	}
end
ROW_VIEW_MODEL.create_kick_action = create_kick_action

local function is_current_duels_enemy(player, is_self)
	if is_self or not player or not (MP.is_duels_mode and MP.is_duels_mode()) then
		return false
	end

	local self_player = MP.get_self_lobby_player and MP.get_self_lobby_player() or nil
	local nemesis_player_id = self_player and self_player.nemesis_player_id or nil
	return nemesis_player_id ~= nil and player.id ~= nil and player.id == nemesis_player_id
end
ROW_VIEW_MODEL.is_current_duels_enemy = is_current_duels_enemy

local build_lobby_player_row_model

local function get_lobby_player_display_index(player_id, opts)
	local options = opts or {}
	local players = MP.get_lobby_view_players and MP.get_lobby_view_players({
		lobby_context = options.lobby_context or (MP.get_lobby_state_context and MP.get_lobby_state_context()) or nil,
		sort_by_team = options.sort_by_team ~= false,
		match_only = options.match_only,
	}) or nil

	for index, player in ipairs(players or {}) do
		if player.id == player_id then
			return index
		end
	end

	return 1
end

local function build_lobby_team_picker_model(player_id, opts)
	local options = type(opts) == "table" and opts or {}
	local lobby_context = options.lobby_context or (MP.get_lobby_state_context and MP.get_lobby_state_context()) or {}
	local player = (MP.get_lobby_player_by_id and MP.get_lobby_player_by_id(player_id)) or {
		id = player_id,
		username = "Guest",
		team = 1,
	}
	local row_model = build_lobby_player_row_model(player, get_lobby_player_display_index(player_id, {
		lobby_context = lobby_context,
		sort_by_team = true,
	}), {
		lobby_context = lobby_context,
	})
	local current_team = (player and player.team) or 1
	return {
		player_id = player_id,
		player = player,
		current_team = current_team,
		lobby_context = lobby_context,
		row_model = row_model,
		lock_action = (lobby_context.is_host and not row_model.is_self) and {
			id = "team_lock_toggle_" .. tostring(player_id),
			button = "toggle_player_team_lock",
			label = row_model.is_team_locked and "LOCK" or "FREE",
			minw = 1.05,
			minh = 0.42,
			scale = 0.45,
			colour = row_model.is_team_locked and G.C.RED or G.C.GREEN,
			text_colour = G.C.WHITE,
		} or nil,
		team_choice_rows = build_lobby_team_picker_choice_rows(player_id, current_team),
		back_action = {
			button = "cancel_player_team_picker",
			label = localize("b_back") or "Back",
			minw = 3.0,
			minh = 0.62,
			scale = 0.45,
			colour = G.C.ORANGE,
		},
	}
end
ROW_VIEW_MODEL.build_lobby_team_picker_model = build_lobby_team_picker_model

build_lobby_player_row_model = function(player, index, opts)
	local options = opts or {}
	local lobby_context = options.lobby_context or (MP.get_lobby_state_context and MP.get_lobby_state_context()) or {}
	local is_dummy = not not player.is_dummy
	local is_self = player.is_self
	if is_self == nil then
		is_self = (player.id == (G and G.MP_ID or nil))
	end

	local can_manage = player.can_kick
	if can_manage == nil then
		can_manage = lobby_context.is_host and not is_self and not player.is_owner
	end
	if is_dummy then
		can_manage = false
	end

	local uses_lobby_ready = lobby_context.uses_lobby_ready
	local status_kind = nil
	local status_text = nil
	if uses_lobby_ready then
		status_kind = player.status_kind or (player.is_ready and "ready" or "waiting")
		status_text = player.status_text
		if not status_text or status_text == "" then
			status_text = player.is_ready and localize("b_ready") or localize("b_unready")
		end
	end

	local badge_colour = MP.TEAM_COLORS[player.team or 1] or G.C.WHITE
	if is_self then
		badge_colour = G.C.GOLD
	elseif player.is_owner then
		badge_colour = G.C.ORANGE
	elseif uses_lobby_ready and player.is_ready then
		badge_colour = G.C.GREEN
	end

	local can_change_team = lobby_context.is_teams_mode
		and not lobby_context.match_in_progress
		and not is_dummy
		and (lobby_context.is_host or (is_self and not player.is_team_locked))
	local row_colour = lobby_context.is_teams_mode and (MP.TEAM_COLORS[player.team or 1] or G.C.WHITE)
		or darken(G.C.JOKER_GREY, 0.1)
	local is_duels_nemesis = is_current_duels_enemy(player, is_self)

	return {
		id = player.id,
		index = index or 1,
		username = player.username or "Guest",
		is_dummy = is_dummy,
		is_self = is_self,
		is_owner = not not player.is_owner,
		is_ready = not not player.is_ready,
		team = player.team or 1,
		team_name = player.team_name or (MP.TEAM_NAMES[player.team or 1] or "TEAM"),
		team_colour = MP.TEAM_COLORS[player.team or 1] or G.C.WHITE,
		blind_col = player.blind_col or 1,
		status_text = status_text,
		status_kind = status_kind,
		uses_lobby_ready = uses_lobby_ready,
		can_kick = not not can_manage,
		can_make_host = not not (player.can_make_host == nil and can_manage or player.can_make_host),
		mod_count = player.mod_count or count_player_mods(player),
		cached = not not player.cached,
		badge_colour = badge_colour,
		row_colour = row_colour,
		is_duels_nemesis = is_duels_nemesis,
		is_team_locked = not not player.is_team_locked,
		can_change_team = not not can_change_team,
		role = player.role or (player.is_spectator and "spectator") or "player",
		is_spectator = not not (player.is_spectator or player.role == "spectator"),
		lives = player.lives,
	}
end
ROW_VIEW_MODEL.build_lobby_player_row_model = build_lobby_player_row_model

local function build_lobby_player_surface_model(player, index, surface, opts)
	local options = opts or {}
	local lobby_context = options.lobby_context or (MP.get_lobby_state_context and MP.get_lobby_state_context()) or {}
	local row_model = build_lobby_player_row_model(player, index, {
		lobby_context = lobby_context,
	})
	local is_players_surface = surface == "players"
	local show_status_lane = not not (row_model.uses_lobby_ready and row_model.status_text and row_model.status_text ~= "")
	local show_team_lane = not not (lobby_context.is_teams_mode and is_players_surface)
	local team_lane_interactive = not not (is_players_surface and row_model.can_change_team)

	row_model.surface = surface
	row_model.show_status_lane = show_status_lane
	row_model.show_team_lane = show_team_lane
	row_model.team_lane_interactive = team_lane_interactive
	row_model.show_kick_slot = is_players_surface
	row_model.show_kick_button = not not (is_players_surface and row_model.can_kick)
	row_model.show_make_host_slot = is_players_surface
	row_model.show_make_host_button = not not (is_players_surface and row_model.can_make_host)
	row_model.show_mod_lane = true
	row_model.status_lane_spec = show_status_lane and {
		kind = "chip",
		text = row_model.status_text,
		colour = row_model.is_ready and G.C.GREEN or G.C.RED,
		minw = 1.95,
		scale = 0.45,
		slot_minw = 1.95,
		slot_minh = 0.42,
	} or nil
	row_model.team_lane_spec = show_team_lane and (
		team_lane_interactive and {
			kind = "action",
			id = row_model.id .. "_team_picker",
			button = "view_player_team_picker",
			label = TEAMS_DOMAIN.get_short_display_name(row_model.team),
			colour = row_model.team_colour,
			text_colour = G.C.WHITE,
			minw = 1.15,
			slot_minw = 1.15,
			slot_minh = 0.42,
		} or {
			kind = "chip",
			text = TEAMS_DOMAIN.get_short_display_name(row_model.team),
			colour = row_model.team_colour,
			text_colour = G.C.WHITE,
			minw = 1.15,
			scale = 0.45,
			slot_minw = 1.15,
		}
	) or nil
	row_model.kick_action = row_model.show_kick_button and create_kick_action(row_model, "_kick", "kick_player") or nil
	row_model.make_host_action = row_model.show_make_host_button and {
		id = row_model.id .. "_make_host",
		button = "make_player_host",
		label = "H",
		colour = G.C.BLUE,
		tooltip = { localize("b_make_host") },
		minw = 0.65,
	} or nil

	return row_model
end
ROW_VIEW_MODEL.build_lobby_player_surface_model = build_lobby_player_surface_model

-- ============================================================================
-- SECTION 2: PLAYER ROW LAYOUT & WIDGETS
-- (Consolidated from player_row_layout.lua)
-- ============================================================================


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
	local score_node
	if spec.show_stake_icon and shared.create_stake_score_box then
		score_node = shared.create_stake_score_box(
			spec.text,
			minw,
			spec.scale,
			spec.text_colour,
			spec.minh,
			spec.stake_scale,
			spec.score_display
		)
	else
		score_node = shared.create_score_text_label
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
			score_node,
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

-- ============================================================================
-- SECTION 3: LOBBY PLAYERS MODERATION ACTIONS
-- (Consolidated from lobby_players_moderation_actions.lua)
-- ============================================================================

function G.FUNCS.kick_player(e)
	if e and e.config and e.config.id then
		local player_id = string.match(e.config.id, "(.+)_kick")
		if player_id then
			MP.ACTIONS.kick_player(player_id)
		end
	end
end

function G.FUNCS.make_player_host(e)
	if e and e.config and e.config.id then
		local player_id = string.match(e.config.id, "(.+)_make_host")
		if player_id then
			MP.ACTIONS.make_player_host(player_id)
		end
	end
end

-- ============================================================================
-- SECTION 4: LOBBY PLAYERS TEAM PICKER ROW
-- (Consolidated from lobby_players_team_picker.lua)
-- ============================================================================

MP.UI.LOBBY_PLAYERS = lobby_players_ui
local TEAMS_DOMAIN = MP.DOMAIN and MP.DOMAIN.TEAMS or {}

function lobby_players_ui.create_team_picker_definition(player_id)
	local picker_model = ROW_VIEW_MODEL.build_lobby_team_picker_model and ROW_VIEW_MODEL.build_lobby_team_picker_model(player_id) or nil
	local picker_rows = ROW_LAYOUT.create_button_rows_from_specs((picker_model and picker_model.team_choice_rows) or {})

	return create_UIBox_generic_options({
		no_back = true,
		no_esc = true,
		contents = {
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.08 },
				nodes = {
					{
						n = G.UIT.C,
						config = {
							align = "cm",
							padding = 0.12,
							colour = G.C.BLACK,
							r = 0.12,
							emboss = 0.05,
							minw = 8.0,
						},
						nodes = {
							{
								n = G.UIT.R,
								config = { align = "cm", padding = 0.02 },
								nodes = {
									lobby_players_ui.create_team_picker_player_row(player_id),
								},
							},
							{
								n = G.UIT.R,
								config = { align = "cm", padding = 0.06 },
								nodes = {
									{
										n = G.UIT.C,
										config = { align = "cm", padding = 0.02 },
										nodes = picker_rows,
									},
								},
							},
						},
					},
				},
			},
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.08 },
				nodes = {
					ROW_LAYOUT.create_button_from_spec((picker_model and picker_model.back_action) or {
						button = "cancel_player_team_picker",
						label = localize("b_back") or "Back",
						minw = 3.0,
						minh = 0.62,
						scale = 0.45,
						colour = G.C.ORANGE,
					}),
				},
			},
		},
	})
end

function lobby_players_ui.set_active_team_picker_player(player_id)
	local overlay_runtime = lobby_players_ui.get_overlay_runtime and lobby_players_ui.get_overlay_runtime() or nil
	if not overlay_runtime then
		return
	end

	overlay_runtime.active_surface = "team_picker"
	overlay_runtime.active_team_picker_player_id = player_id
end

function lobby_players_ui.open_team_picker_overlay(player_id)
	if not player_id then
		return false
	end

	BALATRO.open_overlay_menu({
		definition = lobby_players_ui.create_team_picker_definition(player_id),
	})
	lobby_players_ui.set_active_team_picker_player(player_id)
	lobby_players_ui.mark_overlay("team_picker")
	return true
end

function lobby_players_ui.reopen_team_picker_overlay(player_id)
	if not player_id then
		return false
	end

	if (G and G.OVERLAY_MENU or nil) then
		BALATRO.exit_overlay_menu()
	end

	return lobby_players_ui.open_team_picker_overlay(player_id)
end

BALATRO.set_ui_function("view_player_team_picker", function(e)
	if not (e and e.config and e.config.id) then
		return
	end

	local player_id = string.match(e.config.id, "^team_picker_(.+)$")
		or string.match(e.config.id, "^(.+)_team_picker$")
	if not player_id or not (TEAMS_DOMAIN.can_edit_lobby_player_team and TEAMS_DOMAIN.can_edit_lobby_player_team(player_id)) then
		return
	end

	lobby_players_ui.open_team_picker_overlay(player_id)
end)

BALATRO.set_ui_function("choose_player_team", function(e)
	if not (e and e.config and e.config.id) then
		return
	end

	local player_id, team_id = string.match(e.config.id, "^team_choice_(.+)_(%d+)$")
	local applied_team_id = TEAMS_DOMAIN.apply_local_lobby_team_choice and TEAMS_DOMAIN.apply_local_lobby_team_choice(player_id, team_id) or nil
	if not player_id or not applied_team_id then
		return
	end

	if lobby_players_ui.suppress_next_team_picker_overlay_refresh then
		lobby_players_ui.suppress_next_team_picker_overlay_refresh(player_id)
	end

	local self_player_id = (G and G.MP_ID or nil)
	MP.ACTIONS.set_team(applied_team_id, player_id ~= self_player_id and player_id or nil)
	lobby_players_ui.reopen_team_picker_overlay(player_id)
end)

BALATRO.set_ui_function("toggle_player_team_lock", function(e)
	if not (e and e.config and e.config.id) then
		return
	end

	local player_id = string.match(e.config.id, "^team_lock_toggle_(.+)$")
	local next_locked = nil
	if TEAMS_DOMAIN.toggle_local_lobby_player_team_lock then
		next_locked = TEAMS_DOMAIN.toggle_local_lobby_player_team_lock(player_id)
	end
	if not player_id or next_locked == nil then
		return
	end

	if lobby_players_ui.suppress_next_team_picker_overlay_refresh then
		lobby_players_ui.suppress_next_team_picker_overlay_refresh(player_id)
	end
	MP.ACTIONS.set_team_lock(player_id, next_locked)
	lobby_players_ui.reopen_team_picker_overlay(player_id)
end)

BALATRO.set_ui_function("cancel_player_team_picker", function()
	BALATRO.exit_overlay_menu()
	BALATRO.call_ui_function("view_players_list")
end)

-- ============================================================================
-- SECTION 5: LOBBY PLAYERS ROWS VIEW
-- (Consolidated from lobby_players_rows_view.lua)
-- ============================================================================

MP.UI.LOBBY_PLAYERS = lobby_players_ui
lobby_players_ui.PLAYER_COLUMN_LIMIT = lobby_players_ui.PLAYER_COLUMN_LIMIT or 16
lobby_players_ui.PLAYER_COLUMN_GAP = lobby_players_ui.PLAYER_COLUMN_GAP or 0.24

local function create_default_row_nodes(model)
	return {
		ROW_LAYOUT.create_row_badge(model),
		{ n = G.UIT.B, config = { w = 0.08, h = 0.01 } },
		ROW_LAYOUT.create_name_lane(model),
	}
end

function lobby_players_ui.create_team_picker_player_row(player_id)
	local picker_model = ROW_VIEW_MODEL.build_lobby_team_picker_model and ROW_VIEW_MODEL.build_lobby_team_picker_model(player_id) or nil
	local model = (picker_model and picker_model.row_model) or {
		id = player_id,
		username = "Guest",
		team = 1,
		row_colour = darken(G.C.JOKER_GREY, 0.1),
	}
	model.name_leading_space = false
	local row_nodes = create_default_row_nodes(model)
	local right_slot = nil
	local right_slot_minh = nil
	if model.is_owner then
		right_slot = ROW_LAYOUT.create_host_chip(true)
	elseif picker_model and picker_model.lock_action then
		right_slot = ROW_LAYOUT.create_button_from_spec(picker_model.lock_action)
		right_slot_minh = 0.42
	end
	ROW_LAYOUT.append_row_slot(row_nodes, right_slot, 1.05, right_slot_minh)

	return ROW_LAYOUT.create_player_row_shell(model, row_nodes)
end

function lobby_players_ui.create_lobby_player_row(player, surface, index, lobby_context)
	local model = ROW_VIEW_MODEL.build_lobby_player_surface_model(player, index, surface, {
		lobby_context = lobby_context,
	})
	local row_nodes = create_default_row_nodes(model)

	ROW_LAYOUT.append_surface_lane_slot(row_nodes, model.status_lane_spec)
	ROW_LAYOUT.append_surface_lane_slot(row_nodes, model.team_lane_spec)

	ROW_LAYOUT.append_row_slot(
		row_nodes,
		ROW_LAYOUT.create_host_chip(model.is_owner),
		1.05
	)

	ROW_LAYOUT.append_row_slot(
		row_nodes,
		ROW_LAYOUT.create_spectator_chip(model.is_spectator or model.role == "spectator"),
		1.05
	)

	if model.show_kick_slot then
		ROW_LAYOUT.append_row_slot(
			row_nodes,
			ROW_LAYOUT.create_action_button_from_spec(model.kick_action),
			0.65,
			0.42
		)
	end

	if model.show_make_host_slot then
		ROW_LAYOUT.append_row_slot(
			row_nodes,
			ROW_LAYOUT.create_action_button_from_spec(model.make_host_action),
			0.65,
			0.42
		)
	end

	if model.show_mod_lane then
		ROW_LAYOUT.append_row_slot(row_nodes, ROW_LAYOUT.create_mod_lane(model), 0.9)
	end

	return ROW_LAYOUT.create_player_row_shell(model, row_nodes, {
		tooltip_player_id = model.id,
	})
end

function lobby_players_ui.create_flat_player_rows(players, surface, lobby_context, start_index)
	local rows = {}
	local row_offset = (start_index or 1) - 1
	for index, player in ipairs(players) do
		ROW_LAYOUT.append_node(rows, lobby_players_ui.create_lobby_player_row(player, surface, row_offset + index, lobby_context))
	end
	return rows
end

function lobby_players_ui.should_split_player_rows(players)
	return #players > lobby_players_ui.PLAYER_COLUMN_LIMIT
end

function lobby_players_ui.create_player_row_columns(players, lobby_context, column_width, start_index)
	local first_index = (start_index or 1)
	if not lobby_players_ui.should_split_player_rows(players) then
		return lobby_players_ui.create_flat_player_rows(players, "players", lobby_context, first_index)
	end

	local first_column_players = {}
	local second_column_players = {}
	for index, player in ipairs(players) do
		if index <= lobby_players_ui.PLAYER_COLUMN_LIMIT then
			first_column_players[#first_column_players + 1] = player
		else
			second_column_players[#second_column_players + 1] = player
		end
	end

	return {
		{
			n = G.UIT.R,
			config = { align = "tm", padding = 0 },
			nodes = {
				{
					n = G.UIT.C,
					config = { align = "tm", minw = column_width, padding = 0.02 },
					nodes = lobby_players_ui.create_flat_player_rows(first_column_players, "players", lobby_context, first_index),
				},
				{ n = G.UIT.B, config = { w = lobby_players_ui.PLAYER_COLUMN_GAP, h = 0.01 } },
				{
					n = G.UIT.C,
					config = { align = "tm", minw = column_width, padding = 0.02 },
					nodes = lobby_players_ui.create_flat_player_rows(second_column_players, "players", lobby_context, first_index + lobby_players_ui.PLAYER_COLUMN_LIMIT),
				},
			},
		},
	}
end

-- ============================================================================
-- SECTION 6: LOBBY PLAYERS OVERLAY & PAGINATION
-- (Consolidated from lobby_players_display.lua)
-- ============================================================================

MP.UI.LOBBY_PLAYERS = lobby_players_ui

function lobby_players_ui.get_overlay_runtime()
	return MP.UI and MP.UI.get_lobby_overlay_runtime and MP.UI.get_lobby_overlay_runtime() or nil
end

local function get_players_page_size()
	return lobby_players_ui.PLAYER_COLUMN_LIMIT * 2
end

local function get_players_page_count(player_count)
	local page_size = get_players_page_size()
	return math.max(1, math.ceil((tonumber(player_count) or 0) / page_size)), page_size
end

local function get_players_page()
	local overlay_runtime = lobby_players_ui.get_overlay_runtime()
	return math.max(1, math.floor(tonumber(overlay_runtime and overlay_runtime.players_page) or 1))
end

local function set_players_page(page)
	local overlay_runtime = lobby_players_ui.get_overlay_runtime()
	if overlay_runtime then
		overlay_runtime.players_page = math.max(1, math.floor(tonumber(page) or 1))
	end
end

local function clamp_players_page(page_count)
	local page = math.min(get_players_page(), page_count)
	set_players_page(page)
	return page
end

local function wrap_players_page(page, page_count)
	if page_count <= 1 then
		return 1
	end
	return ((page - 1) % page_count) + 1
end

local function slice_players_page(players, page, page_size)
	local player_count = #players
	local first_index = ((page - 1) * page_size) + 1
	local last_index = player_count > 0 and math.min(player_count, first_index + page_size - 1) or 0
	local page_players = {}
	if last_index >= first_index then
		for idx = first_index, last_index do
			page_players[#page_players + 1] = players[idx]
		end
	end
	return page_players, first_index
end

local function get_lobby_overlay_list_width(lobby_context)
	local width = 8.8
	if lobby_context and lobby_context.uses_lobby_ready then
		width = width + 2.05
	end
	if lobby_context and lobby_context.is_teams_mode then
		width = width + 1.25
	end
	return width
end

local function get_lobby_overlay_table_width(players, lobby_context)
	local column_width = get_lobby_overlay_list_width(lobby_context)
	if lobby_players_ui.should_split_player_rows(players) then
		return column_width * 2 + (lobby_players_ui.PLAYER_COLUMN_GAP or 0)
	end
	return column_width
end

local function create_players_pager(page, page_count)
	if page_count <= 1 then
		return nil
	end

	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.02, colour = G.C.CLEAR },
		nodes = {
			MP.UI.ROW_LAYOUT.create_button_from_spec({
				label = "<",
				button = "mp_lobby_players_prev_page",
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
					{
						n = G.UIT.T,
						config = {
							text = tostring(page) .. "/" .. tostring(page_count),
							scale = 0.35,
							colour = G.C.UI.TEXT_LIGHT,
							shadow = true,
						},
					},
				},
			},
			{ n = G.UIT.B, config = { w = 0.08, h = 0.01 } },
			MP.UI.ROW_LAYOUT.create_button_from_spec({
				label = ">",
				button = "mp_lobby_players_next_page",
				minw = 0.52,
				minh = 0.34,
				scale = 0.38,
				colour = G.C.GREEN,
			}),
		},
	}
end

local function create_lobby_overlay_contents()
	local players, lobby_context = MP.get_lobby_view_players({
		lobby_context = MP.get_lobby_state_context and MP.get_lobby_state_context() or nil,
		sort_by_team = true,
	})
	local player_count = #players
	local page_count, page_size = get_players_page_count(player_count)
	local page = clamp_players_page(page_count)
	local page_players, page_first_index = slice_players_page(players, page, page_size)
	local column_width = get_lobby_overlay_list_width(lobby_context)
	local rows = lobby_players_ui.create_player_row_columns(page_players, lobby_context, column_width, page_first_index)
	local list_width = get_lobby_overlay_table_width(page_players, lobby_context)
	local pager = create_players_pager(page, page_count)

	local contents = {
		{
			n = G.UIT.R,
			config = { align = "cm", padding = 0.12 },
			nodes = {
				{ n = G.UIT.T, config = { text = localize("b_players"), scale = 0.62, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
			},
		},
		{
			n = G.UIT.R,
			config = { align = "tm", padding = 0.08 },
			nodes = {
				{
					n = G.UIT.C,
					config = { align = "tm", minw = list_width, padding = 0.02 },
					nodes = rows,
				},
			},
		},
	}

	if pager then
		contents[#contents + 1] = pager
	end

	return contents
end

function lobby_players_ui.mark_overlay(surface)
	local overlay_runtime = lobby_players_ui.get_overlay_runtime()
	if overlay_runtime then
		overlay_runtime.active_surface = surface
		overlay_runtime.active_team_picker_player_id = surface == "team_picker" and overlay_runtime.active_team_picker_player_id or nil
		if surface ~= "team_picker" then
			overlay_runtime.suppress_next_team_picker_refresh = nil
		end
	end

	if not (G and G.OVERLAY_MENU) then
		return
	end

	G.OVERLAY_MENU.is_mp_players_list = surface == "players"
	G.OVERLAY_MENU.is_mp_team_picker = surface == "team_picker"
end

function lobby_players_ui.clear_pending_overlay_refresh()
	local overlay_runtime = lobby_players_ui.get_overlay_runtime()
	if overlay_runtime then
		overlay_runtime.pending_surface = nil
	end
end

function lobby_players_ui.suppress_next_team_picker_overlay_refresh(player_id)
	local overlay_runtime = lobby_players_ui.get_overlay_runtime()
	if overlay_runtime then
		overlay_runtime.suppress_next_team_picker_refresh = player_id or true
	end
end

function lobby_players_ui.open_overlay(surface)
	if surface == "team_picker" then
		local overlay_runtime = lobby_players_ui.get_overlay_runtime()
		local player_id = overlay_runtime and overlay_runtime.active_team_picker_player_id or nil
		if lobby_players_ui.open_team_picker_overlay then
			return lobby_players_ui.open_team_picker_overlay(player_id)
		end
		return false
	end

	G.FUNCS.overlay_menu({
		definition = G.UIDEF.create_UIBox_players_list(),
	})
	lobby_players_ui.mark_overlay("players")
end

function lobby_players_ui.get_active_surface()
	if not (G and G.OVERLAY_MENU) then
		return nil
	end

	if G.OVERLAY_MENU.is_mp_players_list then
		return "players"
	end
	if G.OVERLAY_MENU.is_mp_team_picker then
		return "team_picker"
	end

	return nil
end

function lobby_players_ui.request_lobby_overlay_refresh(surface)
	local target_surface = surface or lobby_players_ui.get_active_surface()
	if not target_surface then
		return false
	end

	local overlay_runtime = lobby_players_ui.get_overlay_runtime()
	if overlay_runtime and target_surface == "team_picker" then
		local suppressed_player_id = overlay_runtime.suppress_next_team_picker_refresh
		if suppressed_player_id == true or suppressed_player_id == overlay_runtime.active_team_picker_player_id then
			overlay_runtime.suppress_next_team_picker_refresh = nil
			return false
		end
	end

	if overlay_runtime then
		overlay_runtime.pending_surface = target_surface
	end
	if MP.UI and MP.UI.request_pending_lobby_overlay_refresh then
		MP.UI.request_pending_lobby_overlay_refresh()
	end
	return true
end

MP.UI.request_lobby_overlay_refresh = lobby_players_ui.request_lobby_overlay_refresh

function lobby_players_ui.refresh_pending_lobby_overlay()
	local overlay_runtime = lobby_players_ui.get_overlay_runtime()
	local target_surface = overlay_runtime and overlay_runtime.pending_surface or nil
	if not target_surface then
		return false
	end

	overlay_runtime.pending_surface = nil
	if G and G.OVERLAY_MENU then
		G.FUNCS.exit_overlay_menu()
	end
	lobby_players_ui.open_overlay(target_surface)
	return true
end

MP.UI.refresh_pending_lobby_overlay = lobby_players_ui.refresh_pending_lobby_overlay

G.UIDEF = G.UIDEF or {}
function G.UIDEF.create_UIBox_players_list()
	return create_UIBox_generic_options({
		contents = create_lobby_overlay_contents(),
	})
end

local function change_players_page(delta)
	local players = MP.get_lobby_view_players and select(1, MP.get_lobby_view_players({
		lobby_context = MP.get_lobby_state_context and MP.get_lobby_state_context() or nil,
		sort_by_team = true,
	})) or {}
	local page_count = get_players_page_count(#players)
	set_players_page(wrap_players_page(get_players_page() + delta, page_count))
	return lobby_players_ui.request_lobby_overlay_refresh("players")
end

G.FUNCS.mp_lobby_players_prev_page = function()
	return change_players_page(-1)
end

G.FUNCS.mp_lobby_players_next_page = function()
	return change_players_page(1)
end

function G.FUNCS.view_players_list(e)
	lobby_players_ui.clear_pending_overlay_refresh()
	set_players_page(1)
	lobby_players_ui.open_overlay("players")
end

