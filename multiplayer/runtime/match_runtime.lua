-- Consolidated match_runtime.lua
-- Combines: match_lifecycle.lua, match_action_runtime.lua, match_flow_runtime.lua, match_message_runtime.lua

MP.ACTIONS = MP.ACTIONS or {}
MP.MATCH_LIFECYCLE = MP.MATCH_LIFECYCLE or {}
MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}

local match_lifecycle = MP.MATCH_LIFECYCLE
local match_action_runtime = MP.ACTIONS
local match_flow_runtime = {}
local match_message_runtime = {}

local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}
local teams_domain = MP.DOMAIN and MP.DOMAIN.TEAMS or {}
local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY or {}
local build_traceback = MP.UTILS and MP.UTILS.build_traceback
local load_required_service = MP.UTILS and MP.UTILS.load_required_service
local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end

-- ==========================================================================
-- Section 1: Match Lifecycle
-- ==========================================================================

local function close_overlay_menu_if_open()
	if MP.CONNECTION_SESSION and MP.CONNECTION_SESSION.request_overlay_menu_close then
		MP.CONNECTION_SESSION.request_overlay_menu_close()
	end
end

local function set_team_card_sync_suspended(is_suspended)
	MP.TEAM_CARD_SUSPENDED = not not is_suspended
	return MP.TEAM_CARD_SUSPENDED
end

function match_lifecycle.suspend_team_card_sync()
	return set_team_card_sync_suspended(true)
end

function match_lifecycle.resume_team_card_sync()
	return set_team_card_sync_suspended(false)
end

function match_lifecycle.request_resume_snapshot()
	if MP.RESUME and MP.RESUME.request_current_match_snapshot then
		MP.RESUME.request_current_match_snapshot()
	end
end

function match_lifecycle.capture_resume_snapshot()
	if MP.RESUME and MP.RESUME.capture_current_match_snapshot then
		local captured = MP.RESUME.capture_current_match_snapshot({ force = true })
		trace_runtime_event("resume.snapshot_capture", {
			captured = captured,
		})
		return captured
	end

	trace_runtime_event("resume.snapshot_capture", {
		captured = false,
		reason = "missing_capture_handler",
	})
	return false
end

function match_lifecycle.has_saved_resume()
	return not not (MP.RESUME and MP.RESUME.has_saved_resume and MP.RESUME.has_saved_resume())
end

function match_lifecycle.clear_saved_resume()
	if MP.RESUME and MP.RESUME.clear_saved_resume then
		MP.RESUME.clear_saved_resume()
	end
end

function match_lifecycle.reset_local_blind_ready_runtime()
	if not (MP.GAME and match_domain.reset_ready_blind_state) then
		return
	end

	match_domain.reset_ready_blind_state()
end

function match_lifecycle.prepare_end_game_view()
	match_lifecycle.suspend_team_card_sync()
	if MP.UI and MP.UI.reset_end_game_view_runtime then
		MP.UI.reset_end_game_view_runtime({ preserve_cache = true })
	end
	if MP.ACTIONS and MP.ACTIONS.cache_end_game_state then
		MP.ACTIONS.cache_end_game_state()
	end
	if MP.UI and MP.UI.capture_end_game_view_players then
		MP.UI.capture_end_game_view_players()
	end
	if MP.UI and MP.UI.prefetch_end_game_view_players then
		MP.UI.prefetch_end_game_view_players()
	end
end

local function begin_active_match_session()
	match_lifecycle.resume_team_card_sync()
	if lobby_domain.set_match_in_progress then
		lobby_domain.set_match_in_progress(true)
	end

	close_overlay_menu_if_open()
end

function match_lifecycle.begin_match_runtime()
	begin_active_match_session()
	if MP.COOP_BOSS_BLIND and MP.COOP_BOSS_BLIND.reset_runtime then
		MP.COOP_BOSS_BLIND.reset_runtime()
	end
	match_domain.reset_state()
	if MP.UI and type(MP.UI.reset_end_game_view_runtime) == "function" then
		local ok, err = pcall(MP.UI.reset_end_game_view_runtime, { preserve_cache = false })
		if not ok and sendWarnMessage then
			sendWarnMessage("Failed to clear end-game cache on match start: " .. tostring(err), "MULTIPLAYER")
		end
	end
	if MP.NETWORKING_INTERNAL and MP.NETWORKING_INTERNAL.reset_end_game_summary_updates then
		MP.NETWORKING_INTERNAL.reset_end_game_summary_updates()
	end
	if MP.STATE_APPLY and MP.STATE_APPLY.seed_match_enemies_from_lobby then
		MP.STATE_APPLY.seed_match_enemies_from_lobby()
	end
	if MP.OPPONENTS and MP.OPPONENTS.refresh_primary_enemy_view then
		MP.OPPONENTS.refresh_primary_enemy_view()
	end
end

function match_lifecycle.prepare_resume_runtime()
	begin_active_match_session()
	if MP.COOP_BOSS_BLIND and MP.COOP_BOSS_BLIND.reset_runtime then
		MP.COOP_BOSS_BLIND.reset_runtime()
	end
end

local function resolve_connection_loss_message(message, resume_available, opts)
	local options = opts or {}
	if not (options.resume_message or options.no_resume_message) then
		return message
	end

	if resume_available then
		return options.resume_message or message
	end

	return options.no_resume_message or message
end

function match_lifecycle.transition_to_menu_after_connection_loss(message, opts)
	close_overlay_menu_if_open()
	if MP.CONNECTION_FEEDBACK and MP.CONNECTION_FEEDBACK.clear_all_countdowns then
		MP.CONNECTION_FEEDBACK.clear_all_countdowns()
	end
	match_lifecycle.suspend_team_card_sync()
	local resume_available = match_lifecycle.capture_resume_snapshot() or match_lifecycle.has_saved_resume()
	trace_runtime_event("connection.loss_transition", {
		resume_available = resume_available,
	})
	local notice_message = resolve_connection_loss_message(message, resume_available, opts)
	if MP.CONNECTION_SESSION and MP.CONNECTION_SESSION.set_client_connected then
		MP.CONNECTION_SESSION.set_client_connected(false)
	end
	if MP.CONNECTION_SESSION and MP.CONNECTION_SESSION.clear_local_lobby_session then
		MP.CONNECTION_SESSION.clear_local_lobby_session({
			clear_reconnect = true,
			clear_feedback = false,
			refresh_status = false,
		})
	end
	if not ((G and G.STAGES and G.STAGE == G.STAGES.MAIN_MENU or false)) then
		match_domain.reset_state()
		BALATRO.go_to_menu()
	end
	if MP.UI and MP.UI.UTILS and MP.UI.UTILS.overlay_message then
		MP.UI.UTILS.overlay_message(notice_message)
	end
