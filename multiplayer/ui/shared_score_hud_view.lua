local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local score_shared = MP.UI and MP.UI.PLAYERS_HUD_SHARED or {}
local parse_score_int = score_shared.parse_score_int
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}
local teams_domain = MP.DOMAIN and MP.DOMAIN.TEAMS or {}

local function get_team_local_score_text()
	local teams_domain = MP.DOMAIN and MP.DOMAIN.TEAMS or nil
	return teams_domain and teams_domain.get_local_score_text and teams_domain.get_local_score_text() or nil
end

local function get_round_score_labels()
	local language = BALATRO.get_setting_value and BALATRO.get_setting_value("language") or nil
	return {
		top = language == "vi" and localize("k_lower_score") or localize("k_round"),
		bottom = language == "vi" and localize("k_round") or localize("k_lower_score"),
	}
end

local function uses_cooperative_shared_score()
	return (teams_domain.is_cooperative_blind and teams_domain.is_cooperative_blind())
		or (MP.is_coop_blind and MP.is_coop_blind())
end

local function get_cooperative_shared_display_score()
	local local_score_text = get_team_local_score_text()
		or (MP.GAME and MP.GAME.score_text)
		or "0"
	local total_score = parse_score_int(local_score_text)
	local global_coop = MP.is_coop_blind and MP.is_coop_blind()
	local self_team_id = MP.get_self_team_id and MP.get_self_team_id() or nil

	if not MP.GAME or not MP.GAME.enemies then
		return total_score
	end

	for _, enemy in pairs(MP.GAME.enemies) do
		if enemy and enemy.in_match ~= false and (global_coop or (self_team_id and enemy.team == self_team_id)) then
			total_score = MP.INSANE_INT.add(
				total_score,
				enemy.score or enemy.synced_score or MP.INSANE_INT.empty()
			)
		end
	end

	return total_score
end

local function get_shared_score_scale_from_insane_int(score, base_scale, max_value, cap)
	base_scale = base_scale or 1.1
	max_value = max_value or 10000
	cap = cap or 0.8

	if not score then
		return cap
	end

	local coeff = math.abs(tonumber(score.coefficient) or 0)
	local exponent = math.max(0, tonumber(score.exponent) or 0)
	local e_count = math.max(0, tonumber(score.e_count) or 0)
	if coeff <= 0 then
		return cap
	end

	local max_digits = math.floor(math.log(max_value * 10, 10))
	local fixed_huge_scale = base_scale * max_digits / math.floor(math.log(1000000 * 10, 10))
	if e_count > 0 then
		return math.min(cap, fixed_huge_scale)
	end

	local huge_threshold = math.max(1, math.floor(math.log((G.E_SWITCH_POINT or 100000000000) * 10, 10)))
	local total_digits = exponent + math.max(1, math.floor(math.log(coeff * 10, 10)))
	if total_digits >= huge_threshold then
		return math.min(cap, fixed_huge_scale)
	end
	if total_digits >= max_digits then
		return math.min(cap, base_scale * max_digits / total_digits)
	end

	return math.min(cap, base_scale)
end

local function get_shared_score_display_state()
	local use_cooperative_score = uses_cooperative_shared_score()
	local displayed_text
	local scale

	if use_cooperative_score then
		local display_score = get_cooperative_shared_display_score()
		displayed_text = score_shared.format_score_int(display_score, "0")
		scale = get_shared_score_scale_from_insane_int(display_score, 1.1, 10000, 0.8)
	else
		local live_chips = BALATRO.get_chips and BALATRO.get_chips() or 0
		displayed_text = number_format(live_chips)
		BALATRO.set_chips_text(displayed_text)
		scale = math.min(0.8, scale_number(BALATRO.get_chips and BALATRO.get_chips() or 0, 1.1))
	end

	if MP.GAME and match_domain.set_shared_score_text then
		match_domain.set_shared_score_text(displayed_text)
	end

	return {
		text = displayed_text,
		scale = scale,
		mode = use_cooperative_score and "cooperative" or "round",
	}
end

local function recalc_row_dollars_chips_layout()
	if not BALATRO.get_hud then
		return
	end

	local row_dollars_chips = BALATRO.get_hud_element_by_id("row_dollars_chips")
	if row_dollars_chips and row_dollars_chips.recalculate then
		row_dollars_chips:recalculate()
	end

	BALATRO.recalculate_ui(BALATRO.get_hud())
end

