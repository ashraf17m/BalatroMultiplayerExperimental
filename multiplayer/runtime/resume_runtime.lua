local resume_runtime = MP.RESUME or {}
MP.RESUME = resume_runtime

local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}
local teams_domain = MP.DOMAIN and MP.DOMAIN.TEAMS or {}
local reconnect_domain = MP.DOMAIN and MP.DOMAIN.RECONNECT or {}
local reconnect_persistence = MP.RECONNECT_PERSISTENCE or {}

local RESUME_SYNC_BUFFER = resume_runtime
local RESUME_SNAPSHOT = resume_runtime
local RESUME_APPLY = resume_runtime

-- ============================================================================
-- 1. Sync Buffer & Queuing (from resume_sync_buffer.lua)
-- ============================================================================
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
	endCoopBlind = "handle_end_coop_blind",
	winGame = "handle_win_game",
	aloneGame = "handle_alone_game",
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
		handler(runtime_match_sync.match_outcome_lost, runtime_match_sync.match_outcome_pvp_timer_lost)
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

function RESUME_SYNC_BUFFER.buffer_runtime_match_outcome(action_name, lost, pvp_timer_lost)
	if type(action_name) ~= "string" or action_name == "" then
		return false
	end

	return set_runtime_match_sync_field("match_outcome_action", action_name)
		and set_runtime_match_sync_field("match_outcome_lost", lost)
		and set_runtime_match_sync_field("match_outcome_pvp_timer_lost", pvp_timer_lost)
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

-- ============================================================================
-- 2. Snapshot Capture & Serialization (from resume_snapshot_capture.lua)
-- ============================================================================
if RESUME_SNAPSHOT._capture_loaded then
end
RESUME_SNAPSHOT._capture_loaded = true

local SNAPSHOT_CAPTURE_DEBOUNCE_SECONDS = 0.6
local SNAPSHOT_CAPTURE_MIN_INTERVAL_SECONDS = 2.5
local card_area_class = rawget(_G, "CardArea")
local tag_class = rawget(_G, "Tag")

local function get_reconnect_domain()
	return MP.DOMAIN and MP.DOMAIN.RECONNECT or nil
end

local function get_resume_capture_time()
	return BALATRO.get_wall_time()
end

local function copy_table_shallow(source)
	local result = {}
	for key, value in pairs(source or {}) do
		result[key] = value
	end
	return result
end

local function copy_sequence(source)
	local result = {}
	for index, value in ipairs(source or {}) do
		result[index] = value
	end
	return result
end

local function serialize_insane_int(value)
	if MP.INSANE_INT and MP.INSANE_INT.to_string and value then
		return MP.INSANE_INT.to_string(value)
	end

	return "0"
end

local function serialize_enemy_state(enemy)
	return {
		username = enemy.username or "Guest",
		score = serialize_insane_int(enemy.score),
		synced_score = serialize_insane_int(enemy.synced_score or enemy.score),
		score_text = tostring(enemy.score_text or "0"),
		hands = tonumber(enemy.hands) or 0,
		location = enemy.location or localize("loc_selecting"),
		raw_location = enemy.raw_location or "loc_selecting",
		is_disconnected = not not enemy.is_disconnected,
		skips = tonumber(enemy.skips) or 0,
		lives = tonumber(enemy.lives) or 0,
		team_lives = tonumber(enemy.team_lives) or tonumber(enemy.lives) or 0,
		sells = tonumber(enemy.sells) or 0,
		sells_per_ante = copy_table_shallow(enemy.sells_per_ante),
		spent_in_shop = copy_sequence(enemy.spent_in_shop),
		highest_score = serialize_insane_int(enemy.highest_score),
		team = enemy.team,
		in_match = enemy.in_match ~= false,
	}
end

local function build_saved_scoring_calc()
	local scoring_calculation = (G and G.GAME and G.GAME.current_scoring_calculation or nil)

	if type(scoring_calculation) == "table" and scoring_calculation.save then
		return scoring_calculation:save()
	end

	if type(scoring_calculation) == "table" then
		return {
			key = scoring_calculation.key or "multiply",
			config = scoring_calculation.config or {},
		}
	end

	return {
		key = "multiply",
		config = {},
	}
end

