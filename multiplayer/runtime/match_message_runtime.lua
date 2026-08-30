MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}

local match_message_runtime = {}
local cached_match_flow_runtime = nil
local load_required_service = MP.UTILS.load_required_service

local MATCH_FLOW_RUNTIME_METHODS = {
	"start_match_runtime",
	"start_match_blind_runtime",
	"handle_team_skip_blind_runtime",
	"end_current_pvp_runtime",
	"end_current_coop_blind_runtime",
	"handle_match_win_runtime",
	"handle_match_alone_runtime",
	"handle_match_loss_runtime",
}

local function ensure_match_flow_runtime()
	if cached_match_flow_runtime then
		return cached_match_flow_runtime
	end

	cached_match_flow_runtime = load_required_service(
		"multiplayer/runtime/match_flow_runtime.lua",
		MATCH_FLOW_RUNTIME_METHODS,
		"Multiplayer match flow runtime service is missing."
	)
	return cached_match_flow_runtime
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

local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end

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
	if MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit and MP.SPECTATOR and MP.SPECTATOR.is_spectating then
		MP.SPECTATOR_LOG.emit("end_pvp_packet", {
			lost = not not lost,
			pvp_timer_lost = not not pvp_timer_lost,
		})
	end
	if buffer_resume_method("buffer_runtime_match_outcome", "endPvP", lost, pvp_timer_lost) then
		if MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit and MP.SPECTATOR and MP.SPECTATOR.is_spectating then
			MP.SPECTATOR_LOG.emit("end_pvp_buffered_resume")
		end
		return
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