local function apply_shared_score_display(target, display_state, force_text_refresh)
	if not (target and target.config) then
		return false
	end

	local config = target.config
	local text_changed = config.last_mp_score_text ~= display_state.text
	local scale_changed = config.last_mp_score_scale ~= display_state.scale
	local mode_changed = config.last_mp_score_mode ~= display_state.mode
	if not (force_text_refresh or text_changed or scale_changed or mode_changed) then
		return false
	end

	config.last_mp_score_text = display_state.text
	config.last_mp_score_scale = display_state.scale
	config.last_mp_score_mode = display_state.mode
	config.scale = display_state.scale

	if target.update_text then
		target:update_text()
	end

	return true
end

local function refresh_shared_score_text_node(opts)
	opts = opts or {}

	if not BALATRO.get_hud then
		return
	end

	local chip_UI = BALATRO.get_hud_element_by_id("chip_UI_count")
	if not (chip_UI and chip_UI.config and chip_UI.config.func == "mp_shared_chip_UI_set") then
		return
	end

	local display_state = get_shared_score_display_state()
	if not apply_shared_score_display(chip_UI, display_state, opts.force_text_refresh) then
		return
	end

	if opts.recalc_layout then
		recalc_row_dollars_chips_layout()
	end
end

BALATRO.set_ui_function("mp_shared_chip_UI_set", function(e)
	if not (e and e.config) then
		return
	end

	apply_shared_score_display(e, get_shared_score_display_state())
end)

local function create_row_dollars_chips_label_line(text, width)
	width = width or 1.3
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0, maxw = width },
		nodes = {
			{
				n = G.UIT.T,
				config = {
					text = text,
					scale = 0.42,
					colour = G.C.UI.TEXT_LIGHT,
					shadow = true,
				},
			},
		},
	}
end

local function create_row_dollars_chips_label_column(label_lines, width)
	width = width or 1.3
	return {
		n = G.UIT.C,
		config = { align = "cm", minw = width },
		nodes = {
			create_row_dollars_chips_label_line(label_lines[1], width),
			create_row_dollars_chips_label_line(label_lines[2], width),
		},
	}
end

local function create_row_dollars_chips_value_panel(value_nodes, minw)
	return {
		n = G.UIT.C,
		config = { align = "cm", minw = minw or 3.3, minh = 0.7, r = 0.1, colour = G.C.DYN_UI.BOSS_DARK },
		nodes = value_nodes,
	}
end

local function create_row_dollars_chips_row(label_lines, value_nodes, value_minw, label_minw)
	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.1 },
		nodes = {
			create_row_dollars_chips_label_column(label_lines, label_minw),
			create_row_dollars_chips_value_panel(value_nodes, value_minw),
		},
	}
end

local function get_enemy_location_display()
	local enemy = MP.GAME and MP.GAME.enemy or {}
	if MP.SPECTATOR and MP.SPECTATOR.is_spectating and MP.SPECTATOR.target_player_id and MP.GAME then
		local nemesis_id
		for _, player in ipairs((MP.LOBBY and MP.LOBBY.players) or {}) do
			if player.id == MP.SPECTATOR.target_player_id then
				nemesis_id = player.nemesis_player_id
				break
			end
		end
		if nemesis_id and MP.GAME.enemies and MP.GAME.enemies[nemesis_id] then
			enemy = MP.GAME.enemies[nemesis_id]
		elseif nemesis_id then
			for _, player in ipairs((MP.LOBBY and MP.LOBBY.players) or {}) do
				if player.id == nemesis_id then
					enemy = {
						raw_location = player.raw_location,
						location = player.location,
					}
					break
				end
			end
		end
	end
	return MP.UI
		and MP.UI.UTILS
		and MP.UI.UTILS.resolve_location_display
		and MP.UI.UTILS.resolve_location_display(enemy.raw_location, enemy.location)
		or {
			text = enemy.location,
			full_text = enemy.location,
		}
end

local function create_enemy_location_blind_render()
	local display = get_enemy_location_display()
	local icon_object = (display.icon_kind or display.blind_key)
		and MP.UI
		and MP.UI.UTILS
		and MP.UI.UTILS.create_location_blind_icon_object
		and MP.UI.UTILS.create_location_blind_icon_object(display, 0.4)
		or nil
	if icon_object then
		return icon_object
	end

	local blind_text = display.icon_label or display.blind_value
	if blind_text and blind_text ~= "" then
		return DynaText({
			string = { blind_text },
			colours = { G.C.WHITE },
			scale = 0.35,
			shadow = true,
		})
	end

	return Moveable()
end

