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

local function create_row_dollars_chips_label_line(text)
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0, maxw = 1.3 },
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

local function create_row_dollars_chips_label_column(label_lines)
	return {
		n = G.UIT.C,
		config = { align = "cm", minw = 1.3 },
		nodes = {
			create_row_dollars_chips_label_line(label_lines[1]),
			create_row_dollars_chips_label_line(label_lines[2]),
		},
	}
end

local function create_row_dollars_chips_value_panel(value_nodes)
	return {
		n = G.UIT.C,
		config = { align = "cm", minw = 3.3, minh = 0.7, r = 0.1, colour = G.C.DYN_UI.BOSS_DARK },
		nodes = value_nodes,
	}
end

local function create_row_dollars_chips_row(label_lines, value_nodes)
	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.1 },
		nodes = {
			create_row_dollars_chips_label_column(label_lines),
			create_row_dollars_chips_value_panel(value_nodes),
		},
	}
end

local function create_enemy_location_row()
	return create_row_dollars_chips_row(localize("ml_enemy_loc"), {
		{
			n = G.UIT.T,
			config = {
				ref_table = MP.GAME.enemy,
				ref_value = "location",
				scale = 0.35,
				colour = G.C.WHITE,
				id = "chip_UI_count",
				shadow = true,
			},
		},
	})
end

local function create_shared_score_row()
	local score_labels = get_round_score_labels()

	return create_row_dollars_chips_row({ score_labels.top, score_labels.bottom }, {
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
