MP.DOMAIN = MP.DOMAIN or {}
MP.DOMAIN.MATCH = MP.DOMAIN.MATCH or {}

local MATCH_DOMAIN = MP.DOMAIN.MATCH
MATCH_DOMAIN.INTERNAL = MATCH_DOMAIN.INTERNAL or {}

local INTERNAL = MATCH_DOMAIN.INTERNAL

-- ============================================================================
-- 1. Match State Lifecycle & Initialization (from match_state_service.lua)
-- ============================================================================
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
		comeback_eval_pending = false,
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

-- ============================================================================
-- 2. Enemy State Tracking & Snapshot Sync (from match_enemy_service.lua)
-- ============================================================================
local ENEMY_IN_MATCH = true
local ENEMY_CONNECTED = false

local function apply_enemy_presence(enemy, team, is_in_match, is_disconnected, raw_location, location)
	enemy.team = team
	if is_in_match ~= nil then
		enemy.in_match = not not is_in_match
	end
	if is_disconnected ~= nil then
		enemy.is_disconnected = not not is_disconnected
	end
	enemy.raw_location = raw_location or enemy.raw_location
	enemy.location = location or enemy.location
	return enemy
end

local function apply_enemy_lobby_lives(enemy, player_state)
	local lives = tonumber(player_state and player_state.lives)
	if lives ~= nil then
		enemy.lives = lives
		enemy.team_lives = lives
	end
end

local function restore_saved_enemy_state(saved_enemy)
	local enemy = MATCH_DOMAIN.create_enemy_state(saved_enemy.username, saved_enemy.lives)
	enemy.score = INTERNAL.restore_insane_int(saved_enemy.score)
	enemy.synced_score = INTERNAL.restore_insane_int(saved_enemy.synced_score or saved_enemy.score)
	enemy.score_text = tostring(saved_enemy.score_text or "0")
	enemy.hands = tonumber(saved_enemy.hands) or enemy.hands
	enemy.location = saved_enemy.location or enemy.location
	enemy.raw_location = saved_enemy.raw_location or enemy.raw_location
	enemy.is_disconnected = not not saved_enemy.is_disconnected
	enemy.skips = tonumber(saved_enemy.skips) or enemy.skips
	enemy.lives = tonumber(saved_enemy.lives) or enemy.lives
	enemy.team_lives = tonumber(saved_enemy.team_lives) or enemy.team_lives
	enemy.sells = tonumber(saved_enemy.sells) or enemy.sells
	enemy.sells_per_ante = INTERNAL.copy_table_shallow(saved_enemy.sells_per_ante)
	enemy.spent_in_shop = INTERNAL.copy_sequence(saved_enemy.spent_in_shop)
	enemy.highest_score = INTERNAL.restore_insane_int(saved_enemy.highest_score or saved_enemy.score)
	enemy.team = saved_enemy.team
	enemy.in_match = saved_enemy.in_match ~= false
	return enemy
end

INTERNAL.restore_saved_enemy_state = restore_saved_enemy_state

function MATCH_DOMAIN.create_enemy_state(username, lives)
	return {
		username = username or "Guest",
		score = MP.INSANE_INT.empty(),
		synced_score = MP.INSANE_INT.empty(),
		score_text = "0",
		hands = MP.DEFAULT_HANDS_PER_ROUND,
		location = localize("loc_selecting"),
		raw_location = "loc_selecting",
		is_disconnected = false,
		skips = 0,
		lives = lives or MP.LOBBY.config.starting_lives or MP.DEFAULT_STARTING_LIVES,
		team_lives = lives or MP.LOBBY.config.starting_lives or MP.DEFAULT_STARTING_LIVES,
		sells = 0,
		sells_per_ante = {},
		spent_in_shop = {},
		highest_score = MP.INSANE_INT.empty(),
	}
end

function MATCH_DOMAIN.get_or_create_enemy_state(player_id, username, state)
	local enemies = INTERNAL.ensure_enemy_collection(state)
	local enemy = enemies[player_id]

	if not enemy then
		enemy = MATCH_DOMAIN.create_enemy_state(username)
		enemies[player_id] = enemy
	elseif username and username ~= "" then
		enemy.username = username
	end

	return enemy
end

