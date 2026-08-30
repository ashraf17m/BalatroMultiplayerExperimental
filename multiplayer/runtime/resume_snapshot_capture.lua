local RESUME_SNAPSHOT = MP.RESUME or {}
MP.RESUME = RESUME_SNAPSHOT

if RESUME_SNAPSHOT._capture_loaded then
	return RESUME_SNAPSHOT
end
RESUME_SNAPSHOT._capture_loaded = true

local SNAPSHOT_CAPTURE_DEBOUNCE_SECONDS = 0.6
local SNAPSHOT_CAPTURE_MIN_INTERVAL_SECONDS = 2.5
local BALATRO = MP.PLATFORM.BALATRO

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
	local scoring_calculation = BALATRO.get_current_scoring_calculation()

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
	local root = BALATRO.get_root()
	local game = BALATRO.get_game()
	local blind = BALATRO.get_current_blind()
	local selected_back = BALATRO.get_selected_back()
	if not (root and game and blind and selected_back) then
		return nil
	end

	local card_areas = {}
	for key, value in pairs(root) do
		if BALATRO.is_card_area_instance(value) then
			local serialized = BALATRO.save_object(value)
			if serialized then
				card_areas[key] = serialized
			end
		end
	end

	local tags = {}
	for index, tag in ipairs(BALATRO.get_tags() or {}) do
		if BALATRO.is_tag_instance(tag) then
			local serialized = BALATRO.save_object(tag)
			if serialized then
				tags[index] = serialized
			end
		end
	end

	return recursive_table_cull({
		cardAreas = card_areas,
		tags = tags,
		GAME = game,
		STATE = BALATRO.get_state(),
		ACTION = BALATRO.get_action(),
		BLIND = BALATRO.save_object(blind),
		SCORING_CALC = build_saved_scoring_calc(),
		BACK = BALATRO.save_object(selected_back),
		VERSION = BALATRO.get_version(),
	})
end

local function build_resume_match_state()
	local enemies = {}
	for player_id, enemy in pairs((MP.GAME and MP.GAME.enemies) or {}) do
		enemies[player_id] = serialize_enemy_state(enemy)
	end

	local team_card_restore = nil
	local playing_cards = BALATRO.get_playing_cards()
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
			next_card_id = tonumber(BALATRO.get_mp_card_next_id()) or #card_ids,
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
		and BALATRO.is_run_stage()
		and BALATRO.get_game()
		and BALATRO.get_current_blind()
		and BALATRO.get_selected_back()
	)
end

local function has_required_resume_runtime_objects()
	return not not (
		BALATRO.get_hand_area()
		and BALATRO.get_deck_area()
		and BALATRO.get_play_area()
		and BALATRO.get_discard_area()
		and BALATRO.get_jokers_area()
		and BALATRO.get_consumeables_area()
		and BALATRO.get_game()
		and BALATRO.get_current_round()
	)
end

local function is_safe_resume_checkpoint()
	if not can_capture_match_snapshot() or not has_required_resume_runtime_objects() then
		return false
	end

	if BALATRO.get_controller_lock("load") then
		return false
	end

	local states = BALATRO.get_states()
	local state = BALATRO.get_state()
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
		player_id = BALATRO.get_player_id(),
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

return RESUME_SNAPSHOT
