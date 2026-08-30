MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}

local match_flow_runtime = {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local build_traceback = MP.UTILS.build_traceback
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}
local teams_domain = MP.DOMAIN and MP.DOMAIN.TEAMS or {}
local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY or {}

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
	if target == nil then
		MP.GAME.coop_blind_target_chips = nil
	end
end

local function sync_local_blind_target_scale()
	if not (MP.ACTIONS and MP.ACTIONS.sync_blind_target_scale) then
		return
	end

	local scale = BALATRO.get_starting_ante_scaling and BALATRO.get_starting_ante_scaling() or 1
	local paperback = BALATRO.get_game_value and BALATRO.get_game_value("paperback", nil) or nil
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
		BALATRO.set_current_setup("Continue")
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
	local overlay = BALATRO.get_overlay_menu and BALATRO.get_overlay_menu() or nil
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
end

function match_flow_runtime.end_current_coop_blind_runtime(lost)
	set_server_coop_blind_target(nil)
	if match_domain.mark_end_coop_blind then
		match_domain.mark_end_coop_blind()
	elseif match_domain.mark_end_pvp then
		match_domain.mark_end_pvp()
	end
	if MP.release_cooperative_deck_out_resolution then
		MP.release_cooperative_deck_out_resolution()
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
	local states = BALATRO.get_states and BALATRO.get_states() or nil
	if (states and BALATRO.get_state and BALATRO.get_state() == states.GAME_WIN) or MP.GAME.won then
		return
	end
	prepare_terminal_match_outcome()
	if match_domain.mark_match_won then
		match_domain.mark_match_won()
	end
	MP.STATS.record_match(true)
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
	if is_loss_overlay_visible() then
		return
	end

	local states = BALATRO.get_states and BALATRO.get_states() or nil
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
		MP.STATS.record_match(false)
		log_terminal_match_memory()
	end
	BALATRO.set_state_complete(false)
	if states then
		BALATRO.set_state(states.GAME_OVER)
	end
	BALATRO.set_paused(true)
	BALATRO.call_ui_function("overlay_endgame_menu")
end

-- Spectator: the watched match finished. Leaves the board (spectator state
-- is cleared by MP.SPECTATOR.handle_match_ended before this runs) and shows
-- the endgame overlay, which offers Spectate-again and Return to Lobby.
function match_flow_runtime.handle_match_ended_runtime()
	prepare_terminal_match_outcome()
	if match_domain.mark_match_abandoned then
		match_domain.mark_match_abandoned()
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

return match_flow_runtime
