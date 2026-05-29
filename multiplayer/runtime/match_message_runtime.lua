MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}

local match_message_runtime = {}
local cached_match_flow_runtime = nil
local has_required_methods = MP.UTILS.has_required_methods

local MATCH_FLOW_RUNTIME_METHODS = {
	"start_match_runtime",
	"start_match_blind_runtime",
	"handle_team_skip_blind_runtime",
	"stop_match_runtime",
	"end_current_pvp_runtime",
	"handle_match_win_runtime",
	"handle_match_loss_runtime",
}

local function ensure_match_flow_runtime()
	if cached_match_flow_runtime then
		return cached_match_flow_runtime
	end

	local loaded = MP.PLATFORM.SMODS.load_mod_file("multiplayer/runtime/match_flow_runtime.lua", { required = true })
	if loaded == nil then
		return nil
	end
	if has_required_methods(loaded, MATCH_FLOW_RUNTIME_METHODS) then
		cached_match_flow_runtime = loaded
		return loaded
	end

	return nil
end

local function ensure_state_apply_runtime(required_method)
	local state_apply = MP.STATE_APPLY or nil
	if has_required_methods(state_apply, required_method) then
		return state_apply
	end

	local loaded = MP.PLATFORM.SMODS.load_mod_file("multiplayer/runtime/network_state_apply.lua", { required = true })
	if loaded == nil then
		return nil
	end
	if has_required_methods(loaded, required_method) then
		return loaded
	end

	state_apply = MP.STATE_APPLY or nil
	if has_required_methods(state_apply, required_method) then
		return state_apply
	end

	return nil
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

function match_message_runtime.handle_start_game(seed, stake_str)
	call_match_flow_runtime("start_match_runtime", seed, stake_str)
end

function match_message_runtime.handle_start_blind()
	call_match_flow_runtime("start_match_blind_runtime")
end

function match_message_runtime.handle_team_skip_blind(blind_row)
	call_match_flow_runtime("handle_team_skip_blind_runtime", blind_row)
end

function match_message_runtime.handle_stop_game()
	if buffer_resume_method("buffer_runtime_match_outcome", "stopGame") then
		return
	end

	call_match_flow_runtime("stop_match_runtime")
end

function match_message_runtime.handle_end_pvp()
	if buffer_resume_method("buffer_runtime_match_outcome", "endPvP") then
		return
	end

	call_match_flow_runtime("end_current_pvp_runtime")
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

	call_match_flow_runtime("handle_match_win_runtime")
end

function match_message_runtime.handle_lose_game()
	if buffer_resume_method("buffer_runtime_match_outcome", "loseGame") then
		return
	end

	call_match_flow_runtime("handle_match_loss_runtime")
end

function match_message_runtime.handle_enemy_info(
	player_id,
	username,
	score_str,
	hands_left_str,
	skips_str,
	lives_str,
	team,
	team_lives,
	life_loss_reason,
	previous_lives
)
	if
		buffer_resume_method(
			"buffer_runtime_enemy_info",
			player_id,
			username,
			score_str,
			hands_left_str,
			skips_str,
			lives_str,
			team,
			team_lives,
			life_loss_reason,
			previous_lives
		)
	then
		return
	end

	apply_state_update(
		"enemy_info",
		player_id,
		username,
		score_str,
		hands_left_str,
		skips_str,
		lives_str,
		team,
		team_lives,
		life_loss_reason,
		previous_lives
	)
end

function match_message_runtime.handle_enemy_location(options)
	if buffer_resume_method("buffer_runtime_enemy_location", options) then
		return
	end

	apply_state_update("enemy_location", options)
end

MP.NETWORKING_INTERNAL.handle_start_game = match_message_runtime.handle_start_game
MP.NETWORKING_INTERNAL.handle_start_blind = match_message_runtime.handle_start_blind
MP.NETWORKING_INTERNAL.handle_team_skip_blind = match_message_runtime.handle_team_skip_blind
MP.NETWORKING_INTERNAL.handle_stop_game = match_message_runtime.handle_stop_game
MP.NETWORKING_INTERNAL.handle_end_pvp = match_message_runtime.handle_end_pvp
MP.NETWORKING_INTERNAL.handle_player_info = match_message_runtime.handle_player_info
MP.NETWORKING_INTERNAL.handle_money_update = match_message_runtime.handle_money_update
MP.NETWORKING_INTERNAL.handle_win_game = match_message_runtime.handle_win_game
MP.NETWORKING_INTERNAL.handle_lose_game = match_message_runtime.handle_lose_game
MP.NETWORKING_INTERNAL.handle_enemy_info = match_message_runtime.handle_enemy_info
MP.NETWORKING_INTERNAL.handle_enemy_location = match_message_runtime.handle_enemy_location
