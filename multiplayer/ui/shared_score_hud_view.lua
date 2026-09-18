local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local score_shared = MP.UI and MP.UI.PLAYERS_HUD_SHARED or {}
local parse_score_int = score_shared.parse_score_int
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}
local teams_domain = MP.DOMAIN and MP.DOMAIN.TEAMS or {}

local function get_team_local_score_text()
	local teams_domain = MP.DOMAIN and MP.DOMAIN.TEAMS or nil
	return teams_domain and teams_domain.get_local_score_text and teams_domain.get_local_score_text() or nil
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

local function are_scores_equal(a, b)
	if not (a and b) then return false end
	return a.e_count == b.e_count and a.exponent == b.exponent and a.coefficient == b.coefficient
end

local function ensure_coop_display_score()
	if not (MP.GAME and MP.INSANE_INT) then
		return nil
	end
	if not MP.GAME.coop_display_score then
		MP.GAME.coop_display_score = MP.INSANE_INT.copy(get_cooperative_shared_display_score())
	end
	return MP.GAME.coop_display_score
end

local function is_display_score_easing(score_display)
	if not (score_display and score_display._mp_score_ease_proxy) then
		return false
	end
	local proxy = score_display._mp_score_ease_proxy
	local target = score_display._mp_score_ease_target
	return proxy.value ~= nil and target ~= nil and proxy.value ~= target
end

local function update_coop_chip_ui(e)
	local target_score = get_cooperative_shared_display_score()
	local display_score = ensure_coop_display_score()
	if not display_score then
		return
	end

	if not is_display_score_easing(display_score) then
		MP.INSANE_INT.copy_into(display_score, target_score)
	end

	local displayed_text = score_shared.format_score_int(display_score, "0")
	if G and G.GAME then
		G.GAME.chips_text = displayed_text
	end
	if MP.GAME then
		MP.GAME.shared_score_text = displayed_text
		if match_domain.set_shared_score_text then
			match_domain.set_shared_score_text(displayed_text)
		end
	end

	if e and e.config then
		local safe_num = MP.INSANE_INT.to_safe_number(display_score)
		e.config.scale = math.min(0.8, scale_number(safe_num or 0, 1.1))
	end
end

local orig_chip_UI_set = G and G.FUNCS and G.FUNCS.chip_UI_set
local function unified_chip_UI_set(e)
	if uses_cooperative_shared_score() then
		update_coop_chip_ui(e)
	elseif orig_chip_UI_set then
		orig_chip_UI_set(e)
	end
end

if G and G.FUNCS then
	G.FUNCS.chip_UI_set = unified_chip_UI_set
end
BALATRO.set_ui_function("mp_shared_chip_UI_set", unified_chip_UI_set)
BALATRO.set_ui_function("chip_UI_set", unified_chip_UI_set)

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

local function is_coop_mode_active()
	return uses_cooperative_shared_score()
		or (MP.is_coop_blind and MP.is_coop_blind())
		or (MP.is_coop_run and MP.is_coop_run())
		or (MP.is_coop_gamemode and MP.is_coop_gamemode())
		or (MP.is_coop_lobby_type and MP.is_coop_lobby_type())
end

local function get_enemy_location_label_lines()
	local is_coop = is_coop_mode_active()
	local key = is_coop and "ml_teammate_loc" or "ml_enemy_loc"
	local label_lines = localize(key)
	if type(label_lines) == "table" and #label_lines >= 2 then
		return label_lines
	end
	if is_coop then
		return { "Teammate", "location" }
	end
	return { "Enemy", "location" }
end

local function create_enemy_location_row()
	local label_lines = get_enemy_location_label_lines()
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
					object = get_stake_sprite((G and G.GAME and G.GAME.stake or nil) or 1, 0.5),
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
	local row = create_row_dollars_chips_row({ localize("k_round"), localize("k_lower_score") }, {
		{
			n = G.UIT.O,
			config = {
				w = 0.5,
				h = 0.5,
				object = get_stake_sprite((G and G.GAME and G.GAME.stake or nil) or 1, 0.5),
				hover = true,
				can_collide = false,
			},
		},
		{ n = G.UIT.B, config = { w = 0.1, h = 0.1 } },
		{
			n = G.UIT.T,
			config = {
				ref_table = G.GAME,
				ref_value = "chips_text",
				lang = G.LANGUAGES["en-us"],
				scale = 0.85,
				colour = G.C.WHITE,
				id = "chip_UI_count",
				func = "chip_UI_set",
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
	local hud = (G and G.HUD) or nil
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

local function recalc_row_dollars_chips_layout()
	local row_dollars_chips = BALATRO.get_hud_element_by_id and BALATRO.get_hud_element_by_id("row_dollars_chips")
	if row_dollars_chips and row_dollars_chips.recalculate then
		row_dollars_chips:recalculate()
	end
	BALATRO.recalculate_ui((G and G.HUD or nil))
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
		recalc_row_dollars_chips_layout()
		if MP.UI.refresh_shared_score_ui then
			MP.UI.refresh_shared_score_ui()
		end
	end
end

function MP.UI.refresh_shared_score_ui()
	if not (MP.LOBBY and MP.LOBBY.code and uses_cooperative_shared_score()) then
		return
	end

	local target_score = get_cooperative_shared_display_score()
	local display_score = ensure_coop_display_score()
	if not (display_score and MP.INSANE_INT) then
		return
	end

	if MP.INSANE_INT.greater_than(target_score, display_score) then
		display_score._mp_score_ease_target = MP.INSANE_INT.to_safe_number(target_score)
		MP.INSANE_INT.ease_display_score(display_score, target_score, { delay = 0.5 })

		local chip_UI = BALATRO.get_hud_element_by_id and BALATRO.get_hud_element_by_id("chip_UI_count")
		if chip_UI and chip_UI.juice_up then
			chip_UI:juice_up(0.3, 0.3)
		end
		if play_sound then
			play_sound("chips2")
		end
	elseif not are_scores_equal(target_score, display_score) then
		display_score._mp_score_ease_target = nil
		MP.INSANE_INT.copy_into(display_score, target_score)
	end
end