local function build_resume_run_snapshot()
	local root = G
	local game = (G and G.GAME or nil)
	local blind = (G and G.GAME and G.GAME.blind or nil)
	local selected_back = (G and G.GAME and G.GAME.selected_back or nil)
	if not (root and game and blind and selected_back) then
		return nil
	end

	local card_areas = {}
	for key, value in pairs(root) do
		if card_area_class and type(value) == "table" and value.is and value:is(card_area_class) then
			local serialized = (value and value.save and value:save() or nil)
			if serialized then
				card_areas[key] = serialized
			end
		end
	end

	local tags = {}
	for index, tag in ipairs((G and G.GAME and G.GAME.tags or nil) or {}) do
		if tag_class and type(value) == "table" and value.is and value:is(tag_class) then
			local serialized = (value and value.save and value:save() or nil)
			if serialized then
				tags[index] = serialized
			end
		end
	end

	return recursive_table_cull({
		cardAreas = card_areas,
		tags = tags,
		GAME = game,
		STATE = (G and G.STATE or nil),
		ACTION = (G and G.action or nil),
		BLIND = (blind and blind.save and blind:save() or nil),
		SCORING_CALC = build_saved_scoring_calc(),
		BACK = (selected_back and selected_back.save and selected_back:save() or nil),
		VERSION = (G and G.VERSION or nil),
	})
end

local function build_resume_match_state()
	local enemies = {}
	for player_id, enemy in pairs((MP.GAME and MP.GAME.enemies) or {}) do
		enemies[player_id] = serialize_enemy_state(enemy)
	end

	local team_card_restore = nil
	local playing_cards = (G and G.playing_cards or nil)
	if MP.is_shared_card_sync_enabled() and playing_cards then
		local card_ids = {}
		local card_ids_by_playing_card = {}
		for index, card in ipairs(playing_cards) do
			card_ids[index] = card.mp_card_id
			if card.playing_card ~= nil then
				card_ids_by_playing_card[tostring(card.playing_card)] = card.mp_card_id
			end
		end

		team_card_restore = {
			card_ids = card_ids,
			card_ids_by_playing_card = card_ids_by_playing_card,
			next_card_id = tonumber(G and G.GAME and G.GAME.mp_card_next_id) or #card_ids,
		}
	end

	return {
		ready_blind = not not MP.GAME.ready_blind,
		ready_blind_kind = MP.GAME.ready_blind_kind,
		ready_blind_text = MP.GAME.ready_blind_text,
		processed_round_done = not not MP.GAME.processed_round_done,
		lives = tonumber(MP.GAME.lives) or 0,
		score_text = tostring(MP.GAME.score_text or "0"),
		loaded_ante = tonumber(MP.GAME.loaded_ante) or 0,
		loading_blinds = not not MP.GAME.loading_blinds,
		force_zero_round_score = not not MP.GAME.force_zero_round_score,
		comeback_bonus_given = not not MP.GAME.comeback_bonus_given,
		comeback_bonus = tonumber(MP.GAME.comeback_bonus) or 0,
		comeback_eval_pending = not not MP.GAME.comeback_eval_pending,
		end_pvp = not not MP.GAME.end_pvp,
		enemies = enemies,
		location = MP.GAME.location or "loc_selecting",
		duel_bye_waiting = not not MP.GAME.duel_bye_waiting,
		skip_ready_blind_row = MP.GAME.skip_ready_blind_row,
		ante_key = tostring(MP.GAME.ante_key or ""),
		antes_keyed = copy_table_shallow(MP.GAME.antes_keyed),
		prevent_eval = not not MP.GAME.prevent_eval,
		round_failed = not not MP.GAME.round_failed,
		round_ended = not not MP.GAME.round_ended,
		duplicate_end = not not MP.GAME.duplicate_end,
		highest_score = serialize_insane_int(MP.GAME.highest_score),
		furthest_blind = tonumber(MP.GAME.furthest_blind) or 0,
		team_lives = tonumber(MP.GAME.team_lives) or tonumber(MP.GAME.lives) or 0,
		team_score = serialize_insane_int(MP.GAME.team_score),
		team_score_text = tostring(MP.GAME.team_score_text or "0"),
		misprint_display = tostring(MP.GAME.misprint_display or ""),
		spent_total = tostring(MP.GAME.spent_total or 0),
		spent_before_shop = tostring(MP.GAME.spent_before_shop or 0),
		real_money = tostring(MP.GAME.real_money or 0),
		timer = tonumber(MP.GAME.timer) or 0,
		timer_started = not not MP.GAME.timer_started,
		timer_locked_for_ante = not not MP.GAME.timer_locked_for_ante,
		timer_skip_count_for_ante = tonumber(MP.GAME.timer_skip_count_for_ante) or 0,
		timer_runtime_generation = tonumber(MP.GAME.timer_runtime_generation) or 0,
		wait_for_enemys_furthest_blind = not not MP.GAME.wait_for_enemys_furthest_blind,
		disable_live_and_timer_hud = not not MP.GAME.disable_live_and_timer_hud,
		pincher_index = tonumber(MP.GAME.pincher_index) or -3,
		pincher_unlock = not not MP.GAME.pincher_unlock,
		asteroids = tonumber(MP.GAME.asteroids) or 0,
		pizza_discards = tonumber(MP.GAME.pizza_discards) or 0,
		stats = copy_table_shallow(MP.GAME.stats),
		team_card_restore = team_card_restore,
	}