end

-- ==========================================================================
-- Section 2: Match Action Senders (MP.ACTIONS)
-- ==========================================================================

local function get_blind_choice_internal()
	return MP.BLIND_CHOICE_INTERNAL or {}
end

local function request_match_lobby_info_refresh()
	if MP.UI and MP.UI.request_match_lobby_info_refresh then
		return MP.UI.request_match_lobby_info_refresh()
	end
	return false
end

local function get_current_blind()
	return G and G.GAME and G.GAME.blind or nil
end

local function get_current_blind_target()
	if MP.is_pvp_boss and MP.is_pvp_boss() and MP.UI and MP.UI.get_pvp_score_to_beat then
		local score_int, score_text = MP.UI.get_pvp_score_to_beat()
		if score_text and score_text ~= "" and score_text ~= "0" then
			return score_text
		elseif score_int and MP.INSANE_INT and MP.INSANE_INT.to_string then
			return MP.INSANE_INT.to_string(score_int)
		end
	end

	if teams_domain.get_cooperative_blind_target then
		local cooperative_target = teams_domain.get_cooperative_blind_target()
		if cooperative_target ~= nil then
			return cooperative_target
		end
	end

	local blind = get_current_blind()
	if blind and blind.mp_coop_scaled_chips ~= nil then
		return blind.mp_coop_scaled_chips
	end

	local target = (G and G.GAME and G.GAME.blind and G.GAME.blind.chips or nil)
	if target ~= nil then
		return target
	end

	if blind and blind.chips ~= nil then
		return blind.chips
	end

	return nil
end

local function send_end_game_summary_update()
	if not (MP.LOBBY and MP.LOBBY.code and MP.GAME) then
		return false
	end
	if MP.NETWORKING_INTERNAL and MP.NETWORKING_INTERNAL.send_end_game_summary_update then
		return MP.NETWORKING_INTERNAL.send_end_game_summary_update()
	end
	return false
end

local function send_end_game_summary_update_after_state_settles()
	if G and G.E_MANAGER and Event then
		G.E_MANAGER:add_event(Event({
			trigger = "after",
			delay = 0,
			func = function()
				send_end_game_summary_update()
				return true
			end,
		}))
		return true
	end
	return send_end_game_summary_update()
end

local function get_current_ante()
	return (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante or nil)
end

local function apply_local_pvp_timer_score_gate()
	if MP.apply_pvp_timer_score_gate then
		MP.apply_pvp_timer_score_gate()
	end
end

local function split_location(location)
	local location_text = tostring(location or "loc_selecting")
	local location_type, location_blind = location_text:match("^([^-]+)%-(.*)$")
	if location_type then
		return location_type, location_blind
	end
	return location_text, nil
end

local function normalize_location(location, blind)
	local location_type, location_blind = split_location(location)
	if
		location_blind == nil
		and (blind ~= nil or location_type == "loc_selecting" or location_type == "loc_playing" or location_type == "loc_shop")
	then
		local get_blind_to_display = MP.UTILS and MP.UTILS.get_blind_to_display or nil
		location_blind = get_blind_to_display and get_blind_to_display(blind) or blind
	end

	if location_blind ~= nil and location_blind ~= "" then
		return tostring(location_type) .. "-" .. tostring(location_blind)
	end
	return tostring(location_type)
end

local function get_starting_hands_for_ready_blind()
	local round_reset_hands = (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets["hands"] or nil)
	if round_reset_hands ~= nil then
		return round_reset_hands
	end

	return (G and G.GAME and G.GAME.current_round and G.GAME.current_round.hands_left or nil)
end

local function apply_ready_blind_runtime_modifiers(amount)
	local paperback = (G and G.GAME and G.GAME["paperback"] or nil)
	if paperback and paperback.blind_multiplier ~= nil then
		amount = amount * paperback.blind_multiplier
	end

	return amount
end

local function get_ready_blind_target(blind_row, blind_kind)
	if blind_kind == "pvp" then
		return nil
	end

	if (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.pvp_blind_choices and G.GAME.round_resets.pvp_blind_choices[blind_row] or nil) then
		return nil
	end

	local blind_key = (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_choices and G.GAME.round_resets.blind_choices[blind_row]) or nil
	local blind_def = blind_key and (G and G.P_BLINDS and G.P_BLINDS[blind_key]) or nil
	if not (blind_def and blind_def.mult) then
		return nil
	end

	local ante = (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets["blind_ante"] or nil)
	if ante == nil then
		ante = (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante or nil)
	end
	local blind_amount = BALATRO.get_blind_amount and BALATRO.get_blind_amount(ante) or nil
	if blind_amount == nil then
		return nil
	end

	local ante_scaling = (G and G.GAME and G.GAME.starting_params and G.GAME.starting_params.ante_scaling or nil) or 1
	local target = apply_ready_blind_runtime_modifiers(blind_amount * blind_def.mult * ante_scaling)
	if MP.is_coop_run and MP.is_coop_run() and MP.scale_coop_blind_amount then
		target = MP.scale_coop_blind_amount(target, ante, blind_def.mult)
	end
	return target
end

function match_action_runtime.start_game()
	if MP.is_lobby_match_in_progress and MP.is_lobby_match_in_progress() then
		MP.UI.UTILS.overlay_message("Waiting for match to finish.")
		return
	end

	Client.queue_send(MP.MATCH_WIRE.build_start_game_payload())
end