local function create_enemy_location_row()
	local label_lines = localize("ml_enemy_loc")
	local display = get_enemy_location_display()
	local has_icon = display.icon_kind or display.blind_key
	local text = has_icon and (display.text or "") or (display.full_text or display.text or "")

	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.1, id = "mp_enemy_location_row" },
		nodes = {
			{
				n = G.UIT.O,
				config = {
					w = 0.5,
					h = 0.5,
					object = get_stake_sprite(BALATRO.get_stake and BALATRO.get_stake() or 1, 0.5),
					hover = true,
					can_collide = false,
				},
			},
			create_row_dollars_chips_label_column(label_lines, 1.2),
			{
				n = G.UIT.C,
				config = { align = "cm", minw = 2.8, minh = 0.7, r = 0.1, colour = G.C.DYN_UI.BOSS_DARK },
				nodes = {
					{
						n = G.UIT.C,
						config = {
							maxw = 2.2,
							align = "cm",
						},
						nodes = {
							{
								n = G.UIT.T,
								config = {
									text = tostring(text),
									scale = 0.35,
									colour = G.C.WHITE,
									id = "chip_UI_count",
									shadow = true,
									maxw = 2.5,
								},
							},
						},
					},
					{ n = G.UIT.B, config = { w = 0.1, h = 0.1 } },
					{
						n = G.UIT.O,
						config = {
							object = create_enemy_location_blind_render(),
							id = "mp_enemy_location_render",
						},
					},
				},
			},
		},
	}
end

local function has_duels_hover_enemy()
	if MP.is_duels_bye and MP.is_duels_bye() then
		return false
	end

	if not (
		MP.OPPONENTS
		and MP.OPPONENTS.get_nemesis_lobby_player
		and MP.OPPONENTS.get_nemesis_lobby_player()
	) then
		return false
	end

	return not not (MP.OPPONENTS.get_nemesis_enemy_state and MP.OPPONENTS.get_nemesis_enemy_state())
end

local function is_enemy_location_score_hover_lobby_type()
	return not not (
		MP.LOBBY
		and MP.LOBBY_TYPES
		and (
			MP.LOBBY.lobby_type == MP.LOBBY_TYPES.ONE_V_ONE
			or MP.LOBBY.lobby_type == MP.LOBBY_TYPES.DUELS
		)
	)
end

local function should_enable_enemy_location_score_hover()
	if not (is_enemy_location_score_hover_lobby_type() and MP.LOBBY.code and MP.GAME and MP.GAME.enemy) then
		return false
	end

	if MP.LOBBY.lobby_type == MP.LOBBY_TYPES.ONE_V_ONE then
		return true
	end

	return not not (MP.is_duels_mode and MP.is_duels_mode() and has_duels_hover_enemy())
end

local function close_enemy_location_hover_popup(anchor)
	if not (G and G.mp_enemy_location_ui) then
		return false
	end
	if anchor and G.mp_enemy_location_ui_anchor and G.mp_enemy_location_ui_anchor ~= anchor then
		return false
	end

	if G.mp_enemy_location_ui.remove then
		G.mp_enemy_location_ui:remove()
	end
	G.mp_enemy_location_ui = nil
	G.mp_enemy_location_ui_anchor = nil
	return true
end

local function create_enemy_location_hover_definition()
	return {
		n = G.UIT.ROOT,
		config = { colour = G.C.DYN_UI.BOSS_MAIN, emboss = 0.05, r = 0.25 },
		nodes = {
			create_enemy_location_row(),
		},
	}
end

local function open_enemy_location_hover_popup(anchor, force_refresh)
	if not (anchor and should_enable_enemy_location_score_hover() and UIBox) then
		close_enemy_location_hover_popup(anchor)
		return false
	end

	if MP.OPPONENTS and MP.OPPONENTS.refresh_primary_enemy_view then
		MP.OPPONENTS.refresh_primary_enemy_view()
	end

	if G.mp_enemy_location_ui and G.mp_enemy_location_ui_anchor == anchor and not force_refresh then
		return true
	end

	close_enemy_location_hover_popup()
	G.mp_enemy_location_ui_anchor = anchor
	G.mp_enemy_location_ui = UIBox({
		definition = create_enemy_location_hover_definition(),
		config = {
			align = "tmi",
			offset = { x = 0, y = ((anchor.T and anchor.T.h) or 0) + 0.15 },
			major = anchor,
			bond = "Weak",
			instance_type = "CARD",
		},
	})
	return true
end

local function refresh_enemy_location_hover_popup()
	local anchor = G and G.mp_enemy_location_ui_anchor or nil
	if not (G and G.mp_enemy_location_ui and anchor) then
		return false
	end

	if not should_enable_enemy_location_score_hover() then
		return close_enemy_location_hover_popup()
	end

	return open_enemy_location_hover_popup(anchor, true)
end