end

local function get_reconnect_snapshot_state()
	if not (MP.CONNECTION_SESSION and MP.CONNECTION_SESSION.get_reconnect_lobby_state) then
		return nil, nil
	end

	return MP.CONNECTION_SESSION.get_reconnect_lobby_state()
end

local function get_snapshot_capture_context()
	local reconnect_domain = get_reconnect_domain()
	local reconnect_persistence = MP.RECONNECT_PERSISTENCE or nil
	if not (reconnect_domain and reconnect_persistence) then
		return nil
	end

	local reconnect_token, lobby_code = get_reconnect_snapshot_state()
	if not reconnect_token or not lobby_code then
		return nil
	end

	return {
		reconnect_domain = reconnect_domain,
		reconnect_persistence = reconnect_persistence,
		reconnect_token = reconnect_token,
		lobby_code = lobby_code,
	}
end

local function can_capture_match_snapshot()
	return not not (
		MP
		and MP.LOBBY
		and MP.LOBBY.code
		and MP.is_lobby_match_in_progress
		and MP.is_lobby_match_in_progress()
		and (G and G.STAGES and G.STAGE == G.STAGES.RUN or false)
		and (G and G.GAME or nil)
		and (G and G.GAME and G.GAME.blind or nil)
		and (G and G.GAME and G.GAME.selected_back or nil)
	)
end

local function has_required_resume_runtime_objects()
	return not not (
		(G and G.hand or nil)
		and (G and G.deck or nil)
		and (G and G.play or nil)
		and (G and G.discard or nil)
		and (G and G.jokers or nil)
		and (G and G.consumeables or nil)
		and (G and G.GAME or nil)
		and (G and G.GAME and G.GAME.current_round or nil)
	)
end

local function is_safe_resume_checkpoint()
	if not can_capture_match_snapshot() or not has_required_resume_runtime_objects() then
		return false
	end

	if (G and G.CONTROLLER and G.CONTROLLER.locks and G.CONTROLLER.locks["load"] or nil) then
		return false
	end

	local states = (G and G.STATES or nil)
	local state = (G and G.STATE or nil)
	if not (states and state) then
		return false
	end

	return state == states.BLIND_SELECT
		or state == states.SELECTING_HAND
		or state == states.SHOP
end

local function build_current_resume_meta_snapshot(snapshot_context)
	return snapshot_context.reconnect_domain.build_resume_meta_snapshot({
		lobby_code = snapshot_context.lobby_code,
		reconnect_token = snapshot_context.reconnect_token,
		player_id = (G and G.MP_ID or nil),
		username = MP.LOBBY.client and MP.LOBBY.client.username or "Guest",
		saved_at = os.time(),
		mp_state = build_resume_match_state(),
	})
end

