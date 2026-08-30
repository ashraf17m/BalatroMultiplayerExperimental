-- Contains game hooks and monkey-patches for multiplayer flow.
-- Overrides Game methods like update_draw_to_hand, update_hand_played, update_new_round, etc.

local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end
local pack_values = MP.UTILS.pack_values
local unpack_packed = MP.UTILS.unpack_packed
local build_traceback = MP.UTILS.build_traceback
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}
local teams_domain = MP.DOMAIN and MP.DOMAIN.TEAMS or {}
local SURVIVAL_WAIT_WIN_ANTE_SENTINEL = 999

local function set_win_ante(win_ante) G.GAME.win_ante = win_ante end

local function set_state_complete(state_complete) G.STATE_COMPLETE = state_complete end

local function set_game_state(state) G.STATE = state end

local function transition_to_state(state, state_complete)
	if state_complete ~= nil then
		set_state_complete(state_complete)
	end

	set_game_state(state)
end

local function set_blind_pvp_flag(active) G.GAME.blind.pvp = not not active end

local function mark_after_pvp_context() G.after_pvp = true end

local function set_current_round_hands_left(hands_left) G.GAME.current_round.hands_left = hands_left end

local function call_with_temporary_win_ante(win_ante, fn, ...)
	local original_win_ante = G.GAME.win_ante
	local args = pack_values(...)
	local results = nil

	set_win_ante(win_ante)
	local ok, err = xpcall(function()
		results = pack_values(fn(unpack_packed(args)))
	end, build_traceback)
	set_win_ante(original_win_ante)

	if not ok then
		error(err, 0)
	end

	return unpack_packed(results)
end

local function call_with_temporary_failed_blind_target(fn, ...)
	local blind = G.GAME and G.GAME.blind or nil
	if not blind then
		return fn(...)
	end

	local original_chips = blind.chips
	local original_chip_text = blind.chip_text
	local args = pack_values(...)
	local results = nil

	blind.chips = -1
	local ok, err = xpcall(function()
		results = pack_values(fn(unpack_packed(args)))
	end, build_traceback)

	if G.GAME and G.GAME.blind == blind and blind.chips == -1 then
		blind.chips = original_chips
		blind.chip_text = original_chip_text
	end

	if not ok then
		error(err, 0)
	end

	return unpack_packed(results)
end

local function enter_pvp_new_round(options)
	options = options or {}

	if options.unhighlight_hand and G.hand then
		G.hand:unhighlight_all()
	end

	if options.draw_to_deck and G.STATE ~= G.STATES.NEW_ROUND then
		G.FUNCS.draw_from_hand_to_deck()
		G.FUNCS.draw_from_discard_to_deck()
	end

	transition_to_state(G.STATES.NEW_ROUND, options.state_complete)
	trace_runtime_event("run_flow.enter_pvp_new_round", { draw_to_deck = options.draw_to_deck == true, end_pvp = not not MP.GAME.end_pvp, hands_left = G.GAME.current_round.hands_left, state_complete = G.STATE_COMPLETE, unhighlight_hand = options.unhighlight_hand == true })
	if MP.SPECTATOR and (MP.SPECTATOR.is_spectating or MP.SPECTATOR.is_spectator_role) and MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit then
		MP.SPECTATOR_LOG.emit("enter_pvp_new_round", {
			draw_to_deck = options.draw_to_deck == true,
			unhighlight_hand = options.unhighlight_hand == true,
			from = "run_flow",
		})
	end

	if match_domain.clear_end_pvp then
		match_domain.clear_end_pvp()
	end
end

local function is_first_blind_draw_to_hand()
	return not G.STATE_COMPLETE
		and G.GAME.current_round.hands_played == 0
		and G.GAME.current_round.discards_used == 0
		and G.GAME.facing_blind
end

local function should_prepare_first_blind_draw_to_hand()
	return MP.LOBBY.code and is_first_blind_draw_to_hand()
end

local function update_pvp_blind_hud_after_intro()
	G.HUD_blind:get_UIE_by_ID("HUD_blind_name").config.object:pop_out(0)
	MP.UI.update_blind_HUD()
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = 0.45,
		blockable = false,
		func = function()
			if MP.UI.update_primary_opponent_blind_name then
				MP.UI.update_primary_opponent_blind_name(true)
			end
			return true
		end,
	}))
