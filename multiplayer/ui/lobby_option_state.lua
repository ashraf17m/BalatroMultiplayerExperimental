MP.UI = MP.UI or {}
MP.UI.LOBBY_OPTION_CYCLE_SPECS = MP.UI.LOBBY_OPTION_CYCLE_SPECS or {}

local view_model = MP.UI

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

local function get_group_scoring_rule_specs()
	if is_party_scoring_locked() then
		return { GROUP_SCORING_RULE_SPECS[1] }
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
	local values = {}
	for _, spec in ipairs(get_group_scoring_rule_specs()) do
		values[#values + 1] = spec.value
	end
	return values
end

local function get_group_max_player_floor()
	if is_head_to_head_lobby_selected() then
		return 2
	end

	local lobby_context = MP.get_lobby_state_context and MP.get_lobby_state_context() or {}
	local player_count = lobby_context.player_count or 0
	return math.max(MP.MIN_GROUP_LOBBY_PLAYERS, player_count)
end

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

function view_model.get_custom_winner_limit(max_players)
	local resolved_max_players = tonumber(max_players) or view_model.get_custom_winner_max_players()
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
		parsed = view_model.get_default_custom_winner_count(max_players or view_model.get_custom_winner_max_players())
	end

	return math.max(1, math.min(max_winners, math.floor(parsed)))
end

function view_model.get_custom_winner_count()
	local config = MP.LOBBY and MP.LOBBY.config or {}
	return view_model.normalize_custom_winner_count(config.pvp_custom_winners)
end

function view_model.get_custom_winner_count_options()
	return build_number_range(1, view_model.get_custom_winner_limit())
end

function view_model.get_custom_winner_percent(winner_count, max_players)
	local resolved_max_players = tonumber(max_players) or view_model.get_custom_winner_max_players()
	return math.max(
		1,
		math.min(100, math.floor(((winner_count or 1) / resolved_max_players) * 100 + 0.5))
	)
end

function view_model.get_custom_winner_min_percent(max_players)
	local resolved_max_players = tonumber(max_players) or view_model.get_custom_winner_max_players()
	return view_model.get_custom_winner_percent(1, resolved_max_players)
end

function view_model.get_custom_winner_percent_limit(max_players)
	local resolved_max_players = tonumber(max_players) or view_model.get_custom_winner_max_players()
	return view_model.get_custom_winner_percent(
		view_model.get_custom_winner_limit(resolved_max_players),
		resolved_max_players
	)
end

function view_model.get_custom_winner_count_from_percent(percent)
	local max_players = view_model.get_custom_winner_max_players()
	local min_percent = view_model.get_custom_winner_min_percent(max_players)
	local max_percent = view_model.get_custom_winner_percent_limit(max_players)
	local default_percent = view_model.get_custom_winner_percent(
		view_model.get_default_custom_winner_count(max_players),
		max_players
	)
	local normalized_percent = math.max(
		min_percent,
		math.min(max_percent, tonumber(percent) or default_percent)
	)
	return view_model.normalize_custom_winner_count(math.floor((max_players * normalized_percent / 100) + 0.5))
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
		config.pvp_score_rule = "highest"
		return
	end

	if previous_lobby_type == MP.LOBBY_TYPES.ONE_V_ONE then
		config.max_players = MP.DEFAULT_GROUP_LOBBY_PLAYERS
		config.pvp_custom_winners = view_model.get_default_custom_winner_count(config.max_players)
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
	local normalized_winners = previous_winners == previous_default_winners
		and view_model.get_default_custom_winner_count(normalized_max_players)
		or view_model.normalize_custom_winner_count(previous_winners, normalized_max_players)

	if MP.LOBBY and MP.LOBBY.config then
		MP.LOBBY.config.max_players = normalized_max_players
		MP.LOBBY.config.pvp_custom_winners = normalized_winners
	end
	view_model.CUSTOM_WINNERS_SLIDER_LAST_SENT = normalized_winners
	if view_model.update_custom_winners_count_cycle then
		view_model.update_custom_winners_count_cycle(normalized_winners)
	end
	if view_model.update_custom_winners_percent_slider then
		view_model.update_custom_winners_percent_slider(normalized_winners)
	end

	return send_party_options_update({
		max_players = normalized_max_players,
		pvp_custom_winners = normalized_winners,
	})
end

local function change_custom_winner_count(winner_count)
	if is_party_scoring_locked() then
		return false
	end

	local normalized_count = view_model.normalize_custom_winner_count(winner_count)
	reset_custom_winners_input_state()
	view_model.CUSTOM_WINNERS_SLIDER_LAST_SENT = normalized_count
	if MP.LOBBY and MP.LOBBY.config then
		MP.LOBBY.config.pvp_custom_winners = normalized_count
	end
	if view_model.update_custom_winners_percent_slider then
		view_model.update_custom_winners_percent_slider(normalized_count)
	end
	return send_party_options_update({
		pvp_custom_winners = normalized_count,
	})
end

local starting_lives_values = build_number_range(1, 16)
local coop_blind_scaling_values = { 1, 1.5, 2, 2.5, 3, 4, 5, 6, 7, 8 }
local round_values = build_number_range(1, 20)
local timer_base_values = { 30, 60, 90, 120, 150, 180, 210, 240 }
local timer_increment_values = { 0, 30, 60, 90, 120, 150, 180 }
local pvp_countdown_values = { 0, 3, 5, 10 }

local team_options_toggle_ui = { w = 4.9 }
local party_options_cycle_ui = {
	w = 4.9,
	no_pips = false,
	cycle_shoulders = true,
}

local function build_coop_blind_scaling_display_options()
	local options = {}
	for _, value in ipairs(coop_blind_scaling_values) do
		options[#options + 1] = tostring(value) .. "x/player"
	end
	return options
end

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
				return view_model.normalize_group_max_players(MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.max_players)
			end,
			normalize = function(value)
				return view_model.normalize_group_max_players(value)
			end,
			on_change = change_party_max_players,
			ui_args = party_options_cycle_ui,
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
	},
}

view_model.LOBBY_OPTION_TAB_SPECS = {
	gameplay = {
		{ kind = "toggle", control_id = "gold_on_life_loss_toggle", label_key = "b_opts_cb_money", option_key = "gold_on_life_loss" },
		{ kind = "toggle", control_id = "no_gold_on_round_loss_toggle", label_key = "b_opts_no_gold_on_loss", option_key = "no_gold_on_round_loss" },
		{ kind = "toggle", control_id = "death_on_round_loss_toggle", label_key = "b_opts_death_on_loss", option_key = "death_on_round_loss" },
		{ kind = "toggle", control_id = "timer_toggle", label_key = "b_opts_timer", option_key = "timer" },
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
			kind = "cycle",
			spec_id = "coop_blind_scaling_per_player",
			control_id = "coop_blind_scaling_per_player_option",
			label_key = "k_opts_coop_blind_scaling",
			option_key = "coop_blind_scaling_per_player",
			scale = 0.85,
			option_values = coop_blind_scaling_values,
			display_options = build_coop_blind_scaling_display_options(),
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
		{
			kind = "cycle",
			spec_id = "pvp_countdown_seconds",
			control_id = "pvp_countdown_seconds_option",
			label_key = "k_opts_pvp_countdown_seconds",
			option_key = "pvp_countdown_seconds",
			scale = 0.85,
			option_values = pvp_countdown_values,
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