local function perform_current_match_snapshot_capture(opts)
	local options = opts or {}
	if not can_capture_match_snapshot() then
		return false
	end

	if not options.allow_unsafe and not is_safe_resume_checkpoint() then
		return false
	end

	local snapshot_context = get_snapshot_capture_context()
	if not snapshot_context then
		return false
	end

	local ok, err = pcall(function()
		local run_snapshot = build_resume_run_snapshot()
		if not run_snapshot then
			error("Could not build resume run snapshot.")
		end

		local meta_snapshot = build_current_resume_meta_snapshot(snapshot_context)
		if not snapshot_context.reconnect_persistence.save_resume_snapshots(run_snapshot, meta_snapshot) then
			error("Could not write resume snapshot files.")
		end
	end)

	if not ok then
		sendWarnMessage("Failed to store multiplayer resume snapshot.", "MULTIPLAYER")
		sendTraceMessage(tostring(err), "MULTIPLAYER")
		return false
	end

	snapshot_context.reconnect_domain.note_snapshot_captured(get_resume_capture_time())

	return true
end

function RESUME_SNAPSHOT.build_current_match_snapshot(opts)
	local options = opts or {}
	if not can_capture_match_snapshot() then
		return nil, "No active multiplayer run is available to save."
	end

	if not options.allow_unsafe and not is_safe_resume_checkpoint() then
		return nil, "Co-op saves are only available between actions."
	end

	local run_snapshot = build_resume_run_snapshot()
	if not run_snapshot then
		return nil, "Could not build the run snapshot."
	end

	return {
		run_snapshot = run_snapshot,
		mp_state = build_resume_match_state(),
	}
end

function RESUME_SNAPSHOT.build_current_encoded_match_snapshot(opts)
	if not (MP.UTILS and MP.UTILS.str_pack_and_encode) then
		return nil, "Snapshot serialization is unavailable."
	end

	local snapshot, err = RESUME_SNAPSHOT.build_current_match_snapshot(opts)
	if not snapshot then
		return nil, err
	end

	local ok, run_data, mp_state_data = pcall(function()
		return MP.UTILS.str_pack_and_encode(snapshot.run_snapshot, "coop_save.run"),
			MP.UTILS.str_pack_and_encode(snapshot.mp_state, "coop_save.mp_state")
	end)
	if not ok then
		return nil, tostring(run_data)
	end

	return {
		runData = run_data,
		mpStateData = mp_state_data,
	}
end

function RESUME_SNAPSHOT.capture_current_match_snapshot(opts)
	local reconnect_domain = get_reconnect_domain()
	if not reconnect_domain then
		return false
	end

	local options = opts or {}
	local now = get_resume_capture_time()
	if not reconnect_domain.can_capture_snapshot_now(now, options.force, SNAPSHOT_CAPTURE_MIN_INTERVAL_SECONDS) then
		return false
	end

	return perform_current_match_snapshot_capture(options)
end

function RESUME_SNAPSHOT.request_current_match_snapshot(opts)
	local reconnect_domain = get_reconnect_domain()
	if not reconnect_domain then
		return false
	end

	local options = opts or {}
	if options.force then
		return RESUME_SNAPSHOT.capture_current_match_snapshot(options)
	end

	if not can_capture_match_snapshot() then
		return false
	end

	local now = get_resume_capture_time()
	reconnect_domain.request_snapshot_capture(now, {
		allow_unsafe = options.allow_unsafe,
		debounce_seconds = options.delay_seconds or SNAPSHOT_CAPTURE_DEBOUNCE_SECONDS,
	})

	return true
end

function RESUME_SNAPSHOT.update_pending_snapshot_capture()
	local reconnect_domain = get_reconnect_domain()
	if not reconnect_domain then
		return false
	end

	if not reconnect_domain.get_pending_snapshot_capture() then
		return false
	end

	if not can_capture_match_snapshot() then
		reconnect_domain.clear_pending_snapshot_capture()
		return false
	end

	local now = get_resume_capture_time()
	local due_snapshot_capture = reconnect_domain.get_due_snapshot_capture(now, SNAPSHOT_CAPTURE_MIN_INTERVAL_SECONDS)
	if not due_snapshot_capture then
		return false
	end

	return RESUME_SNAPSHOT.capture_current_match_snapshot({
		allow_unsafe = due_snapshot_capture.allow_unsafe,
		force = true,
	})
end

-- ============================================================================
-- 3. Manual Resume Apply & Metadata (from resume_snapshot_manual_apply.lua)
-- ============================================================================
if RESUME_SNAPSHOT._manual_apply_loaded then
end
RESUME_SNAPSHOT._manual_apply_loaded = true