function MATCH_DOMAIN.prune_stale_enemies(tracked_enemy_ids, self_player_id, state)
	local enemies = INTERNAL.ensure_enemy_collection(state)
	local stale_enemy_ids = {}

	for enemy_id, _ in pairs(enemies) do
		if enemy_id ~= self_player_id and not tracked_enemy_ids[enemy_id] then
			stale_enemy_ids[#stale_enemy_ids + 1] = enemy_id
		end
	end

	for _, enemy_id in ipairs(stale_enemy_ids) do
		enemies[enemy_id] = nil
	end

	return enemies
end

local function player_is_spectator(player)
	return not not (player and (player.is_spectator or player.role == "spectator"))
end

function MATCH_DOMAIN.sync_resume_enemies_from_lobby_players(players, self_player_id, state)
	local tracked_enemy_ids = {}

	for _, player in ipairs(players or {}) do
		if player.id ~= self_player_id and not player_is_spectator(player) then
			local enemy = MATCH_DOMAIN.get_or_create_enemy_state(player.id, player.username, state)
			apply_enemy_presence(
				enemy,
				player.team,
				player.is_in_match ~= false,
				player.is_disconnected,
				player.raw_location,
				player.location
			)
			apply_enemy_lobby_lives(enemy, player)
			tracked_enemy_ids[player.id] = true
		end
	end

	MATCH_DOMAIN.prune_stale_enemies(tracked_enemy_ids, self_player_id, state)
	return tracked_enemy_ids
end

function MATCH_DOMAIN.seed_enemies_from_lobby_players(players, self_player_id, state)
	for _, player in ipairs(players or {}) do
		if player.id ~= self_player_id and not player_is_spectator(player) then
			local enemy = MATCH_DOMAIN.get_or_create_enemy_state(player.id, player.username, state)
			apply_enemy_presence(enemy, player.team, true)
			apply_enemy_lobby_lives(enemy, player)
		end
	end

	return INTERNAL.ensure_enemy_collection(state)
end

function MATCH_DOMAIN.sync_enemy_from_lobby_snapshot_player(player_state, is_in_game, local_player_in_match, tracked_enemy_ids, state)
	if not player_state or player_state.is_self or player_is_spectator(player_state) then
		return nil
	end

	local should_track_enemy = (not is_in_game) or (local_player_in_match and player_state.is_in_match)
	if should_track_enemy then
		local enemy = MATCH_DOMAIN.get_or_create_enemy_state(player_state.id, player_state.username, state)
		apply_enemy_presence(
			enemy,
			player_state.team,
			player_state.is_in_match,
			player_state.is_disconnected,
			player_state.raw_location,
			player_state.location
		)
		apply_enemy_lobby_lives(enemy, player_state)
		if tracked_enemy_ids then
			tracked_enemy_ids[player_state.id] = true
		end
		return enemy
	end

	local enemies = INTERNAL.ensure_enemy_collection(state)
	enemies[player_state.id] = nil
	return nil
end

function MATCH_DOMAIN.get_local_player_in_match_from_snapshot(players, self_player_id)
	for _, player_state in ipairs(players or {}) do
		if player_state and (player_state.is_self or player_state.id == self_player_id) then
			return not not player_state.is_in_match
		end
	end

	return false
end

function MATCH_DOMAIN.sync_enemies_from_lobby_snapshot(players, is_in_game, local_player_in_match, self_player_id, state)
	if local_player_in_match == nil then
		local_player_in_match = MATCH_DOMAIN.get_local_player_in_match_from_snapshot(players, self_player_id)
	end

	local tracked_enemy_ids = {}

	for _, player_state in ipairs(players or {}) do
		MATCH_DOMAIN.sync_enemy_from_lobby_snapshot_player(
			player_state,
			is_in_game,
			local_player_in_match,
			tracked_enemy_ids,
			state
		)
	end

	MATCH_DOMAIN.prune_stale_enemies(tracked_enemy_ids, self_player_id, state)
	return tracked_enemy_ids
end

function MATCH_DOMAIN.apply_enemy_team_assignment(player_id, team_id, is_in_match, state)
	local enemies = INTERNAL.ensure_enemy_collection(state)
	local enemy = enemies[player_id]

	if not enemy then
		return nil
	end

	return apply_enemy_presence(enemy, team_id, is_in_match)
end

local function get_enemy_info_field(enemy_info, camel_key, snake_key)
	if type(enemy_info) ~= "table" then
		return nil
	end
	if enemy_info[camel_key] ~= nil then
		return enemy_info[camel_key]
	end
	return enemy_info[snake_key]
end

function MATCH_DOMAIN.apply_enemy_info(enemy_info, self_player_id, state)
	state = state or MATCH_DOMAIN.ensure_state()

	local player_id = get_enemy_info_field(enemy_info, "playerId", "player_id")
	local username = get_enemy_info_field(enemy_info, "username", "username")
	local score_value = get_enemy_info_field(enemy_info, "score", "score_str")
	local hands_left_value = get_enemy_info_field(enemy_info, "handsLeft", "hands_left_str")
	local skips_value = get_enemy_info_field(enemy_info, "skips", "skips_str")
	local lives_value = get_enemy_info_field(enemy_info, "lives", "lives_str")
	local team = get_enemy_info_field(enemy_info, "team", "team")
	local team_lives_value = get_enemy_info_field(enemy_info, "teamLives", "team_lives")
	local life_loss_reason = get_enemy_info_field(enemy_info, "lifeLossReason", "life_loss_reason")
	local server_previous_lives = get_enemy_info_field(enemy_info, "previousLives", "previous_lives")

	if player_id == nil then
		return {
			invalid = true,
			missing_player = true,
		}
	end

	if player_id == self_player_id then
		local enemies = INTERNAL.ensure_enemy_collection(state)
		enemies[player_id] = nil
		return {
			removed_self = true,
		}
	end

	local enemy = MATCH_DOMAIN.get_or_create_enemy_state(player_id, username, state)
	local score = (type(score_value) == "string" or type(score_value) == "number") and MP.INSANE_INT.from_string(score_value) or nil
	local hands_left = tonumber(hands_left_value)
	local skips = tonumber(skips_value)
	local lives = tonumber(lives_value)
	local shared_team_lives = tonumber(team_lives_value)

	if score == nil or hands_left == nil then
		return {
			enemy = enemy,
			invalid = true,
			score = score,
			hands_left = hands_left,
			skips = skips,
			lives = lives,
			shared_team_lives = shared_team_lives,
		}
	end

	local skip_delta = 0
	if skips ~= nil and enemy.skips ~= skips then
		skip_delta = skips - enemy.skips
		if skip_delta > 0 then
			for _ = 1, skip_delta do
				enemy.spent_in_shop[#enemy.spent_in_shop + 1] = 0
			end
		end
	end

	local previous_lives = enemy.lives
	local highest_score_updated = false
	if (MP.is_pvp_boss and MP.is_pvp_boss()) and MP.INSANE_INT.greater_than(score, enemy.highest_score) then
		enemy.highest_score = score
		highest_score_updated = true
	end

	enemy.hands = hands_left
	enemy.skips = skips
	enemy.lives = lives
	enemy.synced_score = score
	enemy.score_text = score_value
	enemy.team_lives = shared_team_lives or lives or enemy.team_lives
	apply_enemy_presence(enemy, team, ENEMY_IN_MATCH, ENEMY_CONNECTED)

	local local_team_lives_updated = false
	if MP.is_teams_mode() and team ~= nil and team == MP.get_self_team_id() then
		state.team_lives = shared_team_lives or lives or state.team_lives
		local_team_lives_updated = true
	end

	return {
		enemy = enemy,
		score = score,
		hands_left = hands_left,
		skips = skips,
		lives = lives,
		shared_team_lives = shared_team_lives,
		skip_delta = skip_delta,
		previous_lives = previous_lives,
		server_previous_lives = tonumber(server_previous_lives),
		life_lost = previous_lives > lives,
		life_loss_reason = life_loss_reason,
		highest_score_updated = highest_score_updated,
		local_team_lives_updated = local_team_lives_updated,
	}
end

function MATCH_DOMAIN.apply_enemy_location(player_id, username, raw_location, resolved_location, state)
	state = state or MATCH_DOMAIN.ensure_state()

	local enemy = MATCH_DOMAIN.get_or_create_enemy_state(player_id, username, state)
	apply_enemy_presence(enemy, enemy.team, ENEMY_IN_MATCH, ENEMY_CONNECTED, raw_location, resolved_location)

	return enemy
end

-- ============================================================================
-- 3. Match Mutations, Timers & Progressions (from match_mutation_service.lua)
-- ============================================================================
local function normalize_integer(value)
	local numeric_value = tonumber(value) or tonumber(tostring(value)) or 0
	if numeric_value ~= numeric_value or numeric_value == math.huge or numeric_value == -math.huge then
		numeric_value = 0
	end
	return math.modf(numeric_value)
end

local function is_furthest_blind_progress_ahead(candidate_progress, current_progress)
	candidate_progress = normalize_integer(candidate_progress)
	current_progress = normalize_integer(current_progress)
	return candidate_progress > current_progress or (current_progress == 0 and candidate_progress < 0)
end

local function normalize_nonnegative_integer(value)
	return math.max(0, math.floor(tonumber(value) or 0))
end

local function set_runtime_activity(state, active_field, generation_field, is_active)
	state[active_field] = not not is_active
	state[generation_field] = normalize_nonnegative_integer(state[generation_field]) + 1
	return state[generation_field]
end

local function increment_nonnegative_counter(state, field_name, amount)
	state[field_name] = normalize_nonnegative_integer(state[field_name])
		+ normalize_nonnegative_integer(amount)
	return state[field_name]
end

local function consume_nonnegative_counter(state, field_name)
	local value = normalize_nonnegative_integer(state[field_name])
	state[field_name] = 0
	return value
end

function MATCH_DOMAIN.apply_local_player_info(lives, life_loss_reason, server_previous_lives, team, state)
	state = state or MATCH_DOMAIN.ensure_state()
	lives = tonumber(lives) or state.lives

	local previous_lives = state.lives
	local changed = previous_lives ~= lives
	local granted_comeback_bonus = false

	if changed and previous_lives ~= 0 and MP.LOBBY.config.gold_on_life_loss then
		state.comeback_bonus_given = false
		state.comeback_eval_pending = true
		state.comeback_bonus = state.comeback_bonus + 1
		granted_comeback_bonus = true
	end

	state.lives = lives
	state.team_lives = lives

	return {
		previous_lives = previous_lives,
		lives = lives,
		changed = changed,
		life_lost = changed and previous_lives > lives,
		life_loss_reason = life_loss_reason,
		server_previous_lives = tonumber(server_previous_lives),
		team = tonumber(team),
		granted_comeback_bonus = granted_comeback_bonus,
	}
end

function MATCH_DOMAIN.apply_remote_money_update(money, state)
	state = state or MATCH_DOMAIN.ensure_state()
	money = tonumber(money)

	if not money then
		return {
			invalid = true,
		}
	end

	state.real_money = tostring(money)

	return {
		invalid = false,
		money = money,
		money_text = state.real_money,
	}
end

function MATCH_DOMAIN.set_timer_value(time, state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.timer = normalize_nonnegative_integer(time)
	return state.timer
end

function MATCH_DOMAIN.stop_timer_runtime(state)
	state = state or MATCH_DOMAIN.ensure_state()
	return set_runtime_activity(
		state,
		"timer_runtime_active",
		"timer_runtime_generation",
		false
	)
end

function MATCH_DOMAIN.start_timer_runtime(state)
	state = state or MATCH_DOMAIN.ensure_state()
	return set_runtime_activity(
		state,
		"timer_runtime_active",
		"timer_runtime_generation",
		true
	)
end

function MATCH_DOMAIN.apply_timer_state(time, timer_started, state)
	state = state or MATCH_DOMAIN.ensure_state()
	MATCH_DOMAIN.set_timer_value(time, state)
	state.timer_started = not not timer_started
	state.timer_locked_for_ante = not not (state.timer_locked_for_ante or timer_started)
	return {
		timer = state.timer,
		timer_started = state.timer_started,
		timer_locked_for_ante = state.timer_locked_for_ante,
	}
end

function MATCH_DOMAIN.reset_timer_for_ante(time, state)
	state = state or MATCH_DOMAIN.ensure_state()
	MATCH_DOMAIN.set_timer_value(time, state)
	state.timer_started = false
	state.timer_locked_for_ante = false
	state.timer_skip_count_for_ante = 0
	MATCH_DOMAIN.stop_timer_runtime(state)
	return state
end

function MATCH_DOMAIN.apply_timer_skip_for_ante(skip_count_delta, base_time, increment_seconds, state)
	state = state or MATCH_DOMAIN.ensure_state()
	if state.timer_locked_for_ante then
		return {
			applied = false,
			locked = true,
		}
	end

	skip_count_delta = normalize_nonnegative_integer(skip_count_delta)
	if skip_count_delta <= 0 then
		return {
			applied = false,
			locked = false,
		}
	end

	local next_skip_count = increment_nonnegative_counter(
		state,
		"timer_skip_count_for_ante",
		skip_count_delta
	)
	MATCH_DOMAIN.set_timer_value((tonumber(base_time) or 0) + ((tonumber(increment_seconds) or 0) * next_skip_count), state)

	return {
		applied = true,
		timer = state.timer,
		skip_count = next_skip_count,
	}
end

function MATCH_DOMAIN.set_spent_before_shop(spent_before_shop, state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.spent_before_shop = spent_before_shop
	return state.spent_before_shop
end

function MATCH_DOMAIN.set_applying_remote_money(is_applying, state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.applying_remote_money = not not is_applying
	return state.applying_remote_money
end

function MATCH_DOMAIN.set_shared_score_text(shared_score_text, state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.shared_score_text = tostring(shared_score_text or state.shared_score_text or "0")
	return state.shared_score_text
end

function MATCH_DOMAIN.set_pincher_unlocked(state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.pincher_unlock = true
	return true
end

function MATCH_DOMAIN.increment_asteroids(amount, state)
	state = state or MATCH_DOMAIN.ensure_state()
	return increment_nonnegative_counter(state, "asteroids", amount)
end

function MATCH_DOMAIN.consume_asteroids(state)
	state = state or MATCH_DOMAIN.ensure_state()
	return consume_nonnegative_counter(state, "asteroids")
end

function MATCH_DOMAIN.increment_pizza_discards(amount, state)
	state = state or MATCH_DOMAIN.ensure_state()
	return increment_nonnegative_counter(state, "pizza_discards", amount)
end

function MATCH_DOMAIN.consume_pizza_discards(state)
	state = state or MATCH_DOMAIN.ensure_state()
	return consume_nonnegative_counter(state, "pizza_discards")
end

function MATCH_DOMAIN.reset_ready_blind_state(state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.ready_blind = false
	state.ready_blind_kind = nil
	state.ready_blind_text = localize("b_ready")
	state.skip_ready_blind_row = nil
	state.location = INTERNAL.normalize_ready_location(state.location)
	return state
end

function MATCH_DOMAIN.set_duel_blind_role(duel_role, state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.duel_blind_role = (duel_role == "pair" or duel_role == "bye") and duel_role or nil
	return state.duel_blind_role
end

function MATCH_DOMAIN.mark_duel_bye_waiting(state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.duel_bye_waiting = true
	return true
end

function MATCH_DOMAIN.clear_duel_bye_waiting(state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.duel_bye_waiting = false
	return false
end

function MATCH_DOMAIN.set_ready_blind_state(is_ready, blind_kind, state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.ready_blind = not not is_ready
	state.ready_blind_kind = state.ready_blind and blind_kind or nil
	state.ready_blind_text = state.ready_blind and localize("b_unready") or localize("b_ready")
	if blind_kind == "pvp" then
		state.pvp_reached = state.ready_blind
		if not state.ready_blind then
			state.pvp_reached_first = false
		end
	end
	return state.ready_blind
end

function MATCH_DOMAIN.queue_next_blind_context(context, state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.next_blind_context = context
	return state
end

function MATCH_DOMAIN.clear_next_blind_context(state)
	state = state or MATCH_DOMAIN.ensure_state()
	return state
end

function MATCH_DOMAIN.set_location(location, state)
	state = state or MATCH_DOMAIN.ensure_state()
	if state.location == location then
		return false
	end

	state.location = location
	return true
end

function MATCH_DOMAIN.apply_local_hand_score(score_text, score, hands_left, state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.score_display = state.score_display or INTERNAL.restore_insane_int(state.score_text)
	state.force_zero_round_score = false
	state.score_text = score_text
	if hands_left ~= nil then
		state.hands = normalize_nonnegative_integer(hands_left)
	end

	local highest_score_updated = false
	if
		(MP.is_pvp_boss and MP.is_pvp_boss())
		and MP.INSANE_INT.greater_than(score, state.highest_score)
	then
		state.highest_score = score
		highest_score_updated = true
	end

	return {
		highest_score_updated = highest_score_updated,
		score_text = state.score_text,
		hands = state.hands,
	}
end

function MATCH_DOMAIN.begin_new_round(state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.duplicate_end = false
	state.round_failed = false
	state.round_ended = false
	state.comeback_eval_pending = false
	state.coop_deck_out_waiting = false
	state.coop_deck_out_resolved = false
	return state
end

function MATCH_DOMAIN.set_skip_ready_blind_row(row, state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.skip_ready_blind_row = row
	return row
end

function MATCH_DOMAIN.prepare_blind_selection(state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.end_pvp = false
	state.duel_blind_role = nil
	state.duel_bye_waiting = false
	state.prevent_eval = false
	state.round_failed = false
	state.comeback_eval_pending = false
	state.coop_deck_out_waiting = false
	state.coop_deck_out_resolved = false
	state.wait_for_enemys_furthest_blind = false
	state.highest_score = MP.INSANE_INT.empty()
	state.score_display = MP.INSANE_INT.empty()
	state.ante_key = tostring(math.random())
	return state
end

function MATCH_DOMAIN.advance_furthest_blind(temp_furthest_blind, state)
	state = state or MATCH_DOMAIN.ensure_state()
	local next_furthest_blind = normalize_integer(temp_furthest_blind)
	state.pincher_index = state.pincher_index + 1
	if is_furthest_blind_progress_ahead(next_furthest_blind, state.furthest_blind) then
		state.furthest_blind = next_furthest_blind
	end
	return state.furthest_blind
end

function MATCH_DOMAIN.clear_end_pvp(state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.end_pvp = false
	return false
end

function MATCH_DOMAIN.clear_end_coop_blind(state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.end_coop_blind = false
	state.end_coop_lost = false
	state.end_pvp = false
	return false
end

function MATCH_DOMAIN.set_wait_for_enemy_furthest_blind(should_wait, state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.wait_for_enemys_furthest_blind = not not should_wait
	return state.wait_for_enemys_furthest_blind
end

function MATCH_DOMAIN.mark_ante_key_processed(state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.antes_keyed = state.antes_keyed or {}
	state.antes_keyed[state.ante_key] = true
	return state.ante_key
end

function MATCH_DOMAIN.mark_duplicate_end(state)
	state = state or MATCH_DOMAIN.ensure_state()
	if state.duplicate_end then
		return false
	end

	state.duplicate_end = true
	return true
end

local function mark_server_resolved_blind(state, options)
	options = options or {}
	state = state or MATCH_DOMAIN.ensure_state()
	state.end_pvp = true
	if not options.preserve_timer_state then
		state.timer_consumed = false
		state.timer_started = false
		state.nemesis_timer_started = false
	end
	state.pvp_reached = false
	state.pvp_reached_first = false
	state.duel_blind_role = nil
	return MATCH_DOMAIN.reset_ready_blind_state(state)
end

function MATCH_DOMAIN.mark_end_pvp(state)
	return mark_server_resolved_blind(state)
end

function MATCH_DOMAIN.mark_end_coop_blind(state, lost)
	if type(state) ~= "table" then
		lost = state
		state = MATCH_DOMAIN.ensure_state()
	else
		state = state or MATCH_DOMAIN.ensure_state()
	end
	mark_server_resolved_blind(state, { preserve_timer_state = true })
	state.end_coop_blind = true
	state.end_coop_lost = not not lost
	return true
end

function MATCH_DOMAIN.mark_match_won(state)
	state = state or MATCH_DOMAIN.ensure_state()
	if state.won then
		return false
	end

	state.won = true
	state.end_game_result = "win"
	return true
end

function MATCH_DOMAIN.mark_match_abandoned(state)
	state = state or MATCH_DOMAIN.ensure_state()
	if not state.won and state.end_game_result == "abandoned" then
		return false
	end

	state.won = false
	state.end_game_result = "abandoned"
	return true
end

function MATCH_DOMAIN.mark_match_lost(state)
	state = state or MATCH_DOMAIN.ensure_state()
	if not state.won and state.end_game_result == "loss" then
		return false
	end

	state.won = false
	state.end_game_result = "loss"
	return true
end

function MATCH_DOMAIN.mark_match_alone(state)
	return MATCH_DOMAIN.mark_match_abandoned(state)
end

-- ============================================================================
-- 4. Match State Save & Restore (from match_restore_service.lua)
-- ============================================================================
function MATCH_DOMAIN.apply_saved_state(saved_state, state)
	if type(saved_state) ~= "table" then
		return nil
	end

	state = state or MATCH_DOMAIN.ensure_state()
	MATCH_DOMAIN.reset_ready_blind_state(state)

	state.processed_round_done = not not saved_state.processed_round_done
	state.lives = tonumber(saved_state.lives) or state.lives
	state.score_text = tostring(saved_state.score_text or state.score_text or "0")
	state.score_display = INTERNAL.restore_insane_int(saved_state.score_display or state.score_text)
	state.loaded_ante = tonumber(saved_state.loaded_ante) or state.loaded_ante
	state.loading_blinds = not not saved_state.loading_blinds
	state.force_zero_round_score = not not saved_state.force_zero_round_score
	state.comeback_bonus_given = not not saved_state.comeback_bonus_given
	state.comeback_bonus = tonumber(saved_state.comeback_bonus) or state.comeback_bonus
	state.comeback_eval_pending = not not saved_state.comeback_eval_pending
	state.end_pvp = not not saved_state.end_pvp
	state.location = INTERNAL.normalize_ready_location(saved_state.location or state.location)
	state.duel_bye_waiting = not not saved_state.duel_bye_waiting
	state.ante_key = tostring(saved_state.ante_key or state.ante_key)
	state.antes_keyed = INTERNAL.copy_table_shallow(saved_state.antes_keyed)
	state.prevent_eval = not not saved_state.prevent_eval
	state.round_failed = not not saved_state.round_failed
	state.round_ended = not not saved_state.round_ended
	state.duplicate_end = not not saved_state.duplicate_end
	state.highest_score = INTERNAL.restore_insane_int(saved_state.highest_score)
	state.furthest_blind = tonumber(saved_state.furthest_blind) or state.furthest_blind
	state.team_lives = tonumber(saved_state.team_lives) or state.team_lives
	state.team_score = INTERNAL.restore_insane_int(saved_state.team_score)
	state.team_score_text = tostring(saved_state.team_score_text or state.team_score_text or "0")
	state.shared_score_text = tostring(saved_state.team_score_text or state.shared_score_text or "0")
	state.misprint_display = tostring(saved_state.misprint_display or state.misprint_display or "")
	state.spent_total = tostring(saved_state.spent_total or state.spent_total or 0)
	state.spent_before_shop = tostring(saved_state.spent_before_shop or state.spent_before_shop or 0)
	state.real_money = tostring(saved_state.real_money or state.real_money or 0)
	state.timer = tonumber(saved_state.timer) or state.timer
	state.timer_started = not not saved_state.timer_started
	state.timer_locked_for_ante = not not (
		saved_state.timer_locked_for_ante or saved_state.timer_started
	)
	state.timer_skip_count_for_ante = tonumber(saved_state.timer_skip_count_for_ante) or 0
	state.timer_runtime_active = false
	state.timer_runtime_generation = tonumber(saved_state.timer_runtime_generation) or 0
	state.wait_for_enemys_furthest_blind = not not saved_state.wait_for_enemys_furthest_blind
	state.disable_live_and_timer_hud = not not saved_state.disable_live_and_timer_hud
	state.pincher_index = tonumber(saved_state.pincher_index) or state.pincher_index
	state.pincher_unlock = not not saved_state.pincher_unlock
	state.asteroids = tonumber(saved_state.asteroids) or state.asteroids
	state.pizza_discards = tonumber(saved_state.pizza_discards) or state.pizza_discards
	state.stats = INTERNAL.copy_table_shallow(saved_state.stats)

	state.enemies = {}
	for player_id, enemy_data in pairs(saved_state.enemies or {}) do
		state.enemies[player_id] = INTERNAL.restore_saved_enemy_state(enemy_data)
	end

	return state
end

return MATCH_DOMAIN
