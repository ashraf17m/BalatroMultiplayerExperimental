MP.DOMAIN = MP.DOMAIN or {}
MP.DOMAIN.MATCH = MP.DOMAIN.MATCH or {}

local MATCH_DOMAIN = MP.DOMAIN.MATCH
MATCH_DOMAIN.INTERNAL = MATCH_DOMAIN.INTERNAL or {}

local INTERNAL = MATCH_DOMAIN.INTERNAL

local function extend_state(target, fields)
	for key, value in pairs(fields) do
		target[key] = value
	end

	return target
end

function INTERNAL.copy_table_shallow(source)
	local result = {}
	for key, value in pairs(source or {}) do
		result[key] = value
	end
	return result
end

function INTERNAL.copy_sequence(source)
	local result = {}
	for index, value in ipairs(source or {}) do
		result[index] = value
	end
	return result
end

function INTERNAL.restore_insane_int(value)
	if MP.INSANE_INT and MP.INSANE_INT.from_string then
		return MP.INSANE_INT.from_string(tostring(value or "0"))
	end

	return value
end

function INTERNAL.normalize_ready_location(location)
	location = tostring(location or "loc_selecting")
	if location == "loc_ready" or location == "loc_ready_teams" then
		return "loc_selecting"
	end

	if string.find(location, "loc_ready_for_team_row%-", 1) == 1 then
		return "loc_selecting"
	end

	if string.find(location, "loc_ready_to_skip_for_team_row%-", 1) == 1 then
		return "loc_selecting"
	end

	return location
end

function INTERNAL.ensure_enemy_collection(state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.enemies = state.enemies or {}
	return state.enemies
end

local function get_default_starting_lives()
	return MP.LOBBY.config.starting_lives or MP.DEFAULT_STARTING_LIVES
end

local function build_initial_round_state(starting_lives)
	return {
		ready_blind = false,
		ready_blind_kind = nil,
		ready_blind_text = localize("b_ready"),
		processed_round_done = false,
		lives = starting_lives,
		hands = MP.DEFAULT_HANDS_PER_ROUND or 0,
		score_text = "0",
		score_display = MP.INSANE_INT.empty(),
		loaded_ante = 0,
		loading_blinds = false,
		force_zero_round_score = true,
		comeback_bonus_given = true,
		comeback_bonus = 0,
		end_pvp = false,
		enemies = {},
		location = "loc_selecting",
		next_blind_context = nil,
		duel_blind_role = nil,
		duel_bye_waiting = false,
		skip_ready_blind_row = nil,
		pvp_reached = false,
		pvp_reached_first = false,
		ante_key = tostring(math.random()),
		antes_keyed = {},
		prevent_eval = false,
		round_failed = false,
		round_ended = false,
		duplicate_end = false,
		coop_deck_out_waiting = false,
		coop_deck_out_resolved = false,
		highest_score = MP.INSANE_INT.empty(),
		furthest_blind = 0,
	}
end

local function build_initial_team_state(starting_lives)
	return {
		live_team_local_score_cache = nil,
		shared_score_text = "0",
		team_lives = starting_lives,
		team_score = MP.INSANE_INT.empty(),
		team_score_text = "0",
	}
end

local function build_initial_economy_state()
	return {
		misprint_display = "",
		spent_total = 0,
		spent_before_shop = 0,
		real_money = 0,
		applying_remote_money = false,
	}
end

local function build_initial_timer_state()
	return {
		timer = MP.UTILS and MP.UTILS.timer_base and MP.UTILS.timer_base() or MP.LOBBY.config.timer_base_seconds,
		timer_started = false,
		nemesis_timer_started = false,
		timer_consumed = false,
		timers_forgiven = 0,
		timer_locked_for_ante = false,
		timer_skip_count_for_ante = 0,
		timer_runtime_active = false,
		timer_runtime_generation = 0,
		wait_for_enemys_furthest_blind = false,
		disable_live_and_timer_hud = false,
	}
end

local function build_initial_meta_state()
	return {
		pincher_index = -3,
		pincher_unlock = false,
		asteroids = 0,
		pizza_discards = 0,
		stats = {
			reroll_count = 0,
			reroll_cost_total = 0,
			total_money_spent = 0,
			vouchers_bought = {},
		},
		ffa_display = {
			text = "Loading...",
			lives_text = "0",
		},
	}
end

local function build_initial_enemy_tracking_state()
	return {
		enemy = MATCH_DOMAIN.create_enemy_state("???"),
		empty_enemy = MATCH_DOMAIN.create_enemy_state("???"),
	}
end

local function build_initial_end_game_state()
	return {
		won = false,
		end_game_result = nil,
	}
end

function MATCH_DOMAIN.build_initial_state()
	local starting_lives = get_default_starting_lives()
	local state = {}

	extend_state(state, build_initial_round_state(starting_lives))
	extend_state(state, build_initial_team_state(starting_lives))
	extend_state(state, build_initial_economy_state())
	extend_state(state, build_initial_timer_state())
	extend_state(state, build_initial_meta_state())
	extend_state(state, build_initial_enemy_tracking_state())
	extend_state(state, build_initial_end_game_state())

	return state
end

function MATCH_DOMAIN.ensure_state()
	if not MP.GAME then
		MP.GAME = MATCH_DOMAIN.build_initial_state()
	end

	return MP.GAME
end

function MATCH_DOMAIN.reset_state()
	sendDebugMessage("Resetting game states", "MULTIPLAYER")
	MP.GAME = MATCH_DOMAIN.build_initial_state()
	return MP.GAME
end

function MATCH_DOMAIN.initialize_runtime_state()
	return MATCH_DOMAIN.reset_state()
end

return MATCH_DOMAIN