end

local function queue_pvp_blind_intro_hud_update()
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = 1,
		blockable = false,
		func = function()
			update_pvp_blind_hud_after_intro()
			return true
		end,
	}))
end

local function unlock_pincher_for_pvp_blind()
	if match_domain.set_pincher_unlocked then
		match_domain.set_pincher_unlocked()
	end
end

local function play_asteroid_send_sequence(asteroid_count)
	delay(0.8)
	update_hand_text({ sound = "button", volume = 0.7, pitch = 0.8, delay = 0.3 }, {
		handname = localize("k_asteroids"),
		chips = localize("k_amount_short"),
		mult = asteroid_count,
	})
	delay(0.6)
	local send = 0
	for i = 1, asteroid_count do
		local perc = asteroid_count - send
		G.E_MANAGER:add_event(Event({
			func = function()
				play_sound("tarot1", 0.9 + (perc / 10), 1)
				return true
			end,
		}))
		send = send + 1
		update_hand_text({ delay = 0 }, { mult = asteroid_count - send })
		delay(0.2)
	end
	G.E_MANAGER:add_event(Event({
		func = function()
			for i = 1, asteroid_count do
				MP.ACTIONS.asteroid()
			end
			return true
		end,
	}))
	delay(0.7)
	update_hand_text(
		{ sound = "button", volume = 0.7, pitch = 1.1, delay = 0 },
		{ mult = 0, chips = 0, handname = "", level = "" }
	)
end

local function consume_and_send_match_asteroids()
	if MP.GAME.asteroids <= 0 then
		return
	end

	local asteroid_count = match_domain.consume_asteroids and match_domain.consume_asteroids() or MP.GAME.asteroids
	play_asteroid_send_sequence(asteroid_count)
end

local function prepare_first_pvp_blind_draw_to_hand()
	set_blind_pvp_flag(G.GAME.round_resets.pvp_blind_choices[G.GAME.blind_on_deck])
	trace_runtime_event("run_flow.prepare_first_blind_draw_to_hand", { blind_on_deck = G.GAME.blind_on_deck, is_pvp_boss = MP.is_pvp_boss(), pvp_flag = G.GAME.blind.pvp })
	if not MP.is_pvp_boss() then
		return
	end

	queue_pvp_blind_intro_hud_update()
	unlock_pincher_for_pvp_blind()
	mark_after_pvp_context()
	consume_and_send_match_asteroids()
end

local update_draw_to_hand_ref = Game.update_draw_to_hand
function Game:update_draw_to_hand(dt)
	if should_prepare_first_blind_draw_to_hand() then
		prepare_first_pvp_blind_draw_to_hand()
	end
	update_draw_to_hand_ref(self, dt)
end