function match_action_runtime.ready_blind(e)
	local blind_choice = get_blind_choice_internal()
	local blind_row = blind_choice.get_blind_choice_row_type and blind_choice.get_blind_choice_row_type(e) or nil
	local blind_kind = blind_choice.get_blind_choice_row_kind and blind_choice.get_blind_choice_row_kind(e) or nil
	if match_domain.queue_next_blind_context then
		match_domain.queue_next_blind_context(e)
	end
	local payload = MP.MATCH_WIRE.build_ready_blind_payload(blind_row, blind_kind, {
		hands_left = get_starting_hands_for_ready_blind(),
		blind_target = get_ready_blind_target(blind_row, blind_kind),
	})
	if not payload then
		sendWarnMessage("Failed to resolve blind row or kind for readyBlind", "MULTIPLAYER")
		return
	end
	Client.queue_send(payload)
end

function match_action_runtime.blind_preview(preview_key, targets)
	local payload = MP.MATCH_WIRE.build_blind_preview_payload(preview_key, targets)
	if payload then
		Client.queue_send(payload)
	end
end

function match_action_runtime.coop_boss_blind(phase, ante, boss_key)
	local payload = MP.MATCH_WIRE.build_coop_boss_blind_payload(phase, ante, boss_key)
	if payload then
		Client.queue_send(payload)
	end
end

function match_action_runtime.unready_blind()
	if match_domain.clear_next_blind_context then
		match_domain.clear_next_blind_context()
	end
	Client.queue_send(MP.MATCH_WIRE.build_unready_blind_payload())
end

function match_action_runtime.ready_skip_blind(blind_row)
	Client.queue_send(MP.MATCH_WIRE.build_ready_skip_blind_payload(blind_row, get_current_ante()))
end

function match_action_runtime.unready_skip_blind()
	Client.queue_send(MP.MATCH_WIRE.build_unready_skip_blind_payload())
end

function match_action_runtime.fail_round(hands_used)
	if MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.no_gold_on_round_loss and BALATRO.set_current_blind_dollars then
		BALATRO.set_current_blind_dollars(0)
	end
	-- Live spectation: the simulated run already failed locally (chips <
	-- blind). Arm comeback the same way a real life packet would, then let
	-- vanilla evaluate_round add the row. Do not send fail_round or stamp
	-- the target's network result.
	if MP.SPECTATOR and MP.SPECTATOR.is_spectating then
		local death_on_loss = MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.death_on_round_loss
		if death_on_loss == nil then death_on_loss = true end
		local gold_on_loss = MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.gold_on_life_loss
		if gold_on_loss == nil then gold_on_loss = true end
		local not_pvp = not (MP.is_pvp_boss and MP.is_pvp_boss())
		if not_pvp and MP.GAME and not MP.GAME.round_loss_processed then
			MP.GAME.round_loss_processed = true
			local prev = tonumber(MP.GAME.lives) or 1
			if death_on_loss and MP.GAME.lives then
				local new_lives = math.max(0, prev - 1)
				MP.GAME.lives = new_lives
				MP.GAME.team_lives = new_lives
				if prev > 0 and MP.UI and MP.UI.ease_lives then
					MP.UI.ease_lives(-1)
				end
			end
			if death_on_loss and gold_on_loss and prev > 0 then
				MP.GAME.comeback_bonus_given = false
				MP.GAME.comeback_eval_pending = true
				MP.GAME.comeback_bonus = (tonumber(MP.GAME.comeback_bonus) or 0) + 1
			end
		end
		return
	end
	if hands_used == 0 then
		return
	end
	Client.queue_send(MP.MATCH_WIRE.build_fail_round_payload())
end

function match_action_runtime.version()
	local client_version = MP.RUNTIME_POLICY and MP.RUNTIME_POLICY.client and MP.RUNTIME_POLICY.client.version or MP.version or ""
	Client.queue_send(MP.MATCH_WIRE.build_version_payload(client_version))
end

function match_action_runtime.set_location(location, blind)
	location = normalize_location(location, blind)
	if match_domain.set_location and not match_domain.set_location(location) then
		return
	end
	if MP.SPECTATOR and MP.SPECTATOR.is_spectating then
		return
	end
	request_match_lobby_info_refresh()
	Client.queue_send(MP.MATCH_WIRE.build_set_location_payload(location))
end

function match_action_runtime.play_hand(score, hands_left, options)
	options = options or {}
	local blind_target = options.blind_target
	if blind_target == nil then
		blind_target = get_current_blind_target()
	end
	local payload, fixed_score = MP.MATCH_WIRE.build_play_hand_payload(score, hands_left, {
		blind_target = blind_target,
	})
	local insane_int_score = MP.INSANE_INT.from_string(fixed_score)
	if match_domain.apply_local_hand_score then
		match_domain.apply_local_hand_score(fixed_score, insane_int_score, hands_left)
	end
	send_end_game_summary_update_after_state_settles()
	if MP.GAME and MP.GAME.score_display then
		if MP.INSANE_INT and MP.INSANE_INT.copy_into then
			MP.INSANE_INT.copy_into(MP.GAME.score_display, insane_int_score)
		else
			MP.GAME.score_display = insane_int_score
		end
	end
	if teams_domain.recalculate_state then
		teams_domain.recalculate_state()
	end
	request_match_lobby_info_refresh()
	if MP.UI and MP.UI.refresh_active_pvp_player_list then
		MP.UI.refresh_active_pvp_player_list()
	end
	apply_local_pvp_timer_score_gate()
	if MP.SPECTATOR and MP.SPECTATOR.is_spectating then
		return
	end
	Client.queue_send(payload)
end

function match_action_runtime.set_ante(ante)
	send_end_game_summary_update_after_state_settles()
	Client.queue_send(MP.MATCH_WIRE.build_set_ante_payload(ante))
end

function match_action_runtime.new_round()
	if match_domain.begin_new_round then
		match_domain.begin_new_round()
	end
	if MP.SPECTATOR and MP.SPECTATOR.is_spectating then
		return
	end
	Client.queue_send(MP.MATCH_WIRE.build_new_round_payload())
end

function match_action_runtime.set_furthest_blind(furthest_blind)
	Client.queue_send(MP.MATCH_WIRE.build_set_furthest_blind_payload(furthest_blind))
end

