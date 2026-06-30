MP.DOMAIN = MP.DOMAIN or {}
MP.DOMAIN.MATCH = MP.DOMAIN.MATCH or {}

local MATCH_DOMAIN = MP.DOMAIN.MATCH
MATCH_DOMAIN.INTERNAL = MATCH_DOMAIN.INTERNAL or {}

local INTERNAL = MATCH_DOMAIN.INTERNAL

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

function MATCH_DOMAIN.begin_pvp_countdown(seconds, state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.pvp_countdown = normalize_nonnegative_integer(seconds)
	return state.pvp_countdown
end

function MATCH_DOMAIN.tick_pvp_countdown(state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.pvp_countdown = math.max(0, normalize_nonnegative_integer(state.pvp_countdown) - 1)
	return state.pvp_countdown
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
	state.start_blind_skip_pvp_countdown = false
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

function MATCH_DOMAIN.queue_next_blind_context(context, should_skip_pvp_countdown, state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.next_blind_context = context
	state.start_blind_skip_pvp_countdown = not not should_skip_pvp_countdown
	return state
end

function MATCH_DOMAIN.clear_next_blind_context(state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.start_blind_skip_pvp_countdown = false
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

function MATCH_DOMAIN.apply_local_hand_score(score_text, score, state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.score_display = state.score_display or INTERNAL.restore_insane_int(state.score_text)
	state.force_zero_round_score = false
	state.score_text = score_text

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
	}
end

function MATCH_DOMAIN.begin_new_round(state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.duplicate_end = false
	state.round_failed = false
	state.round_ended = false
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

local function mark_server_resolved_blind(state)
	state = state or MATCH_DOMAIN.ensure_state()
	state.end_pvp = true
	state.timer_consumed = false
	state.timer_started = false
	state.nemesis_timer_started = false
	state.pvp_reached = false
	state.pvp_reached_first = false
	state.duel_blind_role = nil
	return MATCH_DOMAIN.reset_ready_blind_state(state)
end

function MATCH_DOMAIN.mark_end_pvp(state)
	return mark_server_resolved_blind(state)
end

function MATCH_DOMAIN.mark_end_coop_blind(state)
	return mark_server_resolved_blind(state)
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

return MATCH_DOMAIN
