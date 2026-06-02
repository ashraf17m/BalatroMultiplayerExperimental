local RESUME_SYNC_BUFFER = {}

local function normalize_hand_level(level)
	local hand_level_sync = MP.SYNC and MP.SYNC.TEAM_HAND_LEVEL or nil
	if hand_level_sync and hand_level_sync.serialize_hand_level then
		return hand_level_sync.serialize_hand_level(level)
	end
	if type(level) == "string" and level ~= "" then
		return level
	end
	if type(level) == "number" then
		return tostring(level)
	end
	return nil
end

local function get_reconnect_domain()
	return MP.DOMAIN and MP.DOMAIN.RECONNECT or nil
end

local function begin_runtime_match_sync_buffer()
	local reconnect_domain = get_reconnect_domain()
	if not reconnect_domain then
		return nil
	end

	return reconnect_domain.begin_runtime_match_sync_buffer()
end

local function get_active_runtime_match_sync_buffer()
	local reconnect_domain = get_reconnect_domain()
	if not reconnect_domain then
		return nil
	end

	return reconnect_domain.get_runtime_match_sync_buffer()
end

local function set_runtime_match_sync_field(field_name, value)
	local runtime_match_sync = get_active_runtime_match_sync_buffer()
	if not runtime_match_sync then
		return false
	end

	runtime_match_sync[field_name] = value
	return true
end

local function set_runtime_match_sync_collection_entry(collection_name, entry_key, value)
	local runtime_match_sync = get_active_runtime_match_sync_buffer()
	if not runtime_match_sync then
		return false
	end

	runtime_match_sync[collection_name][tostring(entry_key)] = value
	return true
end

local function apply_buffered_runtime_collection(runtime_match_sync, collection_name, handler_name)
	local handler = MP.NETWORKING_INTERNAL and MP.NETWORKING_INTERNAL[handler_name]
	if not handler then
		return
	end

	for _, payload in pairs(runtime_match_sync[collection_name] or {}) do
		handler(payload)
	end
end

local MATCH_OUTCOME_HANDLERS = {
	endPvP = "handle_end_pvp",
	winGame = "handle_win_game",
	loseGame = "handle_lose_game",
}

local function apply_buffered_runtime_player_info(runtime_match_sync)
	if not (runtime_match_sync.player_info and MP.NETWORKING_INTERNAL and MP.NETWORKING_INTERNAL.handle_player_info) then
		return
	end

	MP.NETWORKING_INTERNAL.handle_player_info(
		runtime_match_sync.player_info.lives,
		runtime_match_sync.player_info.life_loss_reason,
		runtime_match_sync.player_info.previous_lives,
		runtime_match_sync.player_info.team
	)
end

local function apply_buffered_runtime_money_update(runtime_match_sync)
	if not (runtime_match_sync.money_update and MP.NETWORKING_INTERNAL and MP.NETWORKING_INTERNAL.handle_money_update) then
		return
	end

	MP.NETWORKING_INTERNAL.handle_money_update(
		runtime_match_sync.money_update.money,
		runtime_match_sync.money_update.delta,
		runtime_match_sync.money_update.source_player_id
	)
end

local function apply_buffered_runtime_enemy_infos(runtime_match_sync)
	apply_buffered_runtime_collection(runtime_match_sync, "enemy_info_by_player_id", "handle_enemy_info")
end

local function apply_buffered_runtime_enemy_locations(runtime_match_sync)
	apply_buffered_runtime_collection(runtime_match_sync, "enemy_location_by_player_id", "handle_enemy_location")
end

local function apply_buffered_runtime_team_card_syncs(runtime_match_sync)
	apply_buffered_runtime_collection(runtime_match_sync, "team_card_sync_by_card_id", "handle_team_card_sync")
end

local function apply_buffered_runtime_team_hand_level_syncs(runtime_match_sync)
	apply_buffered_runtime_collection(runtime_match_sync, "team_hand_level_sync_by_hand", "handle_team_hand_level_sync")
end

local function apply_buffered_runtime_timer_state(runtime_match_sync)
	local timer_state = runtime_match_sync.timer_state
	if not timer_state then
		return
	end

	if MP.NETWORKING_INTERNAL and MP.NETWORKING_INTERNAL.restore_local_ante_timer_state then
		MP.NETWORKING_INTERNAL.restore_local_ante_timer_state(
			timer_state.time,
			timer_state.kind == "start",
			timer_state.server_now,
			timer_state.deadline_at,
			timer_state.timer_generation
		)
		return
	end

	local handler_name = timer_state.kind == "start" and "handle_start_ante_timer" or "handle_pause_ante_timer"
	local handler = MP.NETWORKING_INTERNAL and MP.NETWORKING_INTERNAL[handler_name]
	if handler then
		handler(
			timer_state.time,
			timer_state.server_now,
			timer_state.deadline_at,
			timer_state.timer_generation
		)
	end
end

local function apply_buffered_runtime_match_outcome(runtime_match_sync)
	local handler_name = MATCH_OUTCOME_HANDLERS[runtime_match_sync.match_outcome_action]
	local handler = handler_name and MP.NETWORKING_INTERNAL and MP.NETWORKING_INTERNAL[handler_name]
	if handler then
		handler()
	end
end

function RESUME_SYNC_BUFFER.queue_runtime_resume(saved_match_state)
	local reconnect_domain = get_reconnect_domain()
	if not reconnect_domain then
		return false
	end

	begin_runtime_match_sync_buffer()
	reconnect_domain.set_pending_team_card_restore(
		type(saved_match_state) == "table" and saved_match_state.team_card_restore or nil
	)
	reconnect_domain.set_pending_runtime_resume({
		mp_state = saved_match_state or {},
	})
	return true