function match_action_runtime.skip(skips)
	Client.queue_send(MP.MATCH_WIRE.build_skip_payload(skips))
end

function match_action_runtime.start_ante_timer()
	trace_runtime_event("ante_timer.start_requested", {
		ready_blind_kind = MP.GAME and MP.GAME.ready_blind_kind,
		time = MP.GAME and MP.GAME.timer,
	})
	local is_local_timer = MP.timer_is_local and MP.timer_is_local() or false
	if is_local_timer and MP.ANTE_TIMER_RUNTIME and MP.ANTE_TIMER_RUNTIME.apply_local_signal then
		MP.ANTE_TIMER_RUNTIME.apply_local_signal(true, true, true)
	end
	Client.queue_send(MP.MATCH_WIRE.build_timer_payload("startAnteTimer", MP.GAME and MP.GAME.timer, is_local_timer))
end

function match_action_runtime.pause_ante_timer()
	trace_runtime_event("ante_timer.pause_requested", {
		ready_blind_kind = MP.GAME and MP.GAME.ready_blind_kind,
		time = MP.GAME and MP.GAME.timer,
	})
	local is_local_timer = MP.timer_is_local and MP.timer_is_local() or false
	if is_local_timer and MP.ANTE_TIMER_RUNTIME and MP.ANTE_TIMER_RUNTIME.apply_local_signal then
		MP.ANTE_TIMER_RUNTIME.apply_local_signal(false, true, false)
	end
	Client.queue_send(MP.MATCH_WIRE.build_timer_payload("pauseAnteTimer", MP.GAME and MP.GAME.timer, is_local_timer))
end

function match_action_runtime.fail_timer()
	trace_runtime_event("timer.fail_requested", {
		ruleset = MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.ruleset,
		time = MP.GAME and MP.GAME.timer,
	})
	Client.queue_send(MP.MATCH_WIRE.build_fail_timer_payload())
end

function match_action_runtime.fail_pvp_timer()
	if MP.SPECTATOR and MP.SPECTATOR.is_spectating then
		return
	end
	trace_runtime_event("pvp_timer.fail_requested", {
		ruleset = MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.ruleset,
		time = MP.GAME and MP.GAME.timer,
	})
	Client.queue_send(MP.MATCH_WIRE.build_fail_pvp_timer_payload())
end

function match_action_runtime.sync_client()
	Client.queue_send(MP.MATCH_WIRE.build_sync_client_payload(_RELEASE_MODE))
end

function match_action_runtime.sync_money(money)
	if MP.uses_shared_sync_group() and not MP.is_shared_money_sync_enabled() then
		trace_runtime_event("team_money.sync_blocked", {
			reason = "disabled",
			money = money,
		})
		return false
	end

	if not MP.LOBBY.code then
		trace_runtime_event("team_money.sync_blocked", {
			reason = "no_lobby",
			money = money,
		})
		return false
	end

	local payload = MP.MATCH_WIRE.build_sync_money_payload(money)
	if not payload then
		sendWarnMessage("Failed to build syncMoney payload.", "MULTIPLAYER")
		return false
	end

	local queued = Client.queue_send(payload)
	trace_runtime_event("team_money.sync_send", {
		money = money,
		queued = queued,
	})
	return queued
end

function match_action_runtime.send_team_money(target_player_id, amount)
	if not MP.uses_shared_sync_group() then
		trace_runtime_event("team_money.send_blocked", {
			reason = "not_shared_sync_group",
			target_player_id = target_player_id,
			amount = amount,
		})
		return false
	end

	if not MP.is_shared_money_sync_enabled() then
		trace_runtime_event("team_money.send_blocked", {
			reason = "disabled",
			target_player_id = target_player_id,
			amount = amount,
		})
		sendWarnMessage("Failed to send team money: money sharing is disabled.", "MULTIPLAYER")
		return false
	end

	if type(target_player_id) ~= "string" or target_player_id == "" then
		trace_runtime_event("team_money.send_blocked", {
			reason = "missing_target",
			amount = amount,
		})
		sendWarnMessage("Failed to send team money: missing target player.", "MULTIPLAYER")
		return false
	end

	local transfer_amount = MP.MATCH_WIRE.normalize_currency_amount(amount)
	if transfer_amount < 1 then
		trace_runtime_event("team_money.send_blocked", {
			reason = "invalid_amount",
			target_player_id = target_player_id,
			amount = amount,
		})
		sendWarnMessage("Failed to send team money: amount must be at least $1.", "MULTIPLAYER")
		return false
	end

	local local_money = MP.get_local_money and MP.get_local_money() or 0
	local available_money = MP.MATCH_WIRE.normalize_money_balance(local_money)
	if available_money < transfer_amount then
		trace_runtime_event("team_money.send_blocked", {
			reason = "local_money_below_amount",
			target_player_id = target_player_id,
			amount = transfer_amount,
			local_money = available_money,
		})
		sendWarnMessage("Failed to send team money: not enough money.", "MULTIPLAYER")
		return false
	end

	local payload = MP.MATCH_WIRE.build_send_team_money_payload(target_player_id, transfer_amount, available_money)
	if not payload then
		trace_runtime_event("team_money.send_blocked", {
			reason = "payload_failed",
			target_player_id = target_player_id,
			amount = transfer_amount,
		})
		sendWarnMessage("Failed to build sendTeamMoney payload.", "MULTIPLAYER")
		return false
	end

	local queued = Client.queue_send(payload)
	trace_runtime_event("team_money.send", {
		target_player_id = target_player_id,
		amount = transfer_amount,
		local_money = available_money,
		queued = queued,
	})
	return queued
end