local function get_reconnect_domain()
	return MP.DOMAIN and MP.DOMAIN.RECONNECT or nil
end

local function get_reconnect_persistence()
	return MP.RECONNECT_PERSISTENCE or nil
end

local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end

local function reset_resume_runtime_state()
	local reconnect_domain = get_reconnect_domain()
	if reconnect_domain then
		reconnect_domain.reset_resume_runtime_state()
	end
end

local function load_saved_resume_snapshot(loader_name)
	local reconnect_persistence = get_reconnect_persistence()
	if not reconnect_persistence then
		return nil, "Resume persistence is unavailable."
	end

	return reconnect_persistence[loader_name](reconnect_persistence)
end

local function validate_saved_resume_meta_snapshot(meta_snapshot)
	local reconnect_domain = get_reconnect_domain()
	if not reconnect_domain then
		return false, "Resume domain is unavailable."
	end

	return reconnect_domain.validate_resume_meta_snapshot(meta_snapshot)
end

local function create_pending_manual_resume(run_snapshot, meta_snapshot)
	local reconnect_domain = get_reconnect_domain()
	if not reconnect_domain then
		return nil
	end

	local resume_snapshot = reconnect_domain.build_manual_resume(run_snapshot, meta_snapshot)
	reconnect_domain.set_pending_manual_resume(resume_snapshot)

	if MP.CONNECTION_SESSION and MP.CONNECTION_SESSION.set_reconnect_lobby_state then
		MP.CONNECTION_SESSION.set_reconnect_lobby_state(meta_snapshot.reconnect_token, meta_snapshot.lobby_code)
	end

	return resume_snapshot
end

function RESUME_SNAPSHOT.has_saved_resume()
	local reconnect_persistence = get_reconnect_persistence()
	if not reconnect_persistence then
		return false
	end

	return reconnect_persistence.has_saved_resume()
end

function RESUME_SNAPSHOT.clear_saved_resume()
	local reconnect_persistence = get_reconnect_persistence()
	reset_resume_runtime_state()
	if reconnect_persistence then
		reconnect_persistence.clear_saved_resume_files()
	end
end

function RESUME_SNAPSHOT.begin_manual_resume()
	if not RESUME_SNAPSHOT.has_saved_resume() then
		trace_runtime_event("resume.manual_begin_blocked", {
			reason = "no_saved_match",
		})
		return nil, "No saved match was found."
	end

	local run_snapshot, run_err = load_saved_resume_snapshot("load_saved_resume_run_snapshot")
	if not run_snapshot then
		trace_runtime_event("resume.manual_begin_failed", {
			reason = "run_snapshot_load_failed",
			error = run_err,
			clear_saved_files = true,
		})
		RESUME_SNAPSHOT.clear_saved_resume()
		return nil, run_err
	end

	local meta_snapshot, meta_err = load_saved_resume_snapshot("load_saved_resume_meta_snapshot")
	if not meta_snapshot then
		trace_runtime_event("resume.manual_begin_failed", {
			reason = "meta_snapshot_load_failed",
			error = meta_err,
			clear_saved_files = true,
		})
		RESUME_SNAPSHOT.clear_saved_resume()
		return nil, meta_err
	end

	local is_valid_meta_snapshot, validation_err = validate_saved_resume_meta_snapshot(meta_snapshot)
	if not is_valid_meta_snapshot then
		trace_runtime_event("resume.manual_begin_failed", {
			reason = "meta_snapshot_invalid",
			error = validation_err,
			clear_saved_files = true,
		})
		RESUME_SNAPSHOT.clear_saved_resume()
		return nil, validation_err
	end

	trace_runtime_event("resume.manual_begin_ready", {
		lobby_code = meta_snapshot.lobby_code,
		has_reconnect_token = meta_snapshot.reconnect_token ~= nil,
	})
	return create_pending_manual_resume(run_snapshot, meta_snapshot)
end

function RESUME_SNAPSHOT.get_pending_manual_resume()
	local reconnect_domain = get_reconnect_domain()
	if not reconnect_domain then
		return nil
	end

	return reconnect_domain.get_pending_manual_resume()
end

