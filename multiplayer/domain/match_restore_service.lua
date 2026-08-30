MP.DOMAIN = MP.DOMAIN or {}
MP.DOMAIN.MATCH = MP.DOMAIN.MATCH or {}

local MATCH_DOMAIN = MP.DOMAIN.MATCH
MATCH_DOMAIN.INTERNAL = MATCH_DOMAIN.INTERNAL or {}

local INTERNAL = MATCH_DOMAIN.INTERNAL

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