MP.ACTIONS.start_game = match_action_runtime.start_game
MP.ACTIONS.ready_blind = match_action_runtime.ready_blind
MP.ACTIONS.blind_preview = match_action_runtime.blind_preview
MP.ACTIONS.coop_boss_blind = match_action_runtime.coop_boss_blind
MP.ACTIONS.unready_blind = match_action_runtime.unready_blind
MP.ACTIONS.ready_skip_blind = match_action_runtime.ready_skip_blind
MP.ACTIONS.unready_skip_blind = match_action_runtime.unready_skip_blind
MP.ACTIONS.fail_round = match_action_runtime.fail_round
MP.ACTIONS.version = match_action_runtime.version
MP.ACTIONS.set_location = match_action_runtime.set_location
MP.ACTIONS.play_hand = match_action_runtime.play_hand
MP.ACTIONS.set_ante = match_action_runtime.set_ante
MP.ACTIONS.new_round = match_action_runtime.new_round
MP.ACTIONS.set_furthest_blind = match_action_runtime.set_furthest_blind
MP.ACTIONS.skip = match_action_runtime.skip
MP.ACTIONS.start_ante_timer = match_action_runtime.start_ante_timer
MP.ACTIONS.pause_ante_timer = match_action_runtime.pause_ante_timer
MP.ACTIONS.fail_timer = match_action_runtime.fail_timer
MP.ACTIONS.fail_pvp_timer = match_action_runtime.fail_pvp_timer
MP.ACTIONS.sync_client = match_action_runtime.sync_client
MP.ACTIONS.sync_money = match_action_runtime.sync_money
MP.ACTIONS.send_team_money = match_action_runtime.send_team_money

-- ==========================================================================
-- Section 3: Match Flow Runtime (Internal orchestration)
-- ==========================================================================

local function get_blind_choice_internal()
	return MP.BLIND_CHOICE_INTERNAL or {}
end

local function get_match_timer_start_time(timer_kind)
	if MP.ANTE_TIMER_RUNTIME and MP.ANTE_TIMER_RUNTIME.get_match_start_time then
		return MP.ANTE_TIMER_RUNTIME.get_match_start_time(timer_kind)
	end

	return MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.timer_base_seconds
end

local function begin_pvp_blind()
	if MP.GAME.next_blind_context then
		BALATRO.select_blind(MP.GAME.next_blind_context)
	else
		sendErrorMessage("No next blind context", "MULTIPLAYER")
	end
end

local function parse_server_blind_target(blind_target)
	if blind_target == nil then
		return nil
	end

	local numeric_target = nil
	if BALATRO.to_score_number then
		numeric_target = BALATRO.to_score_number(blind_target)
	else
		numeric_target = tonumber(blind_target)
	end
	if numeric_target ~= nil then
		return numeric_target
	end

	local target_text = tostring(blind_target or "")
	if target_text == "" then
		return nil
	end

	if type(to_big) == "function" then
		local ok, target = pcall(to_big, target_text)
		if ok and target ~= nil then
			local numeric_target = BALATRO.to_score_number and BALATRO.to_score_number(target) or nil
			if numeric_target ~= nil then
				return numeric_target
			end
			if type(target) ~= "string" then
				return target
			end
		end
	end

	return nil
end

local function set_server_coop_blind_target(blind_target)
	if not MP.GAME then
		return
	end

	local target = parse_server_blind_target(blind_target)
	MP.GAME.coop_blind_server_target_chips = target
	MP.GAME.coop_blind_target_chips = target
	if target == nil then
		return
	end

	local blind = ((G and G.GAME and G.GAME.blind))
		or (G and G.GAME and G.GAME.blind)
		or nil
	if not blind then
		return
	end

	blind.mp_coop_scaled_chips = target
	local chip_text = number_format(target)
	if BALATRO.set_current_blind_score then
		BALATRO.set_current_blind_score(target, chip_text)
	else
		blind.chips = target
		blind.chip_text = chip_text
	end
end

local function sync_local_blind_target_scale()
	if not (MP.ACTIONS and MP.ACTIONS.sync_blind_target_scale) then
		return
	end

	local scale = (G and G.GAME and G.GAME.starting_params and G.GAME.starting_params.ante_scaling or nil) or 1
	local paperback = (G and G.GAME and G.GAME["paperback"] or nil)
	if paperback and paperback.blind_multiplier ~= nil then
		scale = scale * paperback.blind_multiplier
	end
	MP.ACTIONS.sync_blind_target_scale(scale)
end

local function sync_initial_shared_playing_cards()
	if not (MP.LOBBY and MP.LOBBY.is_host) then
		return
	end
	if not (MP.is_shared_card_sync_enabled and MP.is_shared_card_sync_enabled()) then
		return
	end

	local team_card_sync = MP.SYNC and MP.SYNC.TEAM_CARD or nil
	if not (team_card_sync and team_card_sync.sync_full_deck) then
		return
	end

	local function sync_full_deck()
		team_card_sync.sync_full_deck()
		return true
	end

	if BALATRO.queue_event then
		BALATRO.queue_event({
			trigger = "after",
			delay = 0.35,
			func = sync_full_deck,
		})
	else
		sync_full_deck()
	end
end

function match_flow_runtime.sync_resume_enemies_from_lobby()
	MP.STATE_APPLY.sync_resume_enemies_from_lobby()
end

local function apply_shared_start_deck(stake_str, deck_state)
	if not (MP.LOBBY and MP.LOBBY.config) or MP.LOBBY.config.different_decks then
		return
	end

	deck_state = type(deck_state) == "table" and deck_state or {}
	local update = {
		back = deck_state.back,
		stake = stake_str,
		challenge = deck_state.challenge,
		sleeve = deck_state.sleeve,
		cocktail = deck_state.cocktail,
	}

	if lobby_domain.apply_option_update then
		lobby_domain.apply_option_update(update)
	elseif lobby_domain.update_run_deck then
		lobby_domain.update_run_deck(update)
	end
end

function match_flow_runtime.start_match_runtime(seed, stake_str, deck_state)
	MP.MATCH_LIFECYCLE.begin_match_runtime()

	apply_shared_start_deck(stake_str, deck_state)
	local stake = tonumber(stake_str)
	MP.ACTIONS.set_ante(0)
	if not MP.LOBBY.config.different_seeds and MP.LOBBY.config.custom_seed ~= "random" then
		seed = MP.LOBBY.config.custom_seed
	end
	if not (MP.SPECTATOR and (MP.SPECTATOR.is_spectator_role or MP.SPECTATOR.is_spectating)) then
		if MP.RECORDER and MP.RECORDER.reset then
			MP.RECORDER.reset()
		end
	end
	BALATRO.start_lobby_run({ seed = seed, stake = stake })

	if MP.SPECTATOR and MP.SPECTATOR.is_spectator_role then
		return
	end
	sync_initial_shared_playing_cards()
	sync_local_blind_target_scale()
	if MP.LOBBY.config.ruleset == "ruleset_mp_speedlatro" then
		MP.ANTE_TIMER_RUNTIME.reset_for_ante(get_match_timer_start_time())
		MP.ACTIONS.start_ante_timer()
	end
	if teams_domain.recalculate_state then
		teams_domain.recalculate_state()
	end
	MP.MATCH_LIFECYCLE.request_resume_snapshot()
