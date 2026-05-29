MP.ACTIONS = MP.ACTIONS or {}

local match_action_runtime = {}

local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end

local function request_match_lobby_info_refresh()
	if MP.request_match_lobby_info_refresh then
		MP.request_match_lobby_info_refresh()
	end
end

function match_action_runtime.start_game()
	if MP.is_lobby_match_in_progress and MP.is_lobby_match_in_progress() then
		MP.UI.UTILS.overlay_message("Waiting for match to finish.")
		return
	end

	Client.queue_send(MP.MATCH_WIRE.build_start_game_payload())
end

function match_action_runtime.ready_blind(e)
	local blind_kind = MP.get_blind_choice_row_kind and MP.get_blind_choice_row_kind(e) or nil
	if MP.queue_match_next_blind_context then
		MP.queue_match_next_blind_context(
			e,
			blind_kind ~= nil and blind_kind ~= "pvp"
		)
	end
	local payload = MP.MATCH_WIRE.build_ready_blind_payload(e)
	if not payload then
		sendWarnMessage("Failed to resolve blind row or kind for readyBlind", "MULTIPLAYER")
		return
	end
	Client.queue_send(payload)
end

function match_action_runtime.unready_blind()
	if MP.clear_match_next_blind_context then
		MP.clear_match_next_blind_context()
	end
	Client.queue_send(MP.MATCH_WIRE.build_unready_blind_payload())
end

function match_action_runtime.ready_skip_blind(blind_row)
	Client.queue_send(MP.MATCH_WIRE.build_ready_skip_blind_payload(blind_row))
end

function match_action_runtime.unready_skip_blind()
	Client.queue_send(MP.MATCH_WIRE.build_unready_skip_blind_payload())
end

function match_action_runtime.fail_round(hands_used)
	if MP.LOBBY.config.no_gold_on_round_loss then
		G.GAME.blind.dollars = 0
	end
	if hands_used == 0 then
		return
	end
	Client.queue_send(MP.MATCH_WIRE.build_fail_round_payload())
end

function match_action_runtime.version()
	Client.queue_send(MP.MATCH_WIRE.build_version_payload(MP.CLIENT_VERSION or MP.version or ""))
end

function match_action_runtime.set_location(location)
	if MP.set_match_location and not MP.set_match_location(location) then
		return
	end
	request_match_lobby_info_refresh()
	Client.queue_send(MP.MATCH_WIRE.build_set_location_payload(location))
end

function match_action_runtime.play_hand(score, hands_left)
	local payload, fixed_score = MP.MATCH_WIRE.build_play_hand_payload(score, hands_left)
	local insane_int_score = MP.INSANE_INT.from_string(fixed_score)
	if MP.apply_local_match_hand_score then
		MP.apply_local_match_hand_score(fixed_score, insane_int_score)
	end
	local score_shared = MP.UI and MP.UI.PLAYERS_HUD_SHARED or nil
	if MP.GAME and MP.GAME.score_display and score_shared and score_shared.ease_standings_score_number then
		score_shared.ease_standings_score_number(MP.GAME.score_display, insane_int_score, {
			delay = score_shared.PVP_SCORE_EASE_DELAY,
		})
	end
	MP.recalculate_team_state()
	request_match_lobby_info_refresh()
	Client.queue_send(payload)
	if MP.UI and MP.UI.refresh_active_pvp_player_list then
		MP.UI.refresh_active_pvp_player_list()
	end
end

function match_action_runtime.set_ante(ante)
	Client.queue_send(MP.MATCH_WIRE.build_set_ante_payload(ante))
end

function match_action_runtime.new_round()
	if MP.begin_new_match_round then
		MP.begin_new_match_round()
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
	Client.queue_send(MP.MATCH_WIRE.build_timer_payload("startAnteTimer"))
end

function match_action_runtime.pause_ante_timer()
	trace_runtime_event("ante_timer.pause_requested", {
		ready_blind_kind = MP.GAME and MP.GAME.ready_blind_kind,
		time = MP.GAME and MP.GAME.timer,
	})
	Client.queue_send(MP.MATCH_WIRE.build_timer_payload("pauseAnteTimer"))
end

function match_action_runtime.fail_timer()
	trace_runtime_event("timer.fail_requested", {
		ruleset = MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.ruleset,
		time = MP.GAME and MP.GAME.timer,
	})
	Client.queue_send(MP.MATCH_WIRE.build_fail_timer_payload())
end

function match_action_runtime.sync_client()
	Client.queue_send(MP.MATCH_WIRE.build_sync_client_payload(_RELEASE_MODE))
end

function match_action_runtime.sync_money(money)
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
	if not MP.is_teams_mode() then
		trace_runtime_event("team_money.send_blocked", {
			reason = "not_teams",
			target_player_id = target_player_id,
			amount = amount,
		})
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

	local payload = MP.MATCH_WIRE.build_send_team_money_payload(target_player_id, transfer_amount)
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
MP.ACTIONS.sync_client = match_action_runtime.sync_client
MP.ACTIONS.sync_money = match_action_runtime.sync_money
MP.ACTIONS.send_team_money = match_action_runtime.send_team_money