local function eval_hand_and_jokers()
	for i = 1, #G.hand.cards do
		local reps = { 1 }
		local j = 1
		while j <= #reps do
			local percent = (i - 0.999) / (#G.hand.cards - 0.998) + (j - 1) * 0.1
			if reps[j] ~= 1 then
				card_eval_status_text(
					(reps[j].jokers or reps[j].seals).card,
					"jokers",
					nil,
					nil,
					nil,
					(reps[j].jokers or reps[j].seals)
				)
			end

			local effects = { G.hand.cards[i]:get_end_of_round_effect() }
			for k = 1, #G.jokers.cards do
				local eval = G.jokers.cards[k]:calculate_joker({
					cardarea = G.hand,
					other_card = G.hand.cards[i],
					individual = true,
					end_of_round = true,
				})
				if eval then table.insert(effects, eval) end
			end

			if reps[j] == 1 then
				local eval = eval_card(
					G.hand.cards[i],
					{ end_of_round = true, cardarea = G.hand, repetition = true, repetition_only = true }
				)
				if next(eval) and (next(effects[1]) or #effects > 1) then
					for h = 1, eval.seals.repetitions do
						reps[#reps + 1] = eval
					end
				end

				for joker_idx = 1, #G.jokers.cards do
					local joker_eval = eval_card(G.jokers.cards[joker_idx], {
						cardarea = G.hand,
						other_card = G.hand.cards[i],
						repetition = true,
						end_of_round = true,
						card_effects = effects,
					})
					if next(joker_eval) then
						for h = 1, joker_eval.jokers.repetitions do
							reps[#reps + 1] = joker_eval
						end
					end
				end
			end

			for ii = 1, #effects do
				if effects[ii].card then
					G.E_MANAGER:add_event(Event({
						trigger = "immediate",
						func = function()
							effects[ii].card:juice_up(0.7)
							return true
						end,
					}))
				end

				if effects[ii].h_dollars then
					ease_dollars(effects[ii].h_dollars)
					card_eval_status_text(G.hand.cards[i], "dollars", effects[ii].h_dollars, percent)
				end

				if effects[ii].extra then
					card_eval_status_text(G.hand.cards[i], "extra", nil, percent, nil, effects[ii].extra)
				end
			end
			j = j + 1
		end
	end
end

local function is_connected_multiplayer_run()
	return MP.LOBBY.client.connected and MP.LOBBY.code
end

local function should_use_server_resolved_hand_played_flow()
	return is_connected_multiplayer_run() and MP.is_server_resolved_blind()
end

local function remove_run_buttons_and_shop(game)
	if game.buttons then
		game.buttons:remove()
		game.buttons = nil
	end
	if game.shop then
		game.shop:remove()
		game.shop = nil
	end
end

local function is_cooperative_server_blind()
	return (MP.is_coop_run and MP.is_coop_run())
		or (teams_domain.is_cooperative_blind and teams_domain.is_cooperative_blind())
		or (MP.is_coop_blind and MP.is_coop_blind())
end

local function show_wait_for_enemy_hand_text()
	attention_text({
		scale = 0.8,
		text = is_cooperative_server_blind() and "Waiting for players..." or localize("k_wait_enemy"),
		hold = 5,
		align = "cm",
		offset = { x = 0, y = -1.5 },
		major = G.play,
	})
end

local function should_eval_waiting_hand()
	return G.hand.cards[1] and G.STATE == G.STATES.HAND_PLAYED
end

local function should_draw_next_hand_after_play()
	return not MP.GAME.end_pvp and G.STATE == G.STATES.HAND_PLAYED
end

local function get_current_blind_target()
	local blind = G.GAME and G.GAME.blind or nil
	return blind and blind.chips or nil
end

local function is_duel_bye_blind()
	return MP.is_duel_bye_blind and MP.is_duel_bye_blind()
end

function MP.handle_duel_bye_round_complete()
	if not is_duel_bye_blind() then
		return false
	end

	if match_domain.mark_duel_bye_waiting then
		match_domain.mark_duel_bye_waiting()
	end

	MP.ACTIONS.play_hand(G.GAME.chips, 0, { blind_target = get_current_blind_target() })

	return true
end

local function should_wait_after_server_resolved_hand()
	return G.GAME.current_round.hands_left < 1
end

local function wait_for_server_resolved_deck_out()
	trace_runtime_event("run_flow.server_resolved_deck_out_wait", {
		blind_chips = G.GAME.blind and G.GAME.blind.chips or nil,
		chips = G.GAME.chips,
	})

	MP.GAME.round_ended = false
	MP.GAME.duplicate_end = false
	set_current_round_hands_left(0)
	set_state_complete(true)
	show_wait_for_enemy_hand_text()
	MP.ACTIONS.play_hand(0, 0, { blind_target = get_current_blind_target() })
	return true
end

local function resolve_server_hand_played_event()
	trace_runtime_event("run_flow.server_resolved_hand_start", {
		chips = G.GAME.chips,
		end_pvp = not not MP.GAME.end_pvp,
		hands_left = G.GAME.current_round.hands_left,
	})

	MP.ACTIONS.play_hand(G.GAME.chips, G.GAME.current_round.hands_left)
	if should_wait_after_server_resolved_hand() then
		show_wait_for_enemy_hand_text()
		if should_eval_waiting_hand() then
			eval_hand_and_jokers()
			G.FUNCS.draw_from_hand_to_discard()
		end
	elseif should_draw_next_hand_after_play() then
		transition_to_state(G.STATES.DRAW_TO_HAND, false)
	end
	return true
end

local function queue_server_hand_played_event()
	G.E_MANAGER:add_event(Event({
		trigger = "immediate",
		func = resolve_server_hand_played_event,
	}))
end

local function should_enter_new_round_from_resolved_hand()
	if not (MP.GAME.end_pvp and MP.is_server_resolved_blind()) then
		return false
	end
	return not (G.GAME.STOP_USE and G.GAME.STOP_USE > 0)
end

local update_hand_played_ref = Game.update_hand_played
---@diagnostic disable-next-line: duplicate-set-field
function Game:update_hand_played(dt)
	if not should_use_server_resolved_hand_played_flow() then
		update_hand_played_ref(self, dt)
		return
	end

	remove_run_buttons_and_shop(self)

	if not G.STATE_COMPLETE then
		set_state_complete(true)
		if MP.SPECTATOR and (MP.SPECTATOR.is_spectating or MP.SPECTATOR.is_spectator_role) and MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit then
			MP.SPECTATOR_LOG.emit("hand_played_queue_server_event")
		end
		queue_server_hand_played_event()
	end

	if should_enter_new_round_from_resolved_hand() then
		if MP.SPECTATOR and (MP.SPECTATOR.is_spectating or MP.SPECTATOR.is_spectator_role) and MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit then
			MP.SPECTATOR_LOG.emit("hand_played_enter_new_round")
		end
		enter_pvp_new_round({ state_complete = false })
	end
end

local function should_force_current_round_failure()
	return not MP.GAME.round_failed
		and to_big(G.GAME.chips) < to_big(G.GAME.blind.chips)
		and not MP.is_server_resolved_blind()
end

local function is_survival_final_life()
	return (MP.is_survival_gamemode and MP.is_survival_gamemode()) and (tonumber(MP.GAME.lives) == 1)
end

local function mark_wait_for_enemy_furthest_blind_if_available()
	if match_domain.set_wait_for_enemy_furthest_blind then
		match_domain.set_wait_for_enemy_furthest_blind(is_survival_final_life())
	end
end

local function fail_current_round_if_needed()
	if not should_force_current_round_failure() then
		return false
	end

	trace_runtime_event("run_flow.fail_round_send", { blind_chips = G.GAME.blind.chips, chips = G.GAME.chips, hands_played = G.GAME.current_round.hands_played, survival_final_life = is_survival_final_life() })

	MP.GAME.round_failed = true

	mark_wait_for_enemy_furthest_blind_if_available()
	MP.ACTIONS.fail_round(G.GAME.current_round.hands_played)
	return false
end

local function should_wait_for_enemy_furthest_blind()
	return MP.is_survival_gamemode and MP.is_survival_gamemode() and MP.GAME.wait_for_enemys_furthest_blind
end

local function wait_for_enemy_to_reach_blind()
	trace_runtime_event("run_flow.wait_for_enemy_furthest_blind", { furthest_blind = MP.GAME.furthest_blind, lives = MP.GAME.lives })

	set_state_complete(true)
	G.FUNCS.draw_from_hand_to_discard()
	attention_text({
		scale = 0.8,
		text = localize("k_wait_enemy_reach_this_blind"),
		hold = 5,
		align = "cm",
		offset = { x = 0, y = -1.5 },
		major = G.play,
	})
end

local function should_handle_zero_hand_deck_out()
	return MP.LOBBY.code
		and G.GAME.current_round.hands_played == 0
		and G.GAME.current_round.discards_used > 0
		and MP.LOBBY.config.gamemode ~= "gamemode_mp_survival"
end

local function should_wait_for_cooperative_deck_out_resolution()
	return should_handle_zero_hand_deck_out()
		and is_cooperative_server_blind()
		and not MP.GAME.coop_deck_out_waiting
		and not MP.GAME.coop_deck_out_resolved
end

local function wait_for_cooperative_deck_out_resolution()
	trace_runtime_event("run_flow.coop_deck_out_wait", {
		chips = G.GAME.chips,
		blind_chips = G.GAME.blind and G.GAME.blind.chips or nil,
	})

	MP.GAME.coop_deck_out_waiting = true
	MP.GAME.round_ended = false
	MP.GAME.duplicate_end = false
	set_current_round_hands_left(0)
	set_state_complete(true)
	show_wait_for_enemy_hand_text()
	MP.ACTIONS.fail_round(1)
	return true
end

local function should_release_cooperative_deck_out_resolution()
	return MP.GAME.end_pvp
		and MP.GAME.coop_deck_out_waiting
end

local function release_cooperative_deck_out_resolution()
	MP.GAME.coop_deck_out_waiting = false
	MP.GAME.coop_deck_out_resolved = true
	MP.GAME.round_ended = false
	MP.GAME.duplicate_end = false
	set_state_complete(false)
end

local function finish_resolved_cooperative_deck_out()
	release_cooperative_deck_out_resolution()
	transition_to_state(G.STATES.NEW_ROUND, false)
	return true
end

local function to_insane_score(value)
	if not (MP.INSANE_INT and MP.INSANE_INT.from_string) then
		return nil
	end
	if type(value) == "table" then
		if value.coefficient ~= nil or value.coeffiocient ~= nil or value.exponent ~= nil or value.e_count ~= nil then
			return value
		end
	end

	local ok, score = pcall(MP.INSANE_INT.from_string, tostring(value or "0"))
	if not ok then
		return nil
	end
	return score
end

local function is_cooperative_blind_already_cleared_locally()
	if not (
		teams_domain.get_cooperative_blind_score
		and teams_domain.get_cooperative_blind_target
		and MP.INSANE_INT
		and MP.INSANE_INT.greater_than
	) then
		return false
	end

	local ok_score, score = pcall(teams_domain.get_cooperative_blind_score)
	if not ok_score or not score then
		return false
	end

	local ok_target, target = pcall(teams_domain.get_cooperative_blind_target)
	if not ok_target then
		return false
	end

	target = to_insane_score(target)
	if not target then
		return false
	end

	local ok_compare, target_is_greater = pcall(MP.INSANE_INT.greater_than, target, score)
	return ok_compare and not target_is_greater
end

local function finish_locally_cleared_cooperative_deck_out()
	trace_runtime_event("run_flow.coop_deck_out_locally_cleared", {
		chips = G.GAME.chips,
		blind_chips = G.GAME.blind and G.GAME.blind.chips or nil,
	})

	MP.ACTIONS.fail_round(1)
	return finish_resolved_cooperative_deck_out()
end

local function should_finish_locally_cleared_cooperative_deck_out()
	return should_wait_for_cooperative_deck_out_resolution()
		and is_cooperative_blind_already_cleared_locally()
end

function MP.release_cooperative_deck_out_resolution()
	if not (MP.GAME and MP.GAME.coop_deck_out_waiting) then
		return false
	end

	return finish_resolved_cooperative_deck_out()
end

local function should_use_multiplayer_new_round_flow()
	return MP.LOBBY.code and not G.STATE_COMPLETE
end

local update_new_round_ref = Game.update_new_round
function Game:update_new_round(dt)
	local releasing_coop_deck_out = should_release_cooperative_deck_out_resolution()
	if releasing_coop_deck_out then
		release_cooperative_deck_out_resolution()
	end

	if MP.GAME.end_pvp and MP.is_server_resolved_blind() then
		enter_pvp_new_round({
			draw_to_deck = true,
			state_complete = releasing_coop_deck_out and false or nil,
		})
	end
	if should_use_multiplayer_new_round_flow() then
		if fail_current_round_if_needed() then
			return
		end

		call_with_temporary_win_ante(SURVIVAL_WAIT_WIN_ANTE_SENTINEL, function()
			if should_wait_for_enemy_furthest_blind() then
				wait_for_enemy_to_reach_blind()
			elseif should_finish_locally_cleared_cooperative_deck_out() then
				finish_locally_cleared_cooperative_deck_out()
			elseif should_wait_for_cooperative_deck_out_resolution() then
				wait_for_cooperative_deck_out_resolution()
			elseif MP.GAME.round_failed then
				call_with_temporary_failed_blind_target(update_new_round_ref, self, dt)
			else
				update_new_round_ref(self, dt)
			end
		end)
		return
	end
	update_new_round_ref(self, dt)
end

local function release_duel_bye_round_eval_wait_if_ready()
	if not (MP.GAME and MP.GAME.duel_bye_waiting and MP.GAME.end_pvp) then
		return false
	end

	if match_domain.clear_duel_bye_waiting then
		match_domain.clear_duel_bye_waiting()
	end
	if match_domain.clear_end_pvp then
		match_domain.clear_end_pvp()
	end
	set_state_complete(false)
	return true
end

local function should_wait_for_duel_bye_round_result()
	return MP.GAME
		and MP.GAME.duel_bye_waiting
		and not MP.GAME.end_pvp
end

local function show_wait_for_duel_round_text()
	attention_text({
		scale = 0.8,
		text = "Waiting for duel...",
		hold = 5,
		align = "cm",
		offset = { x = 0, y = -1.5 },
		major = G.play,
	})
end

local update_round_eval_ref = Game.update_round_eval
function Game:update_round_eval(dt)
	release_duel_bye_round_eval_wait_if_ready()
	if should_wait_for_duel_bye_round_result() then
		if not G.STATE_COMPLETE then
			set_state_complete(true)
			show_wait_for_duel_round_text()
		end
		return
	end

	update_round_eval_ref(self, dt)
end

local function should_handle_empty_deck_selecting_hand()
	return G.GAME.current_round.hands_left < G.GAME.round_resets.hands
		and #G.hand.cards < 1
		and #G.deck.cards < 1
		and #G.play.cards < 1
		and MP.LOBBY.code
end

local function handle_empty_deck_selecting_hand()
	trace_runtime_event("run_flow.empty_deck_selecting_hand", { chips = G.GAME.chips, server_resolved_blind = MP.is_server_resolved_blind() })

	set_current_round_hands_left(0)
	if not MP.is_server_resolved_blind() then
		transition_to_state(G.STATES.NEW_ROUND, false)
	else
		MP.ACTIONS.play_hand(G.GAME.chips, 0)
		transition_to_state(G.STATES.HAND_PLAYED, false)
	end
end

local function should_enter_new_round_after_selecting_hand()
	return MP.GAME.end_pvp and MP.is_server_resolved_blind()
end

local update_selecting_hand_ref = Game.update_selecting_hand
function Game:update_selecting_hand(dt)
	if should_handle_empty_deck_selecting_hand() then
		handle_empty_deck_selecting_hand()
		return
	end
	update_selecting_hand_ref(self, dt)

	if should_enter_new_round_after_selecting_hand() then
		if MP.SPECTATOR and (MP.SPECTATOR.is_spectating or MP.SPECTATOR.is_spectator_role) and MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit then
			MP.SPECTATOR_LOG.emit("selecting_hand_enter_new_round")
		end
		enter_pvp_new_round({ unhighlight_hand = true, state_complete = false })
	end
end

function MP.handle_duplicate_end()
	if MP.SPECTATOR and MP.SPECTATOR.is_spectating then
		-- round_ended is a local-client latch. Spectators keep it after the
		-- previous target (or previous blind) cashes out, which then aborts
		-- this target's end_round and leaves NEW_ROUND with no cash-out screen.
		if G and G.round_eval then
			return true
		end
		if MP.GAME then
			MP.GAME.round_ended = false
		end
		return false
	end
	if MP.LOBBY.code then
		if MP.GAME.round_ended then
			if match_domain.mark_duplicate_end and match_domain.mark_duplicate_end() then
				sendDebugMessage("Duplicate end_round calls prevented.", "MULTIPLAYER")
			end
			return true
		end
	end
	return false
end

function MP.handle_deck_out()
	if should_handle_zero_hand_deck_out() then
		if is_cooperative_server_blind() then
			if MP.GAME.end_pvp and MP.is_server_resolved_blind() then
				return finish_resolved_cooperative_deck_out()
			end
			if MP.GAME.coop_deck_out_resolved then
				return false
			end
			if should_finish_locally_cleared_cooperative_deck_out() then
				return finish_locally_cleared_cooperative_deck_out()
			end
			if should_wait_for_cooperative_deck_out_resolution() then
				return wait_for_cooperative_deck_out_resolution()
			end
			return true
		elseif MP.is_server_resolved_blind() then
			return wait_for_server_resolved_deck_out()
		else
			MP.GAME.round_failed = true
			MP.ACTIONS.fail_round(1)
		end
	end
	return false
end