end

function match_flow_runtime.resume_match_runtime(saved_run_snapshot, saved_match_state)
	local current_step = "validate saved run snapshot"
	local ok, err = xpcall(function()
		if type(saved_run_snapshot) ~= "table" then
			error("Missing saved multiplayer run snapshot.")
		end

		current_step = "enable multiplayer match runtime"
		MP.MATCH_LIFECYCLE.prepare_resume_runtime()

		current_step = "repair saved run snapshot"
		if MP.RESUME and MP.RESUME.repair_saved_run_snapshot then
			MP.RESUME.repair_saved_run_snapshot(saved_run_snapshot)
		end

		current_step = "queue multiplayer restore state"
		if MP.RESUME and MP.RESUME.queue_runtime_resume then
			MP.RESUME.queue_runtime_resume(saved_match_state)
		end

		current_step = "start run via vanilla continue flow"
		if G and G.SETTINGS then
			G.SETTINGS.current_setup = "Continue"
		end
		BALATRO.start_run({ savetext = saved_run_snapshot, mp_resume = true })
	end, function(resume_err)
		local summary = string.format(
			"Resume runtime failed at step '%s': %s",
			tostring(current_step),
			tostring(resume_err)
		)
		return build_traceback(summary)
	end)

	if not ok then
		error(err)
	end
end

function match_flow_runtime.start_match_blind_runtime(blind_row, blind_kind, duel_role, blind_target)
	local blind_choice = get_blind_choice_internal()
	local ready_blind_kind = blind_kind or (blind_choice.get_match_ready_blind_kind and blind_choice.get_match_ready_blind_kind() or nil)
	local is_pvp_blind = ready_blind_kind == "pvp"

	if match_domain.set_duel_blind_role then
		match_domain.set_duel_blind_role(duel_role)
	end
	MP.MATCH_LIFECYCLE.reset_local_blind_ready_runtime()
	if blind_choice.clear_skip_ready_state then
		blind_choice.clear_skip_ready_state()
	end
	if match_domain.clear_next_blind_context then
		match_domain.clear_next_blind_context()
	end
	set_server_coop_blind_target(is_pvp_blind and nil or blind_target)

	if is_pvp_blind then
		MP.ANTE_TIMER_RUNTIME.reset_for_ante(get_match_timer_start_time("pvp"))
	end
	begin_pvp_blind()

	if MP.UI and MP.UI.refresh_timer_hud_binding then
		MP.UI.refresh_timer_hud_binding()
	end
end

function match_flow_runtime.handle_team_skip_blind_runtime(blind_row, ante)
	local is_cooperative_skip_mode = MP.is_teams_mode()
		or (MP.is_coop_lobby_type and MP.is_coop_lobby_type())
	if not is_cooperative_skip_mode or not MP.LOBBY or not MP.LOBBY.code then
		return
	end
	if blind_row ~= "Small" and blind_row ~= "Big" then
		return
	end
	local blind_choice = get_blind_choice_internal()
	if blind_choice.perform_team_skip then
		blind_choice.perform_team_skip(blind_row, ante)
	end
end

local function refresh_player_list_before_terminal_outcome()
	if MP.UI and MP.UI.refresh_player_list then
		MP.UI.refresh_player_list()
	end
end

local function prepare_terminal_match_outcome()
	refresh_player_list_before_terminal_outcome()
	MP.MATCH_LIFECYCLE.prepare_end_game_view()
	MP.MATCH_LIFECYCLE.clear_saved_resume()
end

local function log_terminal_match_memory()
	if MP.UTILS and MP.UTILS.log_mem_debug_messages then
		MP.UTILS.log_mem_debug_messages()
	end
end

local function is_loss_overlay_visible()
	local overlay = (G and G.OVERLAY_MENU) or nil
	return not not (
		overlay
		and overlay.is_mp_end_game_overlay
		and overlay.mp_end_game_result == "loss"
	)
end

local function trigger_pvp_timer_loss_context()
	if not (G and G.GAME and G.GAME.current_round) then
		return false
	end
	local hands_left = tonumber(G.GAME.current_round.hands_left) or 0
	if hands_left <= 0 then
		return false
	end

	if type(stop_use) == "function" then
		stop_use()
	end
	if SMODS and SMODS.calculate_context then
		SMODS.calculate_context({ mp_pvp_loss = true, mp_hands_left = hands_left })
		return true
	end
	return false
end
MP.trigger_pvp_timer_loss_context = trigger_pvp_timer_loss_context

function match_flow_runtime.end_current_pvp_runtime(lost, pvp_timer_lost)
	if lost and pvp_timer_lost then
		trigger_pvp_timer_loss_context()
	end
	set_server_coop_blind_target(nil)
	if match_domain.mark_end_pvp then
		match_domain.mark_end_pvp()
	end
	if MP.release_cooperative_deck_out_resolution then
		MP.release_cooperative_deck_out_resolution()
	end
	if MP.is_pvp_boss and MP.is_pvp_boss() then
		MP.ANTE_TIMER_RUNTIME.reset_for_ante(get_match_timer_start_time("ante"))
	end
	local blind_choice = get_blind_choice_internal()
	if blind_choice.clear_skip_ready_state then
		blind_choice.clear_skip_ready_state()
	end
	if MP.UI and MP.UI.refresh_timer_hud_binding then
		MP.UI.refresh_timer_hud_binding()
	end
	if MP.RECORDER and MP.RECORDER.is_recording and not (MP.SPECTATOR and MP.SPECTATOR.is_spectating) then
		MP.RECORDER.record_end_pvp(lost, pvp_timer_lost)
	end
end