function RESUME_SNAPSHOT.complete_manual_resume()
	local reconnect_domain = get_reconnect_domain()
	if reconnect_domain then
		reconnect_domain.clear_pending_manual_resume()
	end
	trace_runtime_event("resume.manual_complete", {})
end

function RESUME_SNAPSHOT.fail_manual_resume(clear_saved_files)
	trace_runtime_event("resume.manual_fail", {
		clear_saved_files = clear_saved_files,
	})
	if clear_saved_files then
		RESUME_SNAPSHOT.clear_saved_resume()
		return
	end

	reset_resume_runtime_state()
end

function RESUME_SNAPSHOT.refresh_saved_resume_metadata(token, code, player_id)
	local reconnect_domain = get_reconnect_domain()
	local reconnect_persistence = get_reconnect_persistence()
	if not (reconnect_domain and reconnect_persistence) then
		return false
	end

	if not RESUME_SNAPSHOT.has_saved_resume() then
		return false
	end

	local meta_snapshot = load_saved_resume_snapshot("load_saved_resume_meta_snapshot")
	if not meta_snapshot then
		return false
	end

	meta_snapshot = reconnect_domain.refresh_resume_meta_snapshot(meta_snapshot, token, code, player_id)
	return reconnect_persistence.save_resume_meta_snapshot(meta_snapshot)
end

function RESUME_SNAPSHOT.apply_saved_mp_state(saved_state)
	if type(saved_state) ~= "table" or not (MP.GAME and match_domain.apply_saved_state) then
		return
	end

	match_domain.apply_saved_state(saved_state)
end

-- ============================================================================
-- 4. Runtime State Repair & UI Apply (from resume_runtime_apply.lua)
-- ============================================================================
local function repair_scoring_calculation(game_state)
	if type(game_state) ~= "table" then
		return
	end

	local scoring_calculation = game_state.current_scoring_calculation
	if type(scoring_calculation) == "table" and scoring_calculation.func == nil then
		local key = scoring_calculation.key or "multiply"
		local definitions = MP.PLATFORM.SMODS.get_scoring_calculation_definitions()
		local definition = definitions and definitions[key]

		if definition and definition.load then
			game_state.current_scoring_calculation = definition:load(scoring_calculation)
		elseif definition and definition.new then
			game_state.current_scoring_calculation = definition:new(scoring_calculation)
		else
			game_state.current_scoring_calculation = nil
			sendWarnMessage(
				"Missing scoring calculation definition for saved resume state: " .. tostring(key),
				"MULTIPLAYER"
			)
		end
	end
end

local function refresh_resumed_team_shared_score()
	if not MP.GAME then
		return
	end

	if teams_domain.recalculate_state then
		teams_domain.recalculate_state()
	end

	local is_cooperative_shared_score = (teams_domain.is_cooperative_blind and teams_domain.is_cooperative_blind())
		or (MP.is_coop_blind and MP.is_coop_blind())

	if is_cooperative_shared_score then
		if match_domain.set_shared_score_text then
			match_domain.set_shared_score_text(MP.GAME.team_score_text or MP.GAME.shared_score_text or "0")
		end
		if (G and G.HUD) and MP.UI and MP.UI.hide_enemy_location then
			local chip_UI = BALATRO.get_hud_element_by_id and BALATRO.get_hud_element_by_id("chip_UI_count")
			if not (chip_UI and chip_UI.config and chip_UI.config.func == "mp_shared_chip_UI_set") then
				MP.UI.hide_enemy_location()
			end
		end
		if MP.UI and MP.UI.request_shared_score_refresh then
			MP.UI.request_shared_score_refresh()
		end
	end
end

local function reapply_post_resume_multiplayer_blind_ui()
	if not (MP.UI and MP.UI.reapply_active_multiplayer_blind_ui) then
		return false
	end

	local ui_reapplied = MP.UI.reapply_active_multiplayer_blind_ui()
	if ui_reapplied then
		refresh_resumed_team_shared_score()
		return true
	end

	if BALATRO.queue_event then
		BALATRO.queue_event({
			trigger = "after",
			delay = 0.2,
			blockable = false,
			func = function()
				if MP.UI and MP.UI.reapply_active_multiplayer_blind_ui then
					MP.UI.reapply_active_multiplayer_blind_ui()
				end
				refresh_resumed_team_shared_score()
				return true
			end,
		})
		return true
	end

	return false
