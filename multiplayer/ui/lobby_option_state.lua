MP.UI = MP.UI or {}
MP.UI.LOBBY_OPTION_CYCLE_SPECS = MP.UI.LOBBY_OPTION_CYCLE_SPECS or {}

local view_model = MP.UI

local function build_number_range(min_value, max_value)
	local values = {}
	for value = min_value, max_value do
		values[#values + 1] = value
	end
	return values
end

local function get_group_max_player_floor()
	local player_count = MP.get_lobby_player_count and MP.get_lobby_player_count() or 0
	return math.max(MP.MIN_GROUP_LOBBY_PLAYERS, player_count)
end

local function build_group_max_player_options()
	local options = {}
	for i = get_group_max_player_floor(), MP.MAX_GROUP_LOBBY_PLAYERS do
		options[#options + 1] = i
	end
	return options
end

local function get_group_scoring_options()
	return {
		localize("k_highest_score"),
		localize("k_beat_average"),
	}
end

local function normalize_group_max_players(value)
	local parsed = tonumber(value)
	if not parsed then
		parsed = MP.DEFAULT_GROUP_LOBBY_PLAYERS
	end

	parsed = math.floor(parsed)
	return math.max(get_group_max_player_floor(), math.min(MP.MAX_GROUP_LOBBY_PLAYERS, parsed))
end

function view_model.get_group_scoring_options()
	return get_group_scoring_options()
end

function view_model.get_group_max_player_options()
	return build_group_max_player_options()
end

function view_model.normalize_group_max_players(value)
	return normalize_group_max_players(value)
end

function view_model.get_group_max_players_index(current_max_players)
	local options = view_model.get_group_max_player_options()
	return MP.UTILS.get_array_index_by_value(options, view_model.normalize_group_max_players(current_max_players))
		or MP.UTILS.get_array_index_by_value(options, view_model.normalize_group_max_players(MP.DEFAULT_GROUP_LOBBY_PLAYERS))
		or 1
end

local starting_lives_values = build_number_range(1, 16)
local coop_blind_scaling_values = build_number_range(1, 8)
local round_values = build_number_range(1, 20)
local timer_base_values = { 30, 60, 90, 120, 150, 180, 210, 240 }
local timer_increment_values = { 0, 30, 60, 90, 120, 150, 180 }
local pvp_countdown_values = { 0, 3, 5, 10 }

local function is_coop_gamemode_selected()
	return MP.is_coop_gamemode and MP.is_coop_gamemode()
end

local function build_coop_blind_scaling_display_options()
	local options = {}
	for _, value in ipairs(coop_blind_scaling_values) do
		options[#options + 1] = "+" .. tostring(value) .. "x/player"
	end
	return options
end

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
				return MP.LOBBY.config.ruleset == "ruleset_mp_smallworld"
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
			display_options = { "30s", "60s", "90s", "120s", "150s", "180s", "210s", "240s" },
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
}