function match_flow_runtime.end_current_coop_blind_runtime(lost)
	set_server_coop_blind_target(nil)
	if match_domain.mark_end_coop_blind then
		match_domain.mark_end_coop_blind(lost)
	elseif match_domain.mark_end_pvp then
		match_domain.mark_end_pvp()
	end
	if MP.release_cooperative_deck_out_resolution then
		MP.release_cooperative_deck_out_resolution()
	end
	if MP.RECORDER and MP.RECORDER.is_recording and not (MP.SPECTATOR and MP.SPECTATOR.is_spectating) then
		MP.RECORDER.record_end_pvp(lost, false)
	end
	local blind_choice = get_blind_choice_internal()
	if blind_choice.clear_skip_ready_state then
		blind_choice.clear_skip_ready_state()
	end
	if MP.UI and MP.UI.refresh_timer_hud_binding then
		MP.UI.refresh_timer_hud_binding()
	end
end

function match_flow_runtime.handle_match_win_runtime()
	local states = (G and G.STATES) or nil
	if (states and (G and G.STATE) == states.GAME_WIN) or MP.GAME.won then
		return
	end
	prepare_terminal_match_outcome()
	if match_domain.mark_match_won then
		match_domain.mark_match_won()
	end
	log_terminal_match_memory()
	win_game()
end

function match_flow_runtime.handle_match_alone_runtime()
	if MP.GAME and MP.GAME.won then
		return
	end

	prepare_terminal_match_outcome()
	if match_domain.mark_match_abandoned then
		match_domain.mark_match_abandoned()
	elseif match_domain.mark_match_alone then
		match_domain.mark_match_alone()
	end
	log_terminal_match_memory()
	BALATRO.set_paused(true)
	BALATRO.call_ui_function("overlay_endgame_menu")
end

function match_flow_runtime.handle_match_loss_runtime()
	if (MP.SPECTATOR and MP.SPECTATOR.is_spectating) or is_loss_overlay_visible() then
		return
	end

	local states = (G and G.STATES) or nil
	local is_new_loss = true

	prepare_terminal_match_outcome()
	if match_domain.mark_match_lost then
		is_new_loss = match_domain.mark_match_lost()
	elseif MP.GAME then
		is_new_loss = MP.GAME.end_game_result ~= "loss"
		MP.GAME.won = false
		MP.GAME.end_game_result = "loss"
	end
	if is_new_loss then
		log_terminal_match_memory()
	end
	G.STATE_COMPLETE = false
	if states then
		G.STATE = states.GAME_OVER
	end
	BALATRO.set_paused(true)
	BALATRO.call_ui_function("overlay_endgame_menu")
end

-- Spectator: the watched match finished. Leave the board and show the
-- endgame overlay. Abandoned only if a contestant disconnected.
function match_flow_runtime.handle_match_ended_runtime()
	prepare_terminal_match_outcome()
	local left = false
	for _, player in ipairs((MP.LOBBY and MP.LOBBY.players) or {}) do
		if player and player.is_disconnected and not player.is_spectator and player.role ~= "spectator" then
			left = true
			break
		end
	end
	if MP.GAME then
		MP.GAME.won = false
		MP.GAME.end_game_result = left and "abandoned" or "ended"
	end
	log_terminal_match_memory()
	BALATRO.set_paused(true)
	BALATRO.call_ui_function("overlay_endgame_menu")
end

MP.NETWORKING_INTERNAL.sync_resume_enemies_from_lobby = match_flow_runtime.sync_resume_enemies_from_lobby
MP.NETWORKING_INTERNAL.start_match_runtime = match_flow_runtime.start_match_runtime
MP.NETWORKING_INTERNAL.resume_match_runtime = match_flow_runtime.resume_match_runtime
MP.NETWORKING_INTERNAL.start_match_blind_runtime = match_flow_runtime.start_match_blind_runtime
MP.NETWORKING_INTERNAL.handle_team_skip_blind_runtime = match_flow_runtime.handle_team_skip_blind_runtime
MP.NETWORKING_INTERNAL.end_current_pvp_runtime = match_flow_runtime.end_current_pvp_runtime
MP.NETWORKING_INTERNAL.end_current_coop_blind_runtime = match_flow_runtime.end_current_coop_blind_runtime
MP.NETWORKING_INTERNAL.handle_match_win_runtime = match_flow_runtime.handle_match_win_runtime
MP.NETWORKING_INTERNAL.handle_match_alone_runtime = match_flow_runtime.handle_match_alone_runtime
MP.NETWORKING_INTERNAL.handle_match_loss_runtime = match_flow_runtime.handle_match_loss_runtime
MP.NETWORKING_INTERNAL.handle_match_ended_runtime = match_flow_runtime.handle_match_ended_runtime



-- ==========================================================================
-- Section 4: Match Message Handlers (Incoming network events)
-- ==========================================================================

local function ensure_match_flow_runtime()
	return match_flow_runtime
end

local function ensure_state_apply_runtime(required_method)
	return load_required_service(
		"multiplayer/runtime/network_state_apply.lua",
		required_method,
		"Multiplayer state apply runtime service is missing.",
		function()
			return MP.STATE_APPLY
		end
	)
end

local function buffer_resume_method(method_name, ...)
	local method = MP.RESUME and MP.RESUME[method_name] or nil
	return method and method(...)
end


local function call_match_flow_runtime(method_name, ...)
	local match_flow_runtime = ensure_match_flow_runtime()
	local method = match_flow_runtime and match_flow_runtime[method_name] or nil
	if method then
		return method(...)
	end

	return nil
end

local function apply_state_update(method_name, ...)
	local state_apply = ensure_state_apply_runtime(method_name)
	local method = state_apply and state_apply[method_name] or nil
	if method then
		return method(...)
	end

	return nil
end

function match_message_runtime.handle_start_game(seed, stake_str, back, challenge, sleeve, cocktail)
	call_match_flow_runtime("start_match_runtime", seed, stake_str, {
		back = back,
		challenge = challenge,
		sleeve = sleeve,
		cocktail = cocktail,
	})
end

function match_message_runtime.handle_start_blind(blind_row, blind_kind, duel_role, blind_target)
	call_match_flow_runtime("start_match_blind_runtime", blind_row, blind_kind, duel_role, blind_target)