BALATRO.set_ui_function("mp_setup_hover_enemy_location_display", function(e)
	if not (e and e.config) then
		return
	end
	e.config.func = nil
	if not is_enemy_location_score_hover_lobby_type() then
		return
	end
	if e.config.mp_enemy_location_hover_installed then
		return
	end
	e.config.mp_enemy_location_hover_installed = true
	e.config.hover = true

	if e.states then
		if e.states.collide then
			e.states.collide.can = true
		end
		if e.states.hover then
			e.states.hover.can = true
		end
	end

	local old_hover = e.hover
	function e:hover(...)
		if old_hover then
			old_hover(self, ...)
		end
		open_enemy_location_hover_popup(self)
	end

	local old_stop_hover = e.stop_hover
	function e:stop_hover(...)
		if old_stop_hover then
			old_stop_hover(self, ...)
		end
		close_enemy_location_hover_popup(self)
	end

	local old_remove = e.remove
	function e:remove(...)
		close_enemy_location_hover_popup(self)
		if old_remove then
			old_remove(self, ...)
		end
	end
end)

local function create_shared_score_row()
	local score_labels = get_round_score_labels()

	local row = create_row_dollars_chips_row({ score_labels.top, score_labels.bottom }, {
		{
			n = G.UIT.O,
			config = {
				w = 0.5,
				h = 0.5,
				object = get_stake_sprite(BALATRO.get_stake and BALATRO.get_stake() or 1, 0.5),
				hover = true,
				can_collide = false,
			},
		},
		{ n = G.UIT.B, config = { w = 0.1, h = 0.1 } },
		{
			n = G.UIT.T,
			config = {
				ref_table = MP.GAME,
				ref_value = "shared_score_text",
				lang = G.LANGUAGES["en-us"],
				scale = 0.85,
				colour = G.C.WHITE,
				id = "chip_UI_count",
				func = "mp_shared_chip_UI_set",
				shadow = true,
			},
		},
	})
	if is_enemy_location_score_hover_lobby_type() then
		row.config.func = "mp_setup_hover_enemy_location_display"
	end
	return row
end

local function update_enemy_location_text_node(text)
	local text_node = BALATRO.get_hud_element_by_id and BALATRO.get_hud_element_by_id("chip_UI_count") or nil
	if not (text_node and text_node.config) then
		return false
	end

	text_node.config.text = tostring(text or "")
	if text_node.update_text then
		text_node:update_text()
	end
	return true
end

local function update_enemy_location_blind_render()
	local renderer = BALATRO.get_hud_element_by_id and BALATRO.get_hud_element_by_id("mp_enemy_location_render") or nil
	if not (renderer and MP.UI and MP.UI.UTILS and MP.UI.UTILS.replace_config_object) then
		return false
	end

	return MP.UI.UTILS.replace_config_object(renderer, create_enemy_location_blind_render())
end

local function update_enemy_location_row_content()
	local display = get_enemy_location_display()
	local has_icon = display.icon_kind or display.blind_key
	local text = has_icon and (display.text or "") or (display.full_text or display.text or "")
	local text_updated = update_enemy_location_text_node(text)
	local render_updated = update_enemy_location_blind_render()

	if text_updated or render_updated then
		refresh_enemy_location_hover_popup()
		return true
	end
	return false
end

local function replace_row_dollars_chips(node)
	local hud = BALATRO.get_hud and BALATRO.get_hud() or nil
	local row_dollars_chips = BALATRO.get_hud_element_by_id("row_dollars_chips")
	if not row_dollars_chips then
		return false
	end

	if not (hud and hud.add_child) then
		return false
	end

	local previous_children = row_dollars_chips.children or {}
	row_dollars_chips.children = {}
	hud:add_child(node, row_dollars_chips)

	for _, child in pairs(previous_children) do
		if child and child.remove then
			child:remove()
		end
	end

	return true
end

function MP.UI.show_enemy_location()
	if replace_row_dollars_chips(create_enemy_location_row()) then
		recalc_row_dollars_chips_layout()
	end
end

function MP.UI.refresh_enemy_location_ui()
	if not (BALATRO.get_hud_element_by_id and BALATRO.get_hud_element_by_id("mp_enemy_location_row")) then
		return false
	end
	return update_enemy_location_row_content()
end

function MP.UI.hide_enemy_location()
	if replace_row_dollars_chips(create_shared_score_row()) then
		refresh_shared_score_text_node({
			force_text_refresh = true,
			recalc_layout = true,
		})
	end
end

function MP.UI.refresh_shared_score_ui()
	if not (BALATRO.get_hud and BALATRO.get_hud() and MP.LOBBY and MP.LOBBY.code) then
		return
	end

	refresh_shared_score_text_node()
end
