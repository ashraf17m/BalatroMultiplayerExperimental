MP.ACTIONS = MP.ACTIONS or {}

local match_action_runtime = {}

local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}
local teams_domain = MP.DOMAIN and MP.DOMAIN.TEAMS or {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

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
	if BALATRO.get_current_blind then
		local blind = BALATRO.get_current_blind()
		if blind then
			return blind
		end
	end
	return G and G.GAME and G.GAME.blind or nil
end

local function get_current_blind_target()
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

	if BALATRO.get_current_blind_target_chips then
		local target = BALATRO.get_current_blind_target_chips()
		if target ~= nil then
			return target
		end
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
	return BALATRO.get_ante and BALATRO.get_ante() or nil
end

local function apply_local_pvp_timer_score_gate(local_score)
	if not (
		MP.GAME
		and MP.is_pvp_boss
		and MP.is_pvp_boss()
		and MP.is_layer_active
		and MP.is_layer_active("pvp_timer")
		and MP.INSANE_INT
	) then
		return
	end

	local enemy_score = MP.GAME.enemy and MP.GAME.enemy.score or nil
	if not enemy_score then
		return
	end

	if MP.INSANE_INT.greater_than(local_score, enemy_score) then
		MP.GAME.nemesis_timer_started = false
	elseif MP.INSANE_INT.equal and MP.INSANE_INT.equal(local_score, enemy_score) and MP.GAME.pvp_reached_first then
		MP.GAME.nemesis_timer_started = false
	else
		MP.GAME.timer_started = false
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
	if BALATRO.get_round_reset_value then
		local round_reset_hands = BALATRO.get_round_reset_value("hands", nil)
		if round_reset_hands ~= nil then
			return round_reset_hands
		end
	end

	if BALATRO.get_hands_left then
		return BALATRO.get_hands_left()
	end
	return nil
end

local function apply_ready_blind_runtime_modifiers(amount)
	local paperback = BALATRO.get_game_value and BALATRO.get_game_value("paperback", nil) or nil
	if paperback and paperback.blind_multiplier ~= nil then
		amount = amount * paperback.blind_multiplier
	end

	return amount
end

local function get_ready_blind_target(blind_row, blind_kind)
	if blind_kind == "pvp" then
		return nil
	end

	if BALATRO.get_pvp_blind_choice and BALATRO.get_pvp_blind_choice(blind_row) then
		return nil
	end

	local blind_key = BALATRO.get_blind_choice and BALATRO.get_blind_choice(blind_row) or nil
	local blind_def = blind_key and BALATRO.get_blind_def and BALATRO.get_blind_def(blind_key) or nil
	if not (blind_def and blind_def.mult) then
		return nil
	end

	local ante = BALATRO.get_round_reset_value and BALATRO.get_round_reset_value("blind_ante", nil) or nil
	if ante == nil then
		ante = BALATRO.get_ante and BALATRO.get_ante() or nil
	end
	local blind_amount = BALATRO.get_blind_amount and BALATRO.get_blind_amount(ante) or nil
	if blind_amount == nil then
		return nil
	end

	local ante_scaling = BALATRO.get_starting_ante_scaling and BALATRO.get_starting_ante_scaling() or 1
	local target = apply_ready_blind_runtime_modifiers(blind_amount * blind_def.mult * ante_scaling)
	if MP.is_coop_run and MP.is_coop_run() and MP.scale_coop_blind_amount then
		target = MP.scale_coop_blind_amount(target)
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
	if MP.LOBBY.config.no_gold_on_round_loss then
		BALATRO.set_current_blind_dollars(0)
	end
	-- Live spectation: the simulated run already failed locally (chips <
	-- blind). Arm comeback the same way a real life packet would, then let
	-- vanilla evaluate_round add the row. Do not send fail_round or stamp
	-- the target's network result.
	if MP.SPECTATOR and MP.SPECTATOR.is_spectating then
		if
			not (MP.is_pvp_boss and MP.is_pvp_boss())
			and MP.LOBBY.config.death_on_round_loss
			and MP.LOBBY.config.gold_on_life_loss
			and MP.GAME
		then
			MP.GAME.comeback_bonus_given = false
			MP.GAME.comeback_eval_pending = true
			MP.GAME.comeback_bonus = (tonumber(MP.GAME.comeback_bonus) or 0) + 1
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
	apply_local_pvp_timer_score_gate(insane_int_score)
	local score_shared = MP.UI and MP.UI.PLAYERS_HUD_SHARED or nil
	if MP.GAME and MP.GAME.score_display and score_shared and score_shared.ease_standings_score_number then
		score_shared.ease_standings_score_number(MP.GAME.score_display, insane_int_score, {
			delay = score_shared.PVP_SCORE_EASE_DELAY,
		})
	end
	if teams_domain.recalculate_state then
		teams_domain.recalculate_state()
	end
	request_match_lobby_info_refresh()
	if MP.SPECTATOR and MP.SPECTATOR.is_spectating then
		if MP.UI and MP.UI.refresh_active_pvp_player_list then
			MP.UI.refresh_active_pvp_player_list()
		end
		return
	end
	Client.queue_send(payload)
	if MP.UI and MP.UI.refresh_active_pvp_player_list then
		MP.UI.refresh_active_pvp_player_list()
	end
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