end

function match_message_runtime.handle_team_skip_blind(blind_row, ante)
	call_match_flow_runtime("handle_team_skip_blind_runtime", blind_row, ante)
end

function match_message_runtime.handle_end_pvp(lost, pvp_timer_lost)
	-- Spectators are not on the resume-buffer path. Applying endPvP here is
	-- how they learn the round is over, same as a live player.
	if not (MP.SPECTATOR and MP.SPECTATOR.is_spectating) then
		if buffer_resume_method("buffer_runtime_match_outcome", "endPvP", lost, pvp_timer_lost) then
			return
		end
	end

	call_match_flow_runtime("end_current_pvp_runtime", lost, pvp_timer_lost)
end

function match_message_runtime.handle_end_coop_blind(lost)
	if buffer_resume_method("buffer_runtime_match_outcome", "endCoopBlind", lost) then
		return
	end

	call_match_flow_runtime("end_current_coop_blind_runtime", lost)
end

function match_message_runtime.handle_player_info(lives, life_loss_reason, previous_lives, team)
	if buffer_resume_method("buffer_runtime_player_info", lives, life_loss_reason, previous_lives, team) then
		return
	end

	apply_state_update("player_info", lives, life_loss_reason, previous_lives, team)
end

function match_message_runtime.handle_money_update(money, delta, source_player_id)
	trace_runtime_event("team_money.update_received", {
		money = money,
		delta = delta,
		source_player_id = source_player_id,
	})

	if buffer_resume_method("buffer_runtime_money_update", money, delta, source_player_id) then
		trace_runtime_event("team_money.update_buffered_for_resume", {
			money = money,
			delta = delta,
			source_player_id = source_player_id,
		})
		return
	end

	trace_runtime_event("team_money.update_dispatch_apply", {
		money = money,
		delta = delta,
		source_player_id = source_player_id,
	})
	apply_state_update("money_update", money, delta, source_player_id)
end

function match_message_runtime.handle_win_game()
	if buffer_resume_method("buffer_runtime_match_outcome", "winGame") then
		return
	end

	if MP.COOP_SAVE and MP.COOP_SAVE.consume_active_resumed_save then
		MP.COOP_SAVE.consume_active_resumed_save()
	end
	call_match_flow_runtime("handle_match_win_runtime")
end

function match_message_runtime.handle_alone_game()
	if buffer_resume_method("buffer_runtime_match_outcome", "aloneGame") then
		return
	end

	if MP.COOP_SAVE and MP.COOP_SAVE.consume_active_resumed_save then
		MP.COOP_SAVE.consume_active_resumed_save()
	end
	call_match_flow_runtime("handle_match_alone_runtime")
end

function match_message_runtime.handle_lose_game()
	if buffer_resume_method("buffer_runtime_match_outcome", "loseGame") then
		return
	end

	if MP.COOP_SAVE and MP.COOP_SAVE.consume_active_resumed_save then
		MP.COOP_SAVE.consume_active_resumed_save()
	end
	call_match_flow_runtime("handle_match_loss_runtime")
end

-- The watched match finished (spectators only).
function match_message_runtime.handle_match_ended()
	if MP.SPECTATOR and MP.SPECTATOR.handle_match_ended then
		MP.SPECTATOR.handle_match_ended()
	end
end

function match_message_runtime.handle_enemy_info(enemy_info)
	if buffer_resume_method("buffer_runtime_enemy_info", enemy_info) then
		return
	end

	apply_state_update("enemy_info", enemy_info)
end

function match_message_runtime.handle_enemy_location(options)
	if buffer_resume_method("buffer_runtime_enemy_location", options) then
		return
	end

	apply_state_update("enemy_location", options)
end

function match_message_runtime.handle_coop_blind_preview(preview_key, targets)
	local blind_choice_state = MP.UI and MP.UI.BLIND_CHOICE_STATE or nil
	if blind_choice_state and blind_choice_state.handle_coop_blind_preview then
		blind_choice_state.handle_coop_blind_preview(preview_key, targets)
	end
end

function match_message_runtime.handle_coop_boss_blind(phase, ante, revision, source_player_id, boss_key, is_reroll)
	if MP.COOP_BOSS_BLIND and MP.COOP_BOSS_BLIND.handle_server_update then
		MP.COOP_BOSS_BLIND.handle_server_update({
			phase = phase,
			ante = ante,
			revision = revision,
			source_player_id = source_player_id,
			boss_key = boss_key,
			is_reroll = is_reroll,
		})
	end
end

MP.NETWORKING_INTERNAL.handle_start_game = match_message_runtime.handle_start_game
MP.NETWORKING_INTERNAL.handle_start_blind = match_message_runtime.handle_start_blind
MP.NETWORKING_INTERNAL.handle_team_skip_blind = match_message_runtime.handle_team_skip_blind
MP.NETWORKING_INTERNAL.handle_end_pvp = match_message_runtime.handle_end_pvp
MP.NETWORKING_INTERNAL.handle_end_coop_blind = match_message_runtime.handle_end_coop_blind
MP.NETWORKING_INTERNAL.handle_player_info = match_message_runtime.handle_player_info
MP.NETWORKING_INTERNAL.handle_money_update = match_message_runtime.handle_money_update
MP.NETWORKING_INTERNAL.handle_win_game = match_message_runtime.handle_win_game
MP.NETWORKING_INTERNAL.handle_alone_game = match_message_runtime.handle_alone_game
MP.NETWORKING_INTERNAL.handle_lose_game = match_message_runtime.handle_lose_game
MP.NETWORKING_INTERNAL.handle_match_ended = match_message_runtime.handle_match_ended
MP.NETWORKING_INTERNAL.handle_enemy_info = match_message_runtime.handle_enemy_info
MP.NETWORKING_INTERNAL.handle_enemy_location = match_message_runtime.handle_enemy_location
MP.NETWORKING_INTERNAL.handle_coop_blind_preview = match_message_runtime.handle_coop_blind_preview
MP.NETWORKING_INTERNAL.handle_coop_boss_blind = match_message_runtime.handle_coop_boss_blind

return match_flow_runtime
