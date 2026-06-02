MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}

local match_flow_runtime = {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local build_traceback = MP.UTILS.build_traceback
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}
local teams_domain = MP.DOMAIN and MP.DOMAIN.TEAMS or {}

local function get_blind_choice_internal()
	return MP.BLIND_CHOICE_INTERNAL or {}
end

local function get_match_timer_start_time()
	if MP.ANTE_TIMER_RUNTIME and MP.ANTE_TIMER_RUNTIME.get_match_start_time then
		return MP.ANTE_TIMER_RUNTIME.get_match_start_time()
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

function match_flow_runtime.sync_resume_enemies_from_lobby()
	MP.STATE_APPLY.sync_resume_enemies_from_lobby()
end

function match_flow_runtime.start_match_runtime(seed, stake_str)
	MP.MATCH_LIFECYCLE.begin_match_runtime()

	local stake = tonumber(stake_str)
	MP.ACTIONS.set_ante(0)
	if not MP.LOBBY.config.different_seeds and MP.LOBBY.config.custom_seed ~= "random" then
		seed = MP.LOBBY.config.custom_seed
	end
	BALATRO.start_lobby_run({ seed = seed, stake = stake })
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

function match_flow_runtime.start_match_blind_runtime()
	local blind_choice = get_blind_choice_internal()
	local ready_blind_kind = blind_choice.get_match_ready_blind_kind and blind_choice.get_match_ready_blind_kind() or nil
	local is_pvp_blind = ready_blind_kind == "pvp"
	local skip_pvp_countdown = MP.GAME and MP.GAME.start_blind_skip_pvp_countdown

	MP.MATCH_LIFECYCLE.reset_local_blind_ready_runtime()
	if blind_choice.clear_skip_ready_state then
		blind_choice.clear_skip_ready_state()
	end
	if match_domain.clear_next_blind_context then
		match_domain.clear_next_blind_context()
	end

	if is_pvp_blind then
		MP.ANTE_TIMER_RUNTIME.reset_for_ante(get_match_timer_start_time())
		if skip_pvp_countdown then
			begin_pvp_blind()
		else
			MP.UI.start_pvp_countdown(begin_pvp_blind)
		end
	else
		begin_pvp_blind()
	end

	if MP.UI and MP.UI.refresh_timer_hud_binding then
		MP.UI.refresh_timer_hud_binding()
	end
end

function match_flow_runtime.handle_team_skip_blind_runtime(blind_row)
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
		blind_choice.perform_team_skip(blind_row)
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

function match_flow_runtime.end_current_pvp_runtime()
	if match_domain.mark_end_pvp then
		match_domain.mark_end_pvp()
	end
	if MP.is_pvp_boss and MP.is_pvp_boss() then
		MP.ANTE_TIMER_RUNTIME.reset_for_ante(get_match_timer_start_time())
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
	win_game()
end

function match_flow_runtime.handle_match_loss_runtime()
	local states = BALATRO.get_states and BALATRO.get_states() or nil
	if states and BALATRO.get_state and BALATRO.get_state() == states.GAME_OVER then
		return
	end
	prepare_terminal_match_outcome()
	MP.STATS.record_match(false)
	BALATRO.set_state_complete(false)
	if states then
		BALATRO.set_state(states.GAME_OVER)
	end
end

MP.NETWORKING_INTERNAL.sync_resume_enemies_from_lobby = match_flow_runtime.sync_resume_enemies_from_lobby
MP.NETWORKING_INTERNAL.start_match_runtime = match_flow_runtime.start_match_runtime
MP.NETWORKING_INTERNAL.resume_match_runtime = match_flow_runtime.resume_match_runtime
MP.NETWORKING_INTERNAL.start_match_blind_runtime = match_flow_runtime.start_match_blind_runtime
MP.NETWORKING_INTERNAL.handle_team_skip_blind_runtime = match_flow_runtime.handle_team_skip_blind_runtime
MP.NETWORKING_INTERNAL.end_current_pvp_runtime = match_flow_runtime.end_current_pvp_runtime
MP.NETWORKING_INTERNAL.handle_match_win_runtime = match_flow_runtime.handle_match_win_runtime
MP.NETWORKING_INTERNAL.handle_match_loss_runtime = match_flow_runtime.handle_match_loss_runtime

return match_flow_runtime