end

function RESUME_APPLY.repair_saved_run_snapshot(saved_run_snapshot)
	if type(saved_run_snapshot) ~= "table" then
		return
	end

	if type(saved_run_snapshot.SCORING_CALC) ~= "table" then
		local game_state = saved_run_snapshot.GAME or {}
		local scoring_calculation = game_state.current_scoring_calculation
		saved_run_snapshot.SCORING_CALC = {
			key = (type(scoring_calculation) == "table" and scoring_calculation.key) or "multiply",
			config = (type(scoring_calculation) == "table" and scoring_calculation.config) or {},
		}
	end

	repair_scoring_calculation(saved_run_snapshot.GAME)
end

function RESUME_APPLY.repair_post_resume_run_state()
	local game = (G and G.GAME) or nil
	if not game then
		return
	end

	repair_scoring_calculation(game)

	if MP.UI and MP.UI.refresh_timer_hud_binding then
		MP.UI.refresh_timer_hud_binding()
	end
	if MP.UI and MP.UI.refresh_lives_hud_binding then
		MP.UI.refresh_lives_hud_binding()
	end

	if
		MP.PLATFORM.SMODS.refresh_score_ui_list
		and (G and G.HUD)
		and BALATRO.call_ui_function
	then
		local hand_text_area = BALATRO.get_hud_element_by_id("hand_text_area")
		local operator_container = BALATRO.get_hud_element_by_id("hand_operator_container")

		if hand_text_area then
			BALATRO.call_ui_function("SMODS_scoring_calculation_function", hand_text_area)
		end
		if operator_container then
			BALATRO.recalculate_ui(operator_container)
		end

		MP.PLATFORM.SMODS.refresh_score_ui_list()
	end
end

function RESUME_APPLY.clear_resume_main_menu_ui()
	BALATRO.clear_main_menu_ui()
end

function RESUME_APPLY.apply_resumed_multiplayer_session_state(queued_resume)
	if match_domain.reset_state then
		match_domain.reset_state()
	end

	if MP.RESUME and MP.RESUME.apply_saved_mp_state then
		MP.RESUME.apply_saved_mp_state(queued_resume and queued_resume.mp_state or {})
	end

	if MP.NETWORKING_INTERNAL and MP.NETWORKING_INTERNAL.restore_local_ante_timer_state then
		local timer = MP.GAME and MP.GAME.timer or 0
		local timer_started = MP.GAME and MP.GAME.timer_started or false
		MP.NETWORKING_INTERNAL.restore_local_ante_timer_state(timer, timer_started)
	end

	if MP.NETWORKING_INTERNAL and MP.NETWORKING_INTERNAL.sync_resume_enemies_from_lobby then
		MP.NETWORKING_INTERNAL.sync_resume_enemies_from_lobby()
	end

	if MP.RESUME and MP.RESUME.flush_runtime_match_sync_buffer then
		MP.RESUME.flush_runtime_match_sync_buffer()
	end

	if MP.OPPONENTS and MP.OPPONENTS.refresh_primary_enemy_view then
		MP.OPPONENTS.refresh_primary_enemy_view()
	end
end

function RESUME_APPLY.repair_post_resume_ui_state()
	if MP.RESUME and MP.RESUME.repair_post_resume_run_state then
		MP.RESUME.repair_post_resume_run_state()
	end

	refresh_resumed_team_shared_score()
	reapply_post_resume_multiplayer_blind_ui()

	if MP.RESUME and MP.RESUME.request_current_match_snapshot then
		MP.RESUME.request_current_match_snapshot()
	end
end

-- ============================================================================
-- 5. Game Run Start Hook & Lifecycle (from resume_runtime.lua)
-- ============================================================================
function resume_runtime.on_game_start_run(args)
	if not (args and args.mp_resume) then
		return
	end

	if reconnect_domain and reconnect_domain.set_resume_transition_active then
		reconnect_domain.set_resume_transition_active(false)
	end
	local queued_resume = resume_runtime.consume_runtime_resume and resume_runtime.consume_runtime_resume() or nil

	resume_runtime.clear_resume_main_menu_ui()
	resume_runtime.apply_resumed_multiplayer_session_state(queued_resume)
	resume_runtime.repair_post_resume_ui_state()
end

return resume_runtime