end

function RESUME_SYNC_BUFFER.get_pending_team_card_restore()
	local reconnect_domain = get_reconnect_domain()
	if not reconnect_domain then
		return nil
	end

	return reconnect_domain.get_pending_team_card_restore()
end

function RESUME_SYNC_BUFFER.activate_runtime_match_sync_buffer()
	return begin_runtime_match_sync_buffer() ~= nil
end

function RESUME_SYNC_BUFFER.consume_runtime_resume()
	local reconnect_domain = get_reconnect_domain()
	if not reconnect_domain then
		return nil
	end

	return reconnect_domain.consume_runtime_resume()
end

function RESUME_SYNC_BUFFER.is_resume_transition_active()
	local reconnect_domain = get_reconnect_domain()
	if not reconnect_domain then
		return false
	end

	return reconnect_domain.is_resume_transition_active()
end

function RESUME_SYNC_BUFFER.is_runtime_match_sync_buffer_active()
	return get_active_runtime_match_sync_buffer() ~= nil
end

function RESUME_SYNC_BUFFER.buffer_runtime_player_info(lives, life_loss_reason, previous_lives, team)
	return set_runtime_match_sync_field("player_info", {
		lives = lives,
		life_loss_reason = life_loss_reason,
		previous_lives = previous_lives,
		team = team,
	})
end

function RESUME_SYNC_BUFFER.buffer_runtime_money_update(money, delta, source_player_id)
	return set_runtime_match_sync_field("money_update", {
		money = money,
		delta = delta,
		source_player_id = source_player_id,
	})
end

function RESUME_SYNC_BUFFER.buffer_runtime_enemy_info(enemy_info)
	if type(enemy_info) ~= "table" or enemy_info.playerId == nil then
		return false
	end

	local player_id = enemy_info.playerId
	return set_runtime_match_sync_collection_entry("enemy_info_by_player_id", player_id, {
		playerId = enemy_info.playerId,
		username = enemy_info.username,
		score = enemy_info.score,
		handsLeft = enemy_info.handsLeft,
		skips = enemy_info.skips,
		lives = enemy_info.lives,
		team = enemy_info.team,
		teamLives = enemy_info.teamLives,
		lifeLossReason = enemy_info.lifeLossReason,
		previousLives = enemy_info.previousLives,
	})
end

function RESUME_SYNC_BUFFER.buffer_runtime_enemy_location(options)
	local player_id = options and options.playerId
	if player_id == nil then
		return false
	end

	return set_runtime_match_sync_collection_entry("enemy_location_by_player_id", player_id, options)
end

local function buffer_runtime_timer_state(kind, time, server_now, deadline_at, timer_generation)
	return set_runtime_match_sync_field("timer_state", {
		kind = kind,
		time = time,
		server_now = server_now,
		deadline_at = deadline_at,
		timer_generation = timer_generation,
	})
end

function RESUME_SYNC_BUFFER.buffer_runtime_start_ante_timer(time, server_now, deadline_at, timer_generation)
	return buffer_runtime_timer_state("start", time, server_now, deadline_at, timer_generation)
end

function RESUME_SYNC_BUFFER.buffer_runtime_pause_ante_timer(time, server_now, deadline_at, timer_generation)
	return buffer_runtime_timer_state("pause", time, server_now, deadline_at, timer_generation)
end

function RESUME_SYNC_BUFFER.buffer_runtime_team_card_sync(parsed_action)
	if type(parsed_action) ~= "table" or not parsed_action.cardKey then
		return false
	end

	return set_runtime_match_sync_collection_entry("team_card_sync_by_card_id", parsed_action.cardKey, {
		action = parsed_action.action or "teamCardSync",
		playerId = parsed_action.playerId,
		username = parsed_action.username,
		cardKey = parsed_action.cardKey,
		actionType = parsed_action.actionType,
		cardData = parsed_action.cardData,
	})
end

function RESUME_SYNC_BUFFER.buffer_runtime_team_hand_level_sync(parsed_action)
	if type(parsed_action) ~= "table" or not parsed_action.hand then
		return false
	end

	local level = normalize_hand_level(parsed_action.level)
	if level == nil then
		return false
	end

	return set_runtime_match_sync_collection_entry("team_hand_level_sync_by_hand", parsed_action.hand, {
		action = parsed_action.action or "teamHandLevelSync",
		playerId = parsed_action.playerId,
		username = parsed_action.username,
		hand = parsed_action.hand,
		level = level,
	})
end

function RESUME_SYNC_BUFFER.buffer_runtime_match_outcome(action_name)
	if type(action_name) ~= "string" or action_name == "" then
		return false
	end

	return set_runtime_match_sync_field("match_outcome_action", action_name)
end

function RESUME_SYNC_BUFFER.flush_runtime_match_sync_buffer()
	local reconnect_domain = get_reconnect_domain()
	if not reconnect_domain then
		return false
	end

	local runtime_match_sync = reconnect_domain.consume_runtime_match_sync_buffer()
	if not runtime_match_sync then
		return false
	end

	apply_buffered_runtime_player_info(runtime_match_sync)
	apply_buffered_runtime_money_update(runtime_match_sync)
	apply_buffered_runtime_enemy_infos(runtime_match_sync)
	apply_buffered_runtime_enemy_locations(runtime_match_sync)
	apply_buffered_runtime_team_card_syncs(runtime_match_sync)
	apply_buffered_runtime_team_hand_level_syncs(runtime_match_sync)
	apply_buffered_runtime_timer_state(runtime_match_sync)
	apply_buffered_runtime_match_outcome(runtime_match_sync)

	return true
end

return RESUME_SYNC_BUFFER
