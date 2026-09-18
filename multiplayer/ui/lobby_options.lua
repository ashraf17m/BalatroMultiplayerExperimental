-- Consolidated Lobby Options & Settings Module
-- Replaces 7 fragmented files with a unified, cohesive vertical module.

MP.UI = MP.UI or {}
MP.UI.LOBBY_OPTION_CYCLE_SPECS = MP.UI.LOBBY_OPTION_CYCLE_SPECS or {}
MP.UI.LOBBY_OPTION_CYCLE_UI_STATES = MP.UI.LOBBY_OPTION_CYCLE_UI_STATES or {}
local view_model = MP.UI
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

-- ============================================================================
-- SECTION 1: LOBBY OPTION STATE, SPECS & NORMALIZATION
-- (Consolidated from lobby_option_state.lua)
-- ============================================================================



function view_model.get_lobby_option_value_index(options, value)
	for i, option_value in ipairs(options or {}) do
		if option_value == value then
			return i
		end
	end
	return nil
end

local function build_number_range(min_value, max_value)
	local values = {}
	for value = min_value, max_value do
		values[#values + 1] = value
	end
	return values
end

local function resolve_spec_value(value, spec)
	if type(value) == "function" then
		return value(spec)
	end
	return value
end

function view_model.get_lobby_option_spec_values(spec)
	if not spec then
		return {}
	end

	return resolve_spec_value(spec.option_values, spec)
		or resolve_spec_value(spec.options, spec)
		or {}
end

function view_model.get_lobby_option_spec_display_options(spec)
	if not spec then
		return {}
	end

	return resolve_spec_value(spec.display_options, spec)
		or resolve_spec_value(spec.options, spec)
		or view_model.get_lobby_option_spec_values(spec)
end

local function is_coop_gamemode_selected()
	return MP.is_coop_gamemode and MP.is_coop_gamemode()
end

local function is_head_to_head_lobby_selected()
	return MP.LOBBY and MP.LOBBY.lobby_type == MP.LOBBY_TYPES.ONE_V_ONE
end

local function is_duels_lobby_selected()
	return MP.LOBBY and MP.LOBBY.lobby_type == MP.LOBBY_TYPES.DUELS
end

local function is_teams_lobby_selected()
	return MP.is_teams_mode and MP.is_teams_mode()
end

local function is_full_shared_progress_lobby_selected()
	return is_teams_lobby_selected() or is_coop_gamemode_selected()
end

local function is_party_scoring_locked()
	return is_head_to_head_lobby_selected() or is_duels_lobby_selected()
end

local GROUP_SCORING_RULE_SPECS = {
	{ value = "highest", label_key = "k_highest_score" },
	{ value = "average", label_key = "k_beat_average" },
	{ value = "median", label_key = "k_median" },
	{ value = "geometric", label_key = "k_geometric" },
	{ value = "custom", label_key = "k_custom_score" },
}

local function is_valid_group_scoring_rule(value)
	for _, spec in ipairs(GROUP_SCORING_RULE_SPECS) do
		if spec.value == value then
			return true
		end
	end
	return false
end

local LOCKED_GROUP_SCORING_SPECS = { GROUP_SCORING_RULE_SPECS[1] }
local LOCKED_GROUP_SCORING_VALUES = { "highest" }
local ALL_GROUP_SCORING_VALUES = { "highest", "average", "median", "geometric", "custom" }

local function get_group_scoring_rule_specs()
	if is_party_scoring_locked() then
		return LOCKED_GROUP_SCORING_SPECS
	end
	return GROUP_SCORING_RULE_SPECS
end

function view_model.get_group_scoring_rule()
	if is_party_scoring_locked() then
		return "highest"
	end

	local config = MP.LOBBY and MP.LOBBY.config or {}
	if is_valid_group_scoring_rule(config.pvp_score_rule) then
		return config.pvp_score_rule
	end
	return "highest"
end

function view_model.get_group_scoring_rule_values()
	if is_party_scoring_locked() then
		return LOCKED_GROUP_SCORING_VALUES
	end
	return ALL_GROUP_SCORING_VALUES
end

local function get_group_max_player_floor()
	if is_head_to_head_lobby_selected() then
		return 2
	end

	local lobby_context = MP.get_lobby_state_context and MP.get_lobby_state_context() or {}
	local player_count = lobby_context.player_count or 0
	return math.max(MP.MIN_GROUP_LOBBY_PLAYERS, player_count)
end
view_model.get_group_max_player_floor = get_group_max_player_floor

function view_model.get_group_scoring_options()
	local options = {}
	for _, spec in ipairs(get_group_scoring_rule_specs()) do
		options[#options + 1] = localize(spec.label_key)
	end
	return options
end

function view_model.get_group_max_player_options()
	if is_head_to_head_lobby_selected() then
		return { 2 }
	end

	local options = {}
	for i = get_group_max_player_floor(), MP.MAX_GROUP_LOBBY_PLAYERS do
		options[#options + 1] = i
	end
	return options
end

function view_model.normalize_group_max_players(value)
	if is_head_to_head_lobby_selected() then
		return 2
	end

	local parsed = tonumber(value)
	if not parsed then
		parsed = MP.DEFAULT_GROUP_LOBBY_PLAYERS
	end

	parsed = math.floor(parsed)
	return math.max(get_group_max_player_floor(), math.min(MP.MAX_GROUP_LOBBY_PLAYERS, parsed))
end

function view_model.get_custom_winner_max_players()
	return view_model.normalize_group_max_players(MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.max_players)
end

function view_model.get_custom_winner_player_count()
	local max_players = view_model.get_custom_winner_max_players()
	local lobby_context = MP.get_lobby_state_context and MP.get_lobby_state_context() or {}
	local player_count = tonumber(lobby_context.player_count) or 0

	if player_count > 0 then
		return math.max(1, math.min(max_players, math.floor(player_count)))
	end

	return max_players
end

function view_model.get_custom_winner_limit(max_players)
	local resolved_max_players = tonumber(max_players) or view_model.get_custom_winner_player_count()
	return math.max(1, math.floor(resolved_max_players) - 1)
end

function view_model.get_default_custom_winner_count(max_players)
	local resolved_max_players = tonumber(max_players) or view_model.get_custom_winner_max_players()
	return math.min(
		view_model.get_custom_winner_limit(resolved_max_players),
		math.max(1, math.ceil(resolved_max_players / 2))
	)
end

function view_model.normalize_custom_winner_count(value, max_players)
	local max_winners = view_model.get_custom_winner_limit(max_players)
	local parsed = tonumber(value)
	if not parsed then
		parsed = view_model.get_default_custom_winner_count(max_players or view_model.get_custom_winner_player_count())
	end

	return math.max(1, math.min(max_winners, math.floor(parsed)))
end

function view_model.get_custom_winner_count()
	local config = MP.LOBBY and MP.LOBBY.config or {}
	local configured_percent = tonumber(config.pvp_custom_winners_percent)
	if configured_percent and configured_percent > 0 then
		return view_model.get_custom_winner_count_from_percent(configured_percent)
	end
	return view_model.normalize_custom_winner_count(config.pvp_custom_winners)
end

function view_model.get_custom_winner_count_options()
	return build_number_range(1, view_model.get_custom_winner_limit())
end

function view_model.get_custom_winner_percent(winner_count, max_players)
	local resolved_max_players = tonumber(max_players) or view_model.get_custom_winner_player_count()
	return math.max(
		1,
		math.min(100, math.floor(((winner_count or 1) / resolved_max_players) * 100 + 0.5))
	)
end

local function get_custom_winner_percent_basis(player_count)
	return math.max(2, tonumber(player_count) or view_model.get_custom_winner_player_count())
end

function view_model.get_custom_winner_min_percent(max_players)
	local resolved_max_players = get_custom_winner_percent_basis(max_players)
	return view_model.get_custom_winner_percent(1, resolved_max_players)
end

function view_model.get_custom_winner_percent_limit(max_players)
	local resolved_max_players = get_custom_winner_percent_basis(max_players)
	return view_model.get_custom_winner_percent(
		view_model.get_custom_winner_limit(resolved_max_players),
		resolved_max_players
	)
end

local function snap_custom_winner_percent(percent, player_count)
	local basis_player_count = get_custom_winner_percent_basis(player_count)
	local min_percent = view_model.get_custom_winner_min_percent(basis_player_count)
	local max_percent = view_model.get_custom_winner_percent_limit(basis_player_count)
	local parsed_percent = tonumber(percent) or 50

	if max_percent < min_percent then
		min_percent, max_percent = max_percent, min_percent
	end

	parsed_percent = math.max(min_percent, math.min(max_percent, parsed_percent))
	local winner_count = view_model.normalize_custom_winner_count(
		math.floor((basis_player_count * parsed_percent / 100) + 0.5),
		basis_player_count
	)
	return view_model.get_custom_winner_percent(winner_count, basis_player_count)
end

view_model.normalize_custom_winner_percent = snap_custom_winner_percent

function view_model.get_custom_winner_slider_percent(winner_count)
	local config = MP.LOBBY and MP.LOBBY.config or {}
	local configured_percent = tonumber(config.pvp_custom_winners_percent)
	if configured_percent and configured_percent > 0 then
		return view_model.normalize_custom_winner_percent(configured_percent)
	end

	return view_model.get_custom_winner_percent(winner_count)
end

function view_model.get_custom_winner_count_from_percent(percent)
	local player_count = view_model.get_custom_winner_player_count()
	local normalized_percent = view_model.normalize_custom_winner_percent(percent, player_count)
	return view_model.normalize_custom_winner_count(
		math.floor((player_count * normalized_percent / 100) + 0.5),
		player_count
	)
end

function view_model.get_party_mode_values()
	local lobby_context = MP.get_lobby_state_context and MP.get_lobby_state_context() or {}
	local values = {
		MP.LOBBY_TYPES.FFA,
		MP.LOBBY_TYPES.TEAMS,
		MP.LOBBY_TYPES.DUELS,
	}

	if (lobby_context.player_count or 0) <= 2 then
		values[#values + 1] = MP.LOBBY_TYPES.ONE_V_ONE
	end

	return values
end

function view_model.get_party_mode_label(lobby_type)
	if lobby_type == MP.LOBBY_TYPES.TEAMS then
		return localize("k_team")
	elseif lobby_type == MP.LOBBY_TYPES.DUELS then
		return "Duels"
	elseif lobby_type == MP.LOBBY_TYPES.ONE_V_ONE then
		return "1v1"
	end

	return "FFA"
end

function view_model.get_party_mode_options()
	local options = {}
	for _, lobby_type in ipairs(view_model.get_party_mode_values()) do
		options[#options + 1] = view_model.get_party_mode_label(lobby_type)
	end
	return options
end

function view_model.should_show_custom_winners_controls()
	local lobby_context = MP.get_lobby_state_context and MP.get_lobby_state_context() or {}
	if lobby_context.is_coop_gamemode then
		return false
	end
	if is_party_scoring_locked() then
		return false
	end

	return view_model.get_group_scoring_rule() == "custom"
end

local function send_party_options_update(options)
	if view_model.send_party_options_update then
		return view_model.send_party_options_update(options)
	end
	if view_model.send_lobby_options then
		view_model.send_lobby_options(options)
		return true
	end
	return false
end

local function reset_custom_winners_input_state()
	if view_model.reset_custom_winners_input_state then
		view_model.reset_custom_winners_input_state()
	else
		view_model.CUSTOM_WINNERS_SLIDER_LAST_SENT = nil
	end
end

local function apply_local_party_mode_defaults(previous_lobby_type, lobby_type)
	local config = MP.LOBBY and MP.LOBBY.config or nil
	if not config then
		return
	end

	config.team_card_sync = lobby_type == MP.LOBBY_TYPES.TEAMS or lobby_type == MP.LOBBY_TYPES.COOP

	if lobby_type == MP.LOBBY_TYPES.ONE_V_ONE then
		config.max_players = 2
		config.pvp_custom_winners = 1
		config.pvp_custom_winners_percent = 0
		config.pvp_score_rule = "highest"
		return
	end

	if previous_lobby_type == MP.LOBBY_TYPES.ONE_V_ONE then
		config.max_players = MP.DEFAULT_GROUP_LOBBY_PLAYERS
		config.pvp_custom_winners = view_model.get_default_custom_winner_count(config.max_players)
		config.pvp_custom_winners_percent = 50
	end

	if lobby_type == MP.LOBBY_TYPES.DUELS then
		config.pvp_score_rule = "highest"
	end
end

local function apply_local_party_mode(lobby_type)
	if not (MP.LOBBY and MP.LOBBY.lobby_type) then
		return
	end

	local previous_lobby_type = MP.LOBBY.lobby_type
	MP.LOBBY.lobby_type = lobby_type
	apply_local_party_mode_defaults(previous_lobby_type, lobby_type)

	if
		view_model.party_mode_change_requires_group_options_rebuild
		and view_model.party_mode_change_requires_group_options_rebuild(previous_lobby_type, lobby_type)
	then
		if view_model.mark_pending_party_mode_change_rebuilt then
			view_model.mark_pending_party_mode_change_rebuilt(lobby_type)
		end
		if view_model.request_group_options_overlay_refresh then
			view_model.request_group_options_overlay_refresh()
		end
		return
	end

	if view_model.sync_party_options_cycles then
		view_model.sync_party_options_cycles("party_mode_cycle")
	end
end

local function change_party_mode(lobby_type)
	if MP.is_lobby_match_in_progress() then
		return false
	end

	if MP.LOBBY and MP.LOBBY.is_saved_coop_restore then
		return false
	end

	if not (MP.LOBBY and MP.LOBBY.is_host) then
		return false
	end

	if not lobby_type or lobby_type == MP.LOBBY.lobby_type then
		return false
	end

	if view_model.mark_pending_party_mode_change then
		view_model.mark_pending_party_mode_change(lobby_type)
	end
	apply_local_party_mode(lobby_type)
	MP.ACTIONS.set_lobby_type(lobby_type)
	return true
end

local function change_party_scoring_rule(scoring_rule)
	if is_party_scoring_locked() then
		return false
	end

	reset_custom_winners_input_state()
	return send_party_options_update({
		pvp_score_rule = scoring_rule,
	})
end

local function change_party_max_players(max_players)
	if is_head_to_head_lobby_selected() then
		return false
	end

	reset_custom_winners_input_state()
	local normalized_max_players = view_model.normalize_group_max_players(max_players)
	local config = MP.LOBBY and MP.LOBBY.config or {}
	local previous_max_players = view_model.normalize_group_max_players(config.max_players)
	local previous_winners = view_model.normalize_custom_winner_count(config.pvp_custom_winners, previous_max_players)
	local previous_default_winners = view_model.get_default_custom_winner_count(previous_max_players)
	local configured_percent = tonumber(config.pvp_custom_winners_percent)
	local percent_mode = configured_percent and configured_percent > 0
	local normalized_percent = percent_mode and view_model.normalize_custom_winner_percent(configured_percent) or nil
	local normalized_winners = percent_mode
			and view_model.get_custom_winner_count_from_percent(normalized_percent)
		or previous_winners == previous_default_winners
				and view_model.get_default_custom_winner_count(normalized_max_players)
			or view_model.normalize_custom_winner_count(previous_winners, normalized_max_players)

	if MP.LOBBY and MP.LOBBY.config then
		MP.LOBBY.config.max_players = normalized_max_players
		MP.LOBBY.config.pvp_custom_winners = normalized_winners
		if percent_mode then
			MP.LOBBY.config.pvp_custom_winners_percent = normalized_percent
		end
	end
	view_model.CUSTOM_WINNERS_SLIDER_LAST_SENT = normalized_winners
	view_model.CUSTOM_WINNERS_SLIDER_PERCENT_LAST_SENT = normalized_percent
	if view_model.update_custom_winners_count_cycle then
		view_model.update_custom_winners_count_cycle(normalized_winners)
	end
	if view_model.update_custom_winners_percent_slider then
		view_model.update_custom_winners_percent_slider(normalized_winners)
	end

	local options_update = {
		max_players = normalized_max_players,
		pvp_custom_winners = normalized_winners,
	}
	if percent_mode then
		options_update.pvp_custom_winners_percent = normalized_percent
	end
	return send_party_options_update(options_update)
end
view_model.change_party_max_players = change_party_max_players

local function change_custom_winner_count(winner_count)
	if is_party_scoring_locked() then
		return false
	end

	local normalized_count = view_model.normalize_custom_winner_count(winner_count)
	reset_custom_winners_input_state()
	view_model.CUSTOM_WINNERS_SLIDER_LAST_SENT = normalized_count
	view_model.CUSTOM_WINNERS_SLIDER_PERCENT_LAST_SENT = 0
	if MP.LOBBY and MP.LOBBY.config then
		MP.LOBBY.config.pvp_custom_winners = normalized_count
		MP.LOBBY.config.pvp_custom_winners_percent = 0
	end
	if view_model.update_custom_winners_percent_slider then
		view_model.update_custom_winners_percent_slider(normalized_count)
	end
	return send_party_options_update({
		pvp_custom_winners = normalized_count,
		pvp_custom_winners_percent = 0,
	})
end

local starting_lives_values = build_number_range(1, 16)
local bonus_hands_values = build_number_range(0, 4)
local bonus_discards_values = build_number_range(0, 3)
local bonus_consumable_slots_values = build_number_range(0, 2)
local bonus_joker_slots_values = build_number_range(0, 5)
local bonus_money_values = { 0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50 }
local coop_blind_scaling_values = { 1, 1.5, 2, 2.5, 3, 4, 5, 6, 7, 8 }
local coop_blind_curve_values = { 1.0, 1.4, 2.0, 3.0, 4.5, 6.0 }
local round_values = build_number_range(1, 20)
local timer_base_values = { 30, 60, 90, 120, 150, 180, 210, 240 }
local timer_increment_values = { 0, 30, 60, 90, 120, 150, 180 }

local team_options_toggle_ui = { w = 4.9 }
local party_options_cycle_ui = {
	w = 4.9,
	no_pips = false,
	cycle_shoulders = true,
}
-- The player range spans up to ~100 values, so a pip row would not fit.
local party_max_players_cycle_ui = {
	w = 4.9,
	no_pips = true,
	cycle_shoulders = true,
	jump_step = 10,
}
local bonuses_cycle_ui = {
	w = 4.9,
	no_pips = false,
	cycle_shoulders = true,
}

local function build_bonus_display_options(values, prefix)
	local options = {}
	for _, value in ipairs(values or {}) do
		options[#options + 1] = value == 0 and "None" or (prefix or "") .. tostring(value)
	end
	return options
end

local function build_coop_blind_scaling_display_options()
	local options = {}
	for _, value in ipairs(coop_blind_scaling_values) do
		options[#options + 1] = tostring(value) .. "x/player"
	end
	return options
end

local function build_coop_blind_curve_display_options()
	local options = {}
	for _, value in ipairs(coop_blind_curve_values) do
		options[#options + 1] = string.format("%.1f", value)
	end
	return options
end

view_model.coop_blind_scaling_values = coop_blind_scaling_values
view_model.coop_blind_curve_values = coop_blind_curve_values
view_model.build_coop_blind_scaling_display_options = build_coop_blind_scaling_display_options
view_model.build_coop_blind_curve_display_options = build_coop_blind_curve_display_options
MP.UI.coop_blind_scaling_values = coop_blind_scaling_values
MP.UI.coop_blind_curve_values = coop_blind_curve_values
MP.UI.build_coop_blind_scaling_display_options = build_coop_blind_scaling_display_options
MP.UI.build_coop_blind_curve_display_options = build_coop_blind_curve_display_options

local function get_timer_base_multiplier()
	local config_multiplier = MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.timer_base_multiplier
	if config_multiplier then
		return config_multiplier
	end
	local ruleset = MP.current_ruleset and MP.current_ruleset() or nil
	return (ruleset and ruleset.timer_base_multiplier) or 1
end

local function build_timer_base_display_options()
	local multiplier = get_timer_base_multiplier()
	local options = {}
	for idx, value in ipairs(timer_base_values) do
		options[idx] = tostring(value * multiplier) .. "s"
	end
	return options
end

local function safe_localize(key, fallback)
	local ok, result = pcall(localize, key)
	if ok and type(result) == "string" and result ~= "" and result ~= key and result ~= "ERROR" then
		return result
	end
	return fallback
end

local function build_timer_ownership_display_options()
	return {
		safe_localize("k_opts_timer_ownership_anyone", "First Ready"),
		safe_localize("k_opts_timer_ownership_host", "Host Only"),
	}
end

view_model.PARTY_OPTION_TAB_SPECS = {
	general = {
		{
			kind = "cycle",
			spec_id = "party_mode",
			control_id = "party_mode_cycle",
			label_key = "k_lobby_type",
			option_values = function()
				return view_model.get_party_mode_values()
			end,
			display_options = function()
				return view_model.get_party_mode_options()
			end,
			current_value = function()
				return MP.LOBBY and MP.LOBBY.lobby_type
			end,
			on_change = change_party_mode,
			ui_args = party_options_cycle_ui,
			when = function()
				return not is_coop_gamemode_selected()
			end,
		},
		{
			kind = "cycle",
			spec_id = "party_scoring_rule",
			control_id = "party_scoring_rule_cycle",
			label_key = "b_beat_average_mode",
			option_values = function()
				return view_model.get_group_scoring_rule_values()
			end,
			display_options = function()
				return view_model.get_group_scoring_options()
			end,
			current_value = function()
				return view_model.get_group_scoring_rule()
			end,
			on_change = change_party_scoring_rule,
			ui_args = party_options_cycle_ui,
			when = function()
				return not is_coop_gamemode_selected()
			end,
		},
		{
			kind = "cycle",
			spec_id = "party_max_players",
			control_id = "party_max_players_cycle",
			label_key = "b_max_players",
			option_key = "max_players",
			option_values = function()
				return view_model.get_group_max_player_options()
			end,
			current_value = function()
				return view_model.normalize_group_max_players(
					MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.max_players
				)
			end,
			normalize = function(value)
				return view_model.normalize_group_max_players(value)
			end,
			on_change = change_party_max_players,
			ui_args = party_max_players_cycle_ui,
			when = function()
				return not is_head_to_head_lobby_selected()
			end,
		},
		{
			kind = "cycle",
			spec_id = "party_custom_winners",
			control_id = "party_custom_winners_cycle",
			label_key = "k_custom_winners",
			option_key = "pvp_custom_winners",
			option_values = function()
				return view_model.get_custom_winner_count_options()
			end,
			current_value = function()
				return view_model.get_custom_winner_count()
			end,
			normalize = function(value)
				return view_model.normalize_custom_winner_count(value)
			end,
			on_change = change_custom_winner_count,
			ui_args = party_options_cycle_ui,
			when = function()
				return view_model.should_show_custom_winners_controls()
			end,
		},
		{
			kind = "custom",
			id = "party_custom_winners_percent_slider",
			build = function()
				return view_model.create_custom_winners_percent_slider("party_custom_winners_percent_slider")
			end,
			when = function()
				return view_model.should_show_custom_winners_controls()
			end,
		},
		{
			kind = "cycle",
			spec_id = "player_role",
			control_id = "player_role_cycle",
			label_key = "k_role",
			option_values = { "player", "spectator" },
			display_options = function()
				return {
					safe_localize("k_role_player", "Player"),
					safe_localize("k_role_spectator", "Spectator"),
				}
			end,
			current_value = function()
				return (MP.SPECTATOR and MP.SPECTATOR.is_spectator_role) and "spectator" or "player"
			end,
			on_change = function(value)
				-- Role switching is only allowed between matches; the server
				-- rejects mid-match changes as well.
				if G and G.STAGE == G.STAGES.RUN then
					return
				end
				if MP.SPECTATOR and MP.SPECTATOR.set_lobby_role then
					MP.SPECTATOR.set_lobby_role(value)
				end
				if MP.ACTIONS and MP.ACTIONS.spectator_set_role then
					MP.ACTIONS.spectator_set_role(value)
				end
			end,
			enabled_ref_table = { always_enabled = true },
			enabled_ref_value = "always_enabled",
			ui_args = party_options_cycle_ui,
		},
	},
}

view_model.LOBBY_OPTION_TAB_SPECS = {
	gameplay = {
		{ kind = "toggle", control_id = "gold_on_life_loss_toggle", label_key = "b_opts_cb_money", option_key = "gold_on_life_loss" },
		{ kind = "toggle", control_id = "no_gold_on_round_loss_toggle", label_key = "b_opts_no_gold_on_loss", option_key = "no_gold_on_round_loss" },
		{ kind = "toggle", control_id = "death_on_round_loss_toggle", label_key = "b_opts_death_on_loss", option_key = "death_on_round_loss" },
		{ kind = "toggle", control_id = "timer_toggle", label_key = "b_opts_timer", option_key = "timer" },
		{ kind = "toggle", control_id = "disable_asteroid_toggle", label_key = "k_opts_disable_asteroid", option_key = "disable_asteroid" },
	},
	options = {
		{
			kind = "cycle",
			spec_id = "starting_lives",
			control_id = "starting_lives_option",
			label_key = "b_opts_lives",
			option_key = "starting_lives",
			scale = 0.85,
			option_values = starting_lives_values,
			when = function()
				return not is_coop_gamemode_selected()
			end,
		},
		{
			kind = "custom",
			id = "coop_blind_scaling_preview_section",
			build = function()
				return MP.UI.create_coop_blind_scaling_section()
			end,
			when = is_coop_gamemode_selected,
		},
		{ kind = "toggle", control_id = "multiplayer_jokers_toggle", label_key = "b_opts_multiplayer_jokers", option_key = "multiplayer_jokers" },
		{ kind = "toggle", control_id = "different_decks_toggle", label_key = "b_opts_player_diff_deck", option_key = "different_decks" },
		{
			kind = "toggle",
			control_id = "random_loadout_toggle",
			label_key = "b_opts_random_loadout",
			option_key = "random_loadout",
			on_toggle = function(value)
				if MP.LOBBY and MP.LOBBY.config then
					MP.LOBBY.config.random_loadout = not not value
				end
				if MP.UI and MP.UI.request_lobby_main_menu_refresh then
					MP.UI.request_lobby_main_menu_refresh()
				end
				view_model.send_lobby_option_update("random_loadout", not not value)
			end,
		},
		{ kind = "toggle", control_id = "normal_bosses_toggle", label_key = "b_opts_normal_bosses", option_key = "normal_bosses" },
	},
	bonuses = {
		{
			kind = "cycle",
			spec_id = "bonus_hands",
			control_id = "bonus_hands_option",
			label_key = "k_opts_bonus_hands",
			option_key = "bonus_hands",
			scale = 0.85,
			option_values = bonus_hands_values,
			display_options = build_bonus_display_options(bonus_hands_values),
			ui_args = bonuses_cycle_ui,
		},
		{
			kind = "cycle",
			spec_id = "bonus_discards",
			control_id = "bonus_discards_option",
			label_key = "k_opts_bonus_discards",
			option_key = "bonus_discards",
			scale = 0.85,
			option_values = bonus_discards_values,
			display_options = build_bonus_display_options(bonus_discards_values),
			ui_args = bonuses_cycle_ui,
		},
		{
			kind = "cycle",
			spec_id = "bonus_consumable_slots",
			control_id = "bonus_consumable_slots_option",
			label_key = "k_opts_bonus_consumables",
			option_key = "bonus_consumable_slots",
			scale = 0.85,
			option_values = bonus_consumable_slots_values,
			display_options = build_bonus_display_options(bonus_consumable_slots_values),
			ui_args = bonuses_cycle_ui,
		},
		{
			kind = "cycle",
			spec_id = "bonus_joker_slots",
			control_id = "bonus_joker_slots_option",
			label_key = "k_opts_bonus_joker_slots",
			option_key = "bonus_joker_slots",
			scale = 0.85,
			option_values = bonus_joker_slots_values,
			display_options = build_bonus_display_options(bonus_joker_slots_values),
			ui_args = bonuses_cycle_ui,
		},
		{
			kind = "cycle",
			spec_id = "bonus_money",
			control_id = "bonus_money_option",
			label_key = "k_opts_bonus_money",
			option_key = "bonus_money",
			scale = 0.85,
			option_values = bonus_money_values,
			display_options = build_bonus_display_options(bonus_money_values),
			ui_args = bonuses_cycle_ui,
		},
	},
	advanced = {
		{ kind = "toggle", control_id = "preview_disabled_toggle", label_key = "b_opts_disable_preview", option_key = "preview_disabled" },
		{ kind = "toggle", control_id = "order_toggle", label_key = "b_opts_the_order", option_key = "the_order" },
		{
			kind = "toggle",
			control_id = "legacy_smallworld_toggle",
			label_key = "b_opts_legacy_smallworld",
			option_key = "legacy_smallworld",
			when = function()
				return MP.is_layer_active and MP.is_layer_active("smallworld")
			end,
		},
		{
			kind = "toggle",
			control_id = "different_seeds_toggle",
			label_key = "b_opts_diff_seeds",
			option_key = "different_seeds",
		},
	},
	modifiers = {
		{
			kind = "cycle",
			spec_id = "timer_base_seconds",
			control_id = "pvp_timer_seconds_option",
			label_key = "k_opts_pvp_timer",
			option_key = "timer_base_seconds",
			scale = 0.85,
			option_values = timer_base_values,
			display_options = build_timer_base_display_options,
		},
		{
			kind = "cycle",
			spec_id = "timer_increment_seconds",
			control_id = "pvp_timer_increment_seconds_option",
			label_key = "k_opts_pvp_timer_increment",
			option_key = "timer_increment_seconds",
			scale = 0.85,
			option_values = timer_increment_values,
			display_options = { "0s", "30s", "60s", "90s", "120s", "150s", "180s" },
		},
		{
			kind = "cycle",
			spec_id = "timer_ownership",
			control_id = "timer_ownership_option",
			label_key = "k_opts_timer_ownership",
			option_key = "timer_ownership",
			scale = 0.85,
			option_values = { "anyone", "host" },
			display_options = build_timer_ownership_display_options,
		},
		{
			kind = "cycle",
			spec_id = "pvp_start_round",
			control_id = "pvp_round_start_option",
			label_key = "k_opts_pvp_start_round",
			option_key = "pvp_start_round",
			scale = 0.85,
			option_values = round_values,
		},
		{
			kind = "cycle",
			spec_id = "showdown_starting_antes",
			control_id = "showdown_starting_antes_option",
			label_key = "k_opts_showdown_starting_antes",
			option_key = "showdown_starting_antes",
			scale = 0.85,
			option_values = round_values,
		},
	},
	team_options = {
		{
			kind = "toggle",
			control_id = "team_card_sync_toggle",
			label_key = "b_opts_team_card_sync",
			option_key = "team_card_sync",
			ui_args = team_options_toggle_ui,
		},
		{
			kind = "toggle",
			control_id = "team_hand_level_sync_toggle",
			label_key = "b_opts_team_hand_level_sync",
			option_key = "team_hand_level_sync",
			ui_args = team_options_toggle_ui,
			when = is_full_shared_progress_lobby_selected,
		},
		{
			kind = "toggle",
			control_id = "team_money_sync_toggle",
			label_key = "b_opts_team_money_sync",
			option_key = "team_money_sync",
			ui_args = team_options_toggle_ui,
			when = is_full_shared_progress_lobby_selected,
		},
	},
}

-- ============================================================================
-- SECTION 2: PARTY CUSTOM WINNERS CONTROLS
-- (Consolidated from party_custom_winners_control.lua)
-- ============================================================================



local function get_slider_percent_range()
	local min_percent = view_model.get_custom_winner_min_percent
			and view_model.get_custom_winner_min_percent()
		or 1
	local max_percent = view_model.get_custom_winner_percent_limit
			and view_model.get_custom_winner_percent_limit()
		or 100

	if max_percent <= min_percent then
		min_percent = math.max(1, max_percent - 1)
	end

	return min_percent, max_percent
end

local function get_slider_args(slider)
	local track = slider and slider.children and slider.children[1] or nil
	local fill_bar = track and track.children and track.children[1] or nil
	return fill_bar, fill_bar and fill_bar.config and fill_bar.config.ref_table or nil
end

local function set_initial_slider_text(slider, percent)
	local track = slider and slider.nodes and slider.nodes[1] or nil
	local fill_bar = track and track.nodes and track.nodes[1] or nil
	local slider_args = fill_bar and fill_bar.config and fill_bar.config.ref_table or nil
	if slider_args then
		slider_args.text = tostring(percent) .. "%"
	end
end

function view_model.update_custom_winners_percent_slider(winner_count)
	local overlay = G and G.OVERLAY_MENU or nil
	local slider = overlay and overlay.get_UIE_by_ID
		and overlay:get_UIE_by_ID("party_custom_winners_percent_slider")
		or nil
	local fill_bar, slider_args = get_slider_args(slider)
	if not (fill_bar and slider_args and slider_args.ref_table and slider_args.ref_value) then
		return false
	end

	slider_args.min, slider_args.max = get_slider_percent_range()

	local percent = view_model.get_custom_winner_slider_percent
			and view_model.get_custom_winner_slider_percent(winner_count)
		or view_model.get_custom_winner_percent(winner_count)
	percent = math.max(slider_args.min, math.min(slider_args.max, percent))
	slider_args.ref_table[slider_args.ref_value] = percent
	slider_args.text = tostring(percent) .. "%"

	local ratio = 1
	if slider_args.max > slider_args.min then
		ratio = (percent - slider_args.min) / (slider_args.max - slider_args.min)
	end

	fill_bar.config.w = slider_args.w * ratio
	if fill_bar.T then
		fill_bar.T.w = fill_bar.config.w
	end
	return true
end

function view_model.update_custom_winners_count_cycle(winner_count)
	local overlay = G and G.OVERLAY_MENU or nil
	local cycle_config = view_model.LOBBY_OPTION_CYCLE_UI_STATES
		and view_model.LOBBY_OPTION_CYCLE_UI_STATES.party_custom_winners_cycle
	if not (overlay and overlay.get_UIE_by_ID and cycle_config and cycle_config.options) then
		return false
	end

	if view_model.get_custom_winner_count_options then
		cycle_config.options = view_model.get_custom_winner_count_options()
		cycle_config.mp_option_values = cycle_config.options
	end

	local normalized_count = view_model.normalize_custom_winner_count(winner_count)
	local option_values = cycle_config.mp_option_values or cycle_config.options
	local next_index = view_model.get_lobby_option_value_index(option_values, normalized_count)
	if not next_index then
		return false
	end

	local cycle_row = overlay:get_UIE_by_ID("party_custom_winners_cycle")
	if not cycle_row then
		return false
	end

	cycle_config.current_option = next_index
	if cycle_config.current_option_val ~= cycle_config.options[next_index] then
		cycle_config.current_option_val = cycle_config.options[next_index]
	end

	if view_model.sync_lobby_option_cycle_pips then
		return view_model.sync_lobby_option_cycle_pips(overlay, cycle_row, cycle_config)
	end
	return true
end

function view_model.create_custom_winners_percent_slider(id)
	local min_percent, max_percent = get_slider_percent_range()
	local current_winner_count = view_model.get_custom_winner_count()
	local percent = view_model.get_custom_winner_slider_percent
			and view_model.get_custom_winner_slider_percent(current_winner_count)
		or view_model.get_custom_winner_percent(current_winner_count)
	percent = math.max(min_percent, math.min(max_percent, percent))
	local slider_state = {
		percent = percent,
	}
	local slider = create_slider({
		w = 4.165,
		h = 0.34,
		text_scale = 0.3,
		ref_table = slider_state,
		ref_value = "percent",
		min = min_percent,
		max = max_percent,
		decimal_places = 0,
		colour = G.C.RED,
		callback = "change_custom_winners_percent",
	})
	slider.config.id = id
	set_initial_slider_text(slider, percent)

	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.03 },
		nodes = {
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0 },
				nodes = {
					{ n = G.UIT.B, config = { w = 0.8, h = 0.01 } },
					slider,
				},
			},
		},
	}
end

-- ============================================================================
-- SECTION 3: LOBBY OPTION UI CONTROLS & BUILDERS
-- (Consolidated from lobby_option_controls.lua)
-- ============================================================================



local function create_option_page(nodes, minh, minw)
	return {
		n = G.UIT.ROOT,
		config = {
			emboss = 0.05,
			minh = minh or 4,
			r = 0.1,
			minw = minw or 10,
			align = "tm",
			padding = 0.2,
			colour = G.C.BLACK,
		},
		nodes = nodes or {},
	}
end

local function get_compact_option_page_minh(visible_count, minh, args)
	if not (args and args.compact_empty_space) then
		return minh
	end

	visible_count = visible_count or 0
	if visible_count <= 0 then
		return args.compact_empty_minh or 1
	end

	local base_minh = minh or 4
	local row_minh = args.compact_row_minh or 0.86
	local padding_minh = args.compact_padding_minh or 0.75
	local min_minh = args.compact_min_minh or 1.6
	local compact_minh = math.max(min_minh, padding_minh + row_minh * visible_count)

	return math.min(base_minh, compact_minh)
end

local function get_cycle_spec_id(spec)
	return spec.spec_id or spec.id or spec.option_key
end

local function get_cycle_option_values(spec)
	if view_model.get_lobby_option_spec_values then
		return view_model.get_lobby_option_spec_values(spec)
	end

	return spec.option_values or spec.options or {}
end

local function get_cycle_display_options(spec)
	if view_model.get_lobby_option_spec_display_options then
		return view_model.get_lobby_option_spec_display_options(spec)
	end

	return spec.display_options or spec.options or spec.option_values or {}
end

local function get_cycle_current_index(spec)
	local option_values = get_cycle_option_values(spec)
	local current_value = spec.current_value and spec.current_value(spec)
		or (spec.option_key and MP.LOBBY.config[spec.option_key] or nil)
	local current_index = view_model.get_lobby_option_value_index(option_values, current_value)

	return current_index or spec.default_index or spec.current_option or 1
end

local function create_cycle_pip_node(index, scale, selected)
	return {
		n = G.UIT.B,
		config = {
			w = 0.1 * scale,
			h = 0.1 * scale,
			r = 0.05,
			id = "pip_" .. index,
			colour = selected and G.C.WHITE or G.C.BLACK,
		},
	}
end

local function get_cycle_pips_parent(overlay, cycle_row)
	if not cycle_row then
		return nil
	end

	local first_pip = overlay and overlay.get_UIE_by_ID and overlay:get_UIE_by_ID("pip_1", cycle_row) or nil
	return first_pip and first_pip.parent or nil
end

local function sync_cycle_pips(overlay, cycle_row, cycle_config)
	local pips_parent = get_cycle_pips_parent(overlay, cycle_row)
	local option_count = #(cycle_config.options or {})
	if not pips_parent then
		return option_count < 2
	end

	local scale = cycle_config.scale or 1
	local changed = false
	pips_parent.config.padding = (0.05 - (option_count > 15 and 0.03 or 0)) * scale

	if #pips_parent.children ~= option_count then
		for i = #pips_parent.children, 1, -1 do
			pips_parent.children[i]:remove()
			table.remove(pips_parent.children, i)
		end
		for i = 1, option_count do
			pips_parent.UIBox:set_parent_child(
				create_cycle_pip_node(i, scale, cycle_config.current_option == i),
				pips_parent
			)
		end
		changed = true
	end

	for i, pip in ipairs(pips_parent.children) do
		pip.config.id = "pip_" .. i
		pip.config.w = 0.1 * scale
		pip.config.h = 0.1 * scale
		pip.config.r = 0.05
		pip.config.colour = cycle_config.current_option == i and G.C.WHITE or G.C.BLACK
	end

	if changed and pips_parent.UIBox then
		pips_parent.UIBox:recalculate()
	end

	return true
end

view_model.sync_lobby_option_cycle_pips = sync_cycle_pips

function view_model.sync_bound_lobby_option_cycle(control_id)
	local overlay = G and G.OVERLAY_MENU or nil
	local cycle_config = view_model.LOBBY_OPTION_CYCLE_UI_STATES
		and view_model.LOBBY_OPTION_CYCLE_UI_STATES[control_id]
	local spec_id = cycle_config
		and cycle_config.opt_args
		and cycle_config.opt_args.spec_id
	local spec = spec_id and view_model.LOBBY_OPTION_CYCLE_SPECS[spec_id] or nil
	local cycle_row = overlay and overlay.get_UIE_by_ID and overlay:get_UIE_by_ID(control_id) or nil
	if not (cycle_config and spec and cycle_row) then
		return false
	end

	local display_options = get_cycle_display_options(spec)
	local option_values = get_cycle_option_values(spec)
	local current_index = get_cycle_current_index(spec)
	local current_display_value = display_options[current_index]

	cycle_config.options = display_options
	cycle_config.mp_option_values = option_values
	cycle_config.current_option = current_index
	if cycle_config.current_option_val ~= current_display_value then
		cycle_config.current_option_val = current_display_value
	end
	return sync_cycle_pips(overlay, cycle_row, cycle_config)
end

local function add_cycle_jump_buttons(cycle, step)
	local row = cycle and cycle.nodes and cycle.nodes[2]
	row = row and row.nodes and row.nodes[2]
	row = row and row.nodes and row.nodes[1]
	if not (row and row.nodes and row.nodes[1] and row.nodes[3]) then
		return
	end

	local function clone_side(src, text, dir)
		local config = {}
		for key, value in pairs(src.config) do
			config[key] = value
		end
		if config.button then
			config.button = "mp_option_cycle_jump"
			config.jump_step = dir
		end
		local src_text = src.nodes[1].config
		return {
			n = src.n,
			config = config,
			nodes = {
				{
					n = src.nodes[1].n,
					config = {
						text = text,
						scale = src_text.scale,
						colour = src_text.colour,
					},
				},
			},
		}
	end

	local left, right = row.nodes[1], row.nodes[3]
	table.insert(row.nodes, 1, clone_side(left, "<<", -step))
	row.nodes[#row.nodes + 1] = clone_side(right, ">>", step)
end

local function find_cycle_main_node(node)
	if not node then return nil end
	if node.config and node.config.id == "cycle_main" then
		return node
	end
	if node.nodes then
		for _, child in ipairs(node.nodes) do
			local found = find_cycle_main_node(child)
			if found then return found end
		end
	end
	return nil
end

function view_model.create_lobby_option_cycle(id, label_key, scale, options, current_option, callback, opt_args, ui_args)
	local Disableable_Option_Cycle = MP.UI.Disableable_Option_Cycle
	ui_args = ui_args or {}
	opt_args = opt_args or {}
	local custom_hover = opt_args.custom_hover_popup or ui_args.custom_hover_popup
	local cycle_args = {
		id = id,
		enabled_ref_table = opt_args.enabled_ref_table or MP.LOBBY,
		enabled_ref_value = opt_args.enabled_ref_value or "is_host",
		label = opt_args.label or (label_key and localize(label_key)) or "",
		scale = scale,
		options = options,
		current_option = current_option,
		opt_callback = callback,
		opt_args = opt_args,
		w = ui_args.w,
		colour = ui_args.colour,
		no_pips = ui_args.no_pips,
		cycle_shoulders = ui_args.cycle_shoulders,
		on_demand_tooltip = not custom_hover and (opt_args.on_demand_tooltip or ui_args.on_demand_tooltip) or nil,
	}
	local cycle = Disableable_Option_Cycle(cycle_args)
	if id then
		view_model.LOBBY_OPTION_CYCLE_UI_STATES[id] = cycle_args._mp_effective_cycle_args or cycle_args
	end
	if ui_args.jump_step then
		add_cycle_jump_buttons(cycle, ui_args.jump_step)
	end
	if custom_hover then
		local cycle_main = find_cycle_main_node(cycle)
		if cycle_main and cycle_main.config then
			cycle_main.config.func = custom_hover
			cycle_main.config.on_demand_tooltip = nil
			cycle_main.config.hover = true
			cycle_main.config.can_collide = true
		end
	end
	return cycle
end

function view_model.create_lobby_option_toggle(id, label_key, ref_value, callback, label_text, ui_args)
	local Disableable_Toggle = MP.UI.Disableable_Toggle
	ui_args = ui_args or {}
	local toggle_state = {
		[ref_value] = MP.LOBBY.config[ref_value],
	}

	return {
		n = G.UIT.R,
		config = {
			padding = 0,
			align = "cr",
		},
		nodes = {
			Disableable_Toggle({
				id = id,
				enabled_ref_table = MP.LOBBY,
				enabled_ref_value = "is_host",
				label = label_text or localize(label_key),
				ref_table = toggle_state,
				ref_value = ref_value,
				w = ui_args.w,
				h = ui_args.h,
				scale = ui_args.scale,
				label_scale = ui_args.label_scale,
				active_colour = ui_args.active_colour,
				inactive_colour = ui_args.inactive_colour,
				callback = function()
					if callback then
						callback(toggle_state, ref_value)
					else
						view_model.send_lobby_option_update(ref_value, toggle_state[ref_value])
					end
				end,
			}),
		},
	}
end

function view_model.create_bound_lobby_option_cycle(spec)
	local spec_id = get_cycle_spec_id(spec)
	view_model.LOBBY_OPTION_CYCLE_SPECS[spec_id] = spec
	local control_id = spec.control_id or spec.id or (spec.option_key .. "_option")

	local cycle = view_model.create_lobby_option_cycle(
		control_id,
		spec.label_key,
		spec.scale or 0.85,
		get_cycle_display_options(spec),
		get_cycle_current_index(spec),
		"change_bound_lobby_option_cycle",
		{
			spec_id = spec_id,
			label = spec.label,
			enabled_ref_table = spec.enabled_ref_table,
			enabled_ref_value = spec.enabled_ref_value,
			on_demand_tooltip = spec.on_demand_tooltip,
			custom_hover_popup = spec.custom_hover_popup,
		},
		spec.ui_args
	)
	if view_model.LOBBY_OPTION_CYCLE_UI_STATES and view_model.LOBBY_OPTION_CYCLE_UI_STATES[control_id] then
		view_model.LOBBY_OPTION_CYCLE_UI_STATES[control_id].mp_option_values = get_cycle_option_values(spec)
	end

	return cycle
end

function view_model.create_bound_lobby_option_toggle(spec)
	return view_model.create_lobby_option_toggle(
		spec.control_id or spec.id or (spec.option_key .. "_toggle"),
		spec.label_key,
		spec.option_key,
		spec.on_toggle
			and function(toggle_state, option_key)
				spec.on_toggle(toggle_state[option_key], toggle_state, spec)
			end
			or nil,
		spec.label_text,
		spec.ui_args
	)
end

function view_model.build_lobby_option_controls(specs)
	local nodes = {}

	for _, spec in ipairs(specs or {}) do
		if not spec.when or spec.when(spec) then
			local node = nil
			if spec.kind == "toggle" then
				node = view_model.create_bound_lobby_option_toggle(spec)
			elseif spec.kind == "cycle" then
				node = view_model.create_bound_lobby_option_cycle(spec)
			elseif spec.kind == "custom" and spec.build then
				node = spec.build(spec)
			end

			if node then
				nodes[#nodes + 1] = node
			end
		end
	end

	return nodes
end

local function create_centered_option_controls(nodes)
	return {
		{
			n = G.UIT.R,
			config = { padding = 0, align = "cm" },
			nodes = nodes or {},
		},
	}
end

function view_model.create_lobby_option_page(nodes, minh)
	return create_option_page(nodes or {}, minh or 4, 10)
end

function view_model.create_lobby_option_specs_page(specs, minh, args)
	args = args or {}
	local nodes = view_model.build_lobby_option_controls(specs)
	local visible_count = #nodes
	minh = get_compact_option_page_minh(visible_count, minh, args)
	if args.center_controls then
		nodes = create_centered_option_controls(nodes)
	end

	return view_model.create_lobby_option_page(nodes, minh)
end

-- ============================================================================
-- SECTION 4: LOBBY OPTION CONTROLLER & NETWORKING
-- (Consolidated from lobby_option_controller.lua)
-- ============================================================================


local pending_custom_winners_slider_count = nil
local pending_custom_winners_slider_percent = nil

local function get_cycle_next_value(spec, args)
	local option_values = view_model.get_lobby_option_spec_values and view_model.get_lobby_option_spec_values(spec)
		or spec.option_values
		or spec.options
		or {}
	local option_index = tonumber(args and args.to_key)
	local next_value = option_index and option_values[option_index] or option_values[args and args.to_key]
	if next_value == nil then
		next_value = args and args.to_val
	end

	if spec.normalize then
		next_value = spec.normalize(next_value, args, spec)
	end

	return next_value
end

local function send_group_options_update(options)
	if MP.is_lobby_match_in_progress and MP.is_lobby_match_in_progress() then
		return false
	end

	view_model.send_lobby_options(options)
	return true
end

function view_model.send_lobby_options(options)
	MP.ACTIONS.lobby_options(options)
end

function view_model.send_party_options_update(options)
	return send_group_options_update(options)
end

function view_model.send_lobby_option_update(option_key, option_value)
	local value = option_value
	if value == nil then
		value = MP.LOBBY.config[option_key]
	end

	view_model.send_lobby_options({
		[option_key] = value,
	})

	if (option_key == "coop_blind_scaling_per_player" or option_key == "coop_blind_scaling_curve")
		and MP.UI.update_coop_blind_curve_demonstration
	then
		MP.UI.update_coop_blind_curve_demonstration()
	end
end

function view_model.reset_custom_winners_input_state()
	view_model.CUSTOM_WINNERS_SLIDER_LAST_SENT = nil
	view_model.CUSTOM_WINNERS_SLIDER_PERCENT_LAST_SENT = nil
	pending_custom_winners_slider_count = nil
	pending_custom_winners_slider_percent = nil
end

function G.FUNCS.change_bound_lobby_option_cycle(args)
	local opt_args = args and args.cycle_config and args.cycle_config.opt_args or nil
	local spec = opt_args and view_model.LOBBY_OPTION_CYCLE_SPECS[opt_args.spec_id] or nil
	if not spec then
		return
	end

	local next_value = get_cycle_next_value(spec, args)

	if spec.on_change then
		spec.on_change(next_value, args, spec)
	else
		view_model.send_lobby_option_update(spec.option_key, next_value)
	end
end

function G.FUNCS.mp_option_cycle_jump(e)
	local cfg = e.config.ref_table
	local from = cfg.current_option
	local to = math.max(1, math.min(#cfg.options, from + e.config.jump_step))
	if to == from then
		return
	end
	cfg.current_option = to
	cfg.current_option_val = cfg.options[to]
	G.FUNCS[cfg.opt_callback]({
		from_val = cfg.options[from],
		to_val = cfg.current_option_val,
		from_key = from,
		to_key = to,
		cycle_config = cfg,
	})
end

local function flush_custom_winners_slider_change()
	if not pending_custom_winners_slider_count then
		return false
	end

	if BALATRO.is_controller_mouse_dragging and BALATRO.is_controller_mouse_dragging() then
		return false
	end

	local winner_count = pending_custom_winners_slider_count
	local winner_percent = pending_custom_winners_slider_percent
	pending_custom_winners_slider_count = nil
	pending_custom_winners_slider_percent = nil

	if
		MP.UI.CUSTOM_WINNERS_SLIDER_LAST_SENT == winner_count
		and MP.UI.CUSTOM_WINNERS_SLIDER_PERCENT_LAST_SENT == winner_percent
	then
		return false
	end
	MP.UI.CUSTOM_WINNERS_SLIDER_LAST_SENT = winner_count
	MP.UI.CUSTOM_WINNERS_SLIDER_PERCENT_LAST_SENT = winner_percent

	return send_group_options_update({
		pvp_custom_winners = winner_count,
		pvp_custom_winners_percent = winner_percent,
	})
end

function G.FUNCS.change_custom_winners_percent(slider_config)
	if not (MP.LOBBY and MP.LOBBY.is_host) then
		return
	end

	local slider_state = slider_config and slider_config.ref_table or nil
	local percent_key = slider_config and slider_config.ref_value or nil
	local raw_percent = slider_state and percent_key and slider_state[percent_key] or nil
	local winner_count = view_model.get_custom_winner_count_from_percent(raw_percent)
	local normalized_percent = view_model.normalize_custom_winner_percent
			and view_model.normalize_custom_winner_percent(raw_percent)
		or view_model.get_custom_winner_percent(winner_count)

	if MP.LOBBY and MP.LOBBY.config then
		MP.LOBBY.config.pvp_custom_winners = winner_count
		MP.LOBBY.config.pvp_custom_winners_percent = normalized_percent
	end
	if slider_state and percent_key then
		slider_state[percent_key] = normalized_percent
	end
	if slider_config then
		slider_config.text = tostring(normalized_percent) .. "%"
	end
	if view_model.update_custom_winners_percent_slider then
		view_model.update_custom_winners_percent_slider(winner_count)
	end
	if view_model.update_custom_winners_count_cycle then
		view_model.update_custom_winners_count_cycle(winner_count)
	end

	pending_custom_winners_slider_count = winner_count
	pending_custom_winners_slider_percent = normalized_percent
	return flush_custom_winners_slider_change()
end

if MP.GAME_UPDATE_CYCLE and MP.GAME_UPDATE_CYCLE.register_after then
	MP.GAME_UPDATE_CYCLE.register_after(
		"mp.ui.custom_winners_slider_flush",
		flush_custom_winners_slider_change,
		110
	)
end

-- ============================================================================
-- SECTION 5: GROUP OPTIONS OVERLAY
-- (Consolidated from lobby_group_options.lua)
-- ============================================================================

local function should_show_custom_winners_controls()
	return not not (MP.UI.should_show_custom_winners_controls and MP.UI.should_show_custom_winners_controls())
end

local active_group_options_tab = "general"
local pending_party_mode_change = nil

local function is_head_to_head_lobby_type(lobby_type)
	return MP.LOBBY_TYPES and lobby_type == MP.LOBBY_TYPES.ONE_V_ONE
end

local function is_duels_lobby_type(lobby_type)
	return MP.LOBBY_TYPES and lobby_type == MP.LOBBY_TYPES.DUELS
end

local function is_teams_lobby_type(lobby_type)
	local lobby_type_spec = MP.get_lobby_type_spec and MP.get_lobby_type_spec(lobby_type) or nil
	return not not (lobby_type_spec and lobby_type_spec.uses_teams)
end

local function is_scoring_locked_lobby_type(lobby_type)
	return is_head_to_head_lobby_type(lobby_type) or is_duels_lobby_type(lobby_type)
end

local function party_mode_change_requires_rebuild(previous_lobby_type, lobby_type)
	return is_scoring_locked_lobby_type(previous_lobby_type)
		or is_scoring_locked_lobby_type(lobby_type)
		or is_teams_lobby_type(previous_lobby_type) ~= is_teams_lobby_type(lobby_type)
end

function MP.UI.party_mode_change_requires_group_options_rebuild(previous_lobby_type, lobby_type)
	return party_mode_change_requires_rebuild(previous_lobby_type, lobby_type)
end

function MP.UI.mark_pending_party_mode_change(lobby_type)
	pending_party_mode_change = {
		from = MP.LOBBY and MP.LOBBY.lobby_type,
		to = lobby_type,
		rebuilt = false,
	}
end

function MP.UI.mark_pending_party_mode_change_rebuilt(lobby_type)
	if pending_party_mode_change and pending_party_mode_change.to == lobby_type then
		pending_party_mode_change.rebuilt = true
		return true
	end
	return false
end

function MP.UI.should_refresh_group_options_for_lobby_type_change(previous_lobby_type, lobby_type)
	local pending_change = pending_party_mode_change
	local is_pending_party_mode_change = pending_change and pending_change.to == lobby_type
	if is_pending_party_mode_change then
		pending_party_mode_change = nil
	end

	if not (G and G.OVERLAY_MENU and G.OVERLAY_MENU.is_mp_group_options) then
		return true
	end

	if is_pending_party_mode_change then
		if pending_change.rebuilt then
			return false
		end
		if party_mode_change_requires_rebuild(pending_change.from or previous_lobby_type, lobby_type) then
			return true
		end
		if MP.UI.sync_party_options_cycles and MP.UI.sync_party_options_cycles("party_mode_cycle") then
			return false
		end
		return party_mode_change_requires_rebuild(previous_lobby_type, lobby_type)
	end

	return previous_lobby_type ~= lobby_type
end

function MP.UI.sync_party_options_cycles(skip_control_id)
	local overlay = G and G.OVERLAY_MENU or nil
	if not (overlay and overlay.is_mp_group_options) then
		return false
	end

	local synced = false
	for _, control_id in ipairs({
		"party_mode_cycle",
		"party_scoring_rule_cycle",
		"party_max_players_cycle",
		"party_custom_winners_cycle",
	}) do
		if control_id ~= skip_control_id and MP.UI.sync_bound_lobby_option_cycle then
			synced = MP.UI.sync_bound_lobby_option_cycle(control_id) or synced
		end
	end

	if MP.UI.update_custom_winners_percent_slider and MP.UI.get_custom_winner_count then
		synced = MP.UI.update_custom_winners_percent_slider(MP.UI.get_custom_winner_count()) or synced
	end

	return synced
end

local function create_group_advanced_tab()
	return MP.UI.create_lobby_option_specs_page(
		MP.UI.PARTY_OPTION_TAB_SPECS and MP.UI.PARTY_OPTION_TAB_SPECS.general,
		4,
		{ center_controls = true, compact_empty_space = true }
	)
end

local function create_team_options_tab()
	return MP.UI.create_lobby_option_specs_page(
		MP.UI.LOBBY_OPTION_TAB_SPECS.team_options,
		3,
		{ compact_empty_space = true }
	)
end

local function is_group_options_tab_available(tab_id, lobby_context)
	if tab_id == "shared_progress" then
		return lobby_context.can_show_shared_progress_options
	end

	return tab_id == "general"
end

local function create_group_options_tab_definition(tab_id, label, build)
	return {
		label = label,
		chosen = active_group_options_tab == tab_id,
		tab_definition_function = function()
			active_group_options_tab = tab_id
			return build()
		end,
	}
end

local function create_group_options_tab()
	local lobby_context = MP.get_lobby_state_context and MP.get_lobby_state_context() or {}
	if not is_group_options_tab_available(active_group_options_tab, lobby_context) then
		active_group_options_tab = "general"
	end

	local tabs = {
		create_group_options_tab_definition(
			"general",
			localize("k_lobby_general"),
			create_group_advanced_tab
		),
	}
	if lobby_context.can_show_shared_progress_options then
		tabs[#tabs + 1] = create_group_options_tab_definition(
			"shared_progress",
			localize("k_team_options"),
			create_team_options_tab
		)
	end

	local contents = {}
	contents[#contents + 1] = {
		n = G.UIT.R,
		config = {
			padding = 0,
			align = "cm",
		},
		nodes = {
			create_tabs({
				snap_to_nav = true,
				colour = G.C.BOOSTER,
				tabs = tabs,
			}),
		},
	}

	return create_UIBox_generic_options({
		contents = contents,
	})
end

local function open_group_options_overlay(silent)
	local config = silent and { offset = { x = 0, y = 0 } } or nil
	local previous_jiggle = silent and G and G.ROOM and G.ROOM.jiggle or nil

	G.FUNCS.overlay_menu({
		definition = create_group_options_tab(),
		config = config,
	})

	if previous_jiggle and G and G.ROOM then
		G.ROOM.jiggle = previous_jiggle
	end

	if G.OVERLAY_MENU then
		G.OVERLAY_MENU.is_mp_group_options = true
	end
end

function G.FUNCS.view_group_options(e)
	if MP.is_lobby_match_in_progress() then
		return
	end

	if MP.LOBBY and MP.LOBBY.is_saved_coop_restore then
		return
	end

	open_group_options_overlay(false)
end

function MP.UI.refresh_group_options_overlay()
	if not (G and G.OVERLAY_MENU and G.OVERLAY_MENU.is_mp_group_options and G.FUNCS and G.FUNCS.view_group_options) then
		return false
	end

	open_group_options_overlay(true)
	return true
end

local function has_option(options, key)
	return type(options) == "table" and options[key] ~= nil
end

local function custom_winners_controls_visible()
	return not not (G
		and G.OVERLAY_MENU
		and G.OVERLAY_MENU:get_UIE_by_ID("party_custom_winners_cycle") ~= nil)
end

local function is_lobby_type_lock_option_batch(options)
	return has_option(options, "pvp_score_rule")
		and has_option(options, "max_players")
		and has_option(options, "pvp_custom_winners")
end

function MP.UI.should_refresh_group_options_for_lobby_options(options)
	if not (G and G.OVERLAY_MENU and G.OVERLAY_MENU.is_mp_group_options) then
		return false
	end

	if not (MP.LOBBY and MP.LOBBY.is_host) then
		return true
	end

	if type(options) ~= "table" then
		return false
	end

	if pending_party_mode_change then
		if pending_party_mode_change.rebuilt then
			return false
		end
		if party_mode_change_requires_rebuild(pending_party_mode_change.from, pending_party_mode_change.to) then
			pending_party_mode_change.rebuilt = true
			return true
		end
		if MP.UI.sync_party_options_cycles then
			MP.UI.sync_party_options_cycles("party_mode_cycle")
		end
		return false
	end

	if is_lobby_type_lock_option_batch(options) then
		return false
	end

	if options.gamemode ~= nil then
		return true
	end

	if has_option(options, "pvp_score_rule") then
		return should_show_custom_winners_controls() ~= custom_winners_controls_visible()
	end

	if has_option(options, "max_players") then
		return false
	end

	if has_option(options, "pvp_custom_winners") then
		return false
	end

	return false
end

-- ============================================================================
-- SECTION 6: ADVANCED OPTIONS & CUSTOM SEED
-- (Consolidated from lobby_options_advanced_tab.lua)
-- ============================================================================

MP.UI.CUSTOM_SEED_INPUT_STATE = MP.UI.CUSTOM_SEED_INPUT_STATE or { enabled = false }

local function normalize_custom_seed(value)
	value = tostring(value or "")
	return value == "" and "random" or value
end

local function get_custom_seed_input_value()
	return MP.LOBBY.config.custom_seed == "random" and "" or MP.LOBBY.config.custom_seed
end

local function get_custom_seed_disabled_text()
	local seed = get_custom_seed_input_value()
	return seed ~= "" and seed or localize("b_set_custom_seed")
end

local function update_custom_seed(value)
	MP.UI.send_lobby_option_update("custom_seed", normalize_custom_seed(value))
end

local function is_custom_seed_editable()
	return not not (MP.LOBBY.is_host and not MP.LOBBY.config.different_seeds)
end

local function create_custom_seed_reset_button()
	return MP.UI.Disableable_Button({
		id = "custom_seed_reset",
		button = "custom_seed_reset",
		colour = G.C.RED,
		minw = 1.65,
		minh = 0.6,
		label = {
			localize("b_reset"),
		},
		disabled_text = {
			localize("b_reset"),
		},
		scale = 0.45,
		col = true,
		enabled_ref_table = MP.UI.CUSTOM_SEED_INPUT_STATE,
		enabled_ref_value = "enabled",
	})
end

function G.FUNCS.custom_seed_reset(e)
	update_custom_seed("random")
end

local function create_custom_seed_text_input()
	return create_text_input({
		w = 3.65,
		h = 0.6,
		text_scale = 0.36,
		max_length = 8,
		all_caps = true,
		ref_table = MP.LOBBY.setup,
		ref_value = "temp_seed",
		prompt_text = localize("b_set_custom_seed"),
		keyboard_offset = 4,
		callback = function()
			update_custom_seed(MP.LOBBY.setup.temp_seed)
		end,
	})
end

local function create_disabled_custom_seed_input()
	return {
		n = G.UIT.C,
		config = {
			align = "cm",
			padding = 0.05,
			r = 0.1,
			minw = 3.65,
			minh = 0.6,
			colour = G.C.UI.BACKGROUND_INACTIVE,
			shadow = true,
		},
		nodes = {
			{
				n = G.UIT.T,
				config = {
					scale = 0.36,
					text = get_custom_seed_disabled_text(),
					colour = G.C.UI.TEXT_INACTIVE,
					shadow = false,
				},
			},
		},
	}
end

local function prepare_custom_seed_input_state()
	if MP.LOBBY then
		MP.LOBBY.setup = MP.LOBBY.setup or {}
		MP.LOBBY.setup.temp_seed = get_custom_seed_input_value()
	end
	MP.UI.CUSTOM_SEED_INPUT_STATE = {
		enabled = is_custom_seed_editable(),
	}
end

local function create_custom_seed_control_nodes()
	prepare_custom_seed_input_state()
	local seed_input_node = create_disabled_custom_seed_input()
	if MP.UI.CUSTOM_SEED_INPUT_STATE.enabled then
		seed_input_node = create_custom_seed_text_input()
	end

	return {
		seed_input_node,
		{
			n = G.UIT.B,
			config = {
				w = 0.1,
				h = 0.1,
			},
		},
		create_custom_seed_reset_button(),
	}
end

function MP.UI.refresh_custom_seed_controls()
	local overlay = G and G.OVERLAY_MENU or nil
	local controls_row = overlay and overlay.get_UIE_by_ID and overlay:get_UIE_by_ID("custom_seed_controls_row") or nil
	if not (controls_row and controls_row.children and controls_row.UIBox and controls_row.UIBox.set_parent_child) then
		return false
	end

	if G.CONTROLLER then
		G.CONTROLLER.text_input_hook = nil
	end

	for i = #controls_row.children, 1, -1 do
		controls_row.children[i]:remove()
		table.remove(controls_row.children, i)
	end
	for _, node in ipairs(create_custom_seed_control_nodes()) do
		controls_row.UIBox:set_parent_child(node, controls_row)
	end
	controls_row.UIBox:recalculate()
	return true
end

local function create_custom_seed_section()
	return {
		n = G.UIT.R,
		config = { padding = 0.2, align = "cr" },
		nodes = {
			{
				n = G.UIT.C,
				config = {
					padding = 0,
					align = "cm",
				},
				nodes = {
					{
						n = G.UIT.R,
						config = {
							padding = 0,
							align = "cm",
						},
						nodes = {
							{
								n = G.UIT.T,
								config = {
									scale = 0.45,
									text = localize("b_set_custom_seed"),
									colour = G.C.UI.TEXT_LIGHT,
								},
							},
						},
					},
					{
						n = G.UIT.R,
						config = {
							id = "custom_seed_controls_row",
							padding = 0.1,
							align = "cm",
						},
						nodes = create_custom_seed_control_nodes(),
					},
				},
			},
		},
	}
end

function MP.UI.create_advanced_options_tab()
	local nodes = MP.UI.build_lobby_option_controls(MP.UI.LOBBY_OPTION_TAB_SPECS.advanced)
	nodes[#nodes + 1] = create_custom_seed_section()

	return MP.UI.create_lobby_option_page(nodes, 4)
end

function MP.UI.update_lobby_option_toggle(option_key)
	if G.OVERLAY_MENU and MP.LOBBY and MP.LOBBY.config then
		local config_uie = G.OVERLAY_MENU:get_UIE_by_ID(option_key .. "_toggle")
		local config = config_uie and config_uie.config or nil
		if config and config.ref_table and config.ref_value then
			config.ref_table[config.ref_value] = MP.LOBBY.config[option_key]
		end
	end
end

local function refresh_seed_options_in_place(options)
	if type(options) ~= "table" or (options.different_seeds == nil and options.custom_seed == nil) then
		return false
	end

	if MP.UI.refresh_custom_seed_controls then
		MP.UI.refresh_custom_seed_controls()
	end
	return true
end

function MP.UI.refresh_lobby_options_tab(options)
	if not (G.OVERLAY_MENU and G.OVERLAY_MENU:get_UIE_by_ID("lobby_options_overlay")) then
		return false
	end
	local synced = false
	if refresh_seed_options_in_place(options) then
		synced = true
	end
	if MP.UI.sync_bound_lobby_option_cycle then
		if MP.UI.sync_bound_lobby_option_cycle("coop_blind_scaling_per_player_option") then
			synced = true
		end
		if MP.UI.sync_bound_lobby_option_cycle("coop_blind_scaling_curve_option") then
			synced = true
		end
	end
	if MP.UI.update_coop_blind_curve_demonstration then
		if MP.UI.update_coop_blind_curve_demonstration() then
			synced = true
		end
	end
	return synced
end

function MP.UI.create_lobby_options_tab()
	return MP.UI.create_lobby_option_specs_page(MP.UI.LOBBY_OPTION_TAB_SPECS.options, 4)
end

function MP.UI.create_gameplay_options_tab()
	return MP.UI.create_lobby_option_specs_page(MP.UI.LOBBY_OPTION_TAB_SPECS.gameplay, 3)
end

function MP.UI.create_gamemode_modifiers_tab()
	return MP.UI.create_lobby_option_specs_page(MP.UI.LOBBY_OPTION_TAB_SPECS.modifiers, 6, {
		center_controls = true,
	})
end

function MP.UI.create_bonuses_options_tab()
	return MP.UI.create_lobby_option_specs_page(MP.UI.LOBBY_OPTION_TAB_SPECS.bonuses, 6, {
		center_controls = true,
	})
end

