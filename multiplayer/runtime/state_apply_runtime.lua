local STATE_APPLY_RUNTIME = {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}
local teams_domain = MP.DOMAIN and MP.DOMAIN.TEAMS or {}

local function refresh_primary_enemy_view(enemy)
	if MP.OPPONENTS and MP.OPPONENTS.refresh_primary_enemy_view then
		MP.OPPONENTS.refresh_primary_enemy_view(enemy)
	end
end

local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end

local function call_state_effect(effect_name, ...)
	local state_effects = MP.UI and MP.UI.STATE_APPLY_EFFECTS or nil
	local effect = state_effects and state_effects[effect_name] or nil
	if type(effect) == "function" then
		return effect(...)
	end
end

local function recalculate_team_state()
	if teams_domain.recalculate_state then
		teams_domain.recalculate_state()
	end
end

local function refresh_player_list(options)
	if
		options
		and options.force_now
		and MP.UI
		and MP.UI.refresh_active_pvp_player_list
		and MP.UI.refresh_active_pvp_player_list()
	then
		return
	end

	if MP.UI and MP.UI.request_player_list_refresh then
		return MP.UI.request_player_list_refresh()
	end
	return false
end

local function request_lobby_main_menu_refresh()
	if MP.UI and MP.UI.request_lobby_main_menu_refresh then
		return MP.UI.request_lobby_main_menu_refresh()
	end
	return false
end

local function request_overlay_menu_close()
	if MP.UI and MP.UI.request_overlay_menu_close then
		return MP.UI.request_overlay_menu_close()
	end
	return false
end

local function request_active_lobby_overlay_refresh()
	if MP.UI and MP.UI.request_lobby_overlay_refresh then
		return MP.UI.request_lobby_overlay_refresh()
	end
	return false
end

local function request_match_lobby_info_refresh()
	if MP.UI and MP.UI.request_match_lobby_info_refresh then
		return MP.UI.request_match_lobby_info_refresh()
	end
	return false
end

local function get_local_score_int()
	if MP.GAME and MP.GAME.score_display then
		return MP.GAME.score_display
	end
	if MP.INSANE_INT and MP.INSANE_INT.from_string then
		return MP.INSANE_INT.from_string(tostring(MP.GAME and MP.GAME.score_text or "0"))
	end
	return nil
end

local function apply_pvp_timer_score_gate(enemy_score)
	if not (
		MP.GAME
		and enemy_score
		and MP.is_pvp_boss
		and MP.is_pvp_boss()
		and MP.is_layer_active
		and MP.is_layer_active("pvp_timer")
		and MP.INSANE_INT
	) then
		return
	end

	local local_score = get_local_score_int()
	if not local_score then
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

local function restore_skip_timer_bonus_once(skip_delta, total_skips, increment)
	if not (MP.GAME and MP.UI and MP.UI.restore_timer) then
		return
	end

	local normalized_delta = math.max(0, math.floor(tonumber(skip_delta) or 0))
	local normalized_total = math.floor(tonumber(total_skips) or 0)
	if normalized_delta <= 0 or normalized_total <= 0 then
		return
	end

	MP.GAME.timer_skip_bonus_applied_for_skips = MP.GAME.timer_skip_bonus_applied_for_skips or {}
	local seen = MP.GAME.timer_skip_bonus_applied_for_skips
	local first_skip = math.max(1, normalized_total - normalized_delta + 1)

	for skip_count = first_skip, normalized_total do
		if not seen[skip_count] then
			seen[skip_count] = true
			MP.UI.restore_timer(increment)
		end
	end
end

local function apply_enemy_skip_timer_bonus(skip_delta, total_skips)
	if
		(skip_delta or 0) <= 0
		or not (MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.timer)
		or not (MP.GAME and MP.GAME.timer)
		or MP.GAME.timer_started
		or MP.GAME.nemesis_timer_started
		or MP.GAME.timer_consumed
		or not (MP.is_any_layer_active and MP.is_any_layer_active({ "no_animation_timer", "pressure_timer" }))
	then
		return
	end

	local increment = tonumber(MP.LOBBY.config.timer_increment_seconds) or 0
	if increment <= 0 then
		return
	end

	restore_skip_timer_bonus_once(skip_delta, total_skips, increment)
end

local function request_group_options_overlay_refresh()
	if MP.UI and MP.UI.request_group_options_overlay_refresh then
		return MP.UI.request_group_options_overlay_refresh()
	end
	return false
end

local function should_refresh_group_options_for_lobby_type_change(previous_lobby_type, lobby_type)
	if MP.UI and MP.UI.should_refresh_group_options_for_lobby_type_change then
		return MP.UI.should_refresh_group_options_for_lobby_type_change(previous_lobby_type, lobby_type)
	end

	return previous_lobby_type ~= lobby_type
end

local function refresh_lobby_main_menu_if_needed()
	if BALATRO.is_main_menu_stage and BALATRO.is_main_menu_stage() then
		request_lobby_main_menu_refresh()
	end
end

function STATE_APPLY_RUNTIME.resolve_enemy_location_text(location)
	return MP.UTILS.resolve_location_text(location)
end

function STATE_APPLY_RUNTIME.handle_lobby_snapshot(snapshot_result)
	if not snapshot_result then
		return
	end

	if not snapshot_result.previous_match_in_progress and snapshot_result.match_in_progress and BALATRO.get_overlay_menu and BALATRO.get_overlay_menu() then
		request_overlay_menu_close()
	end

	if BALATRO.is_main_menu_stage and BALATRO.is_main_menu_stage() then
		request_lobby_main_menu_refresh()
		request_active_lobby_overlay_refresh()
	end

	request_match_lobby_info_refresh()

	if should_refresh_group_options_for_lobby_type_change(snapshot_result.previous_lobby_type, snapshot_result.lobby_type) then
		request_group_options_overlay_refresh()
	end

	recalculate_team_state()
	refresh_primary_enemy_view()
	refresh_player_list()
end

function STATE_APPLY_RUNTIME.handle_lobby_player_joined(snapshot_result)
	STATE_APPLY_RUNTIME.handle_lobby_snapshot(snapshot_result)
end

function STATE_APPLY_RUNTIME.handle_lobby_player_updated(snapshot_result)
	STATE_APPLY_RUNTIME.handle_lobby_snapshot(snapshot_result)
end

function STATE_APPLY_RUNTIME.handle_lobby_player_left(snapshot_result)
	STATE_APPLY_RUNTIME.handle_lobby_snapshot(snapshot_result)
end

function STATE_APPLY_RUNTIME.handle_lobby_type_changed(snapshot_result)
	STATE_APPLY_RUNTIME.handle_lobby_snapshot(snapshot_result)
end

function STATE_APPLY_RUNTIME.handle_lobby_team_assignment()
	refresh_lobby_main_menu_if_needed()
	request_active_lobby_overlay_refresh()

	recalculate_team_state()
	refresh_primary_enemy_view()
end

function STATE_APPLY_RUNTIME.handle_lobby_nemesis_assignments()
	refresh_lobby_main_menu_if_needed()

	refresh_primary_enemy_view()
	request_match_lobby_info_refresh()
end

function STATE_APPLY_RUNTIME.handle_local_player_info(update_result)
	if not update_result then
		return
	end

	if update_result.changed then
		call_state_effect("ease_lives", update_result.lives - update_result.previous_lives)
		call_state_effect("log_life_loss_reason", "Life lost", update_result, { log_missing_reason = true })
		if MP.LOBBY.config.no_gold_on_round_loss then
			BALATRO.set_current_blind_dollars(0)
		end
	end

	recalculate_team_state()
	request_match_lobby_info_refresh()
	refresh_player_list()
end

function STATE_APPLY_RUNTIME.handle_remote_money_update(money, delta, source_player_id)
	local game = BALATRO.get_game and BALATRO.get_game() or nil
	if game and BALATRO.is_run_stage and BALATRO.is_run_stage() then
		local delta_value = tonumber(delta)
		local current_money = MP.get_local_money()
		local diff = money - current_money
		trace_runtime_event("team_money.remote_apply_start", {
			money = money,
			current_money = current_money,
			diff = diff,
			delta = delta,
			source_player_id = source_player_id,
		})
		if diff ~= 0 then
			if match_domain.set_applying_remote_money then
				match_domain.set_applying_remote_money(true)
			end
			local ok, err = pcall(function()
				BALATRO.ease_dollars(diff, true)
			end)
			if match_domain.set_applying_remote_money then
				match_domain.set_applying_remote_money(false)
			end
			if not ok then
				trace_runtime_event("team_money.remote_apply_failed", {
					money = money,
					diff = diff,
					source_player_id = source_player_id,
					error = tostring(err),
				})
				sendWarnMessage("Failed to apply remote money update: " .. tostring(err), "MULTIPLAYER")
				BALATRO.set_game_value("dollars", money)
			end
		end
		trace_runtime_event("team_money.remote_apply_complete", {
			money = money,
			diff = diff,
			delta = delta,
			source_player_id = source_player_id,
		})

		if delta_value and delta_value ~= 0 and MP.sync_local_money_state then
			MP.sync_local_money_state()
		end
	end

	call_state_effect("handle_money_update", money, delta, source_player_id)
end

function STATE_APPLY_RUNTIME.handle_enemy_info(update_result)
	if not update_result then
		return
	end

	if update_result.removed_self then
		recalculate_team_state()
		refresh_player_list({ force_now = true })
		return
	end

	if update_result.invalid then
		sendDebugMessage("Invalid score or hands_left", "MULTIPLAYER")
		return
	end

	local enemy = update_result.enemy
	local score = update_result.score

	apply_enemy_skip_timer_bonus(update_result.skip_delta, update_result.skips)
	apply_pvp_timer_score_gate(score)

	call_state_effect("ease_enemy_score", enemy, score)

	if update_result.life_lost then
		call_state_effect("log_life_loss_reason", "Enemy life lost", update_result)
		call_state_effect("play_enemy_life_loss_sounds")
	end

	recalculate_team_state()
	refresh_primary_enemy_view(enemy)
	request_match_lobby_info_refresh()
	refresh_player_list({ force_now = true })

	call_state_effect("juice_up_pvp_hud")
end

function STATE_APPLY_RUNTIME.handle_enemy_location(enemy)
	refresh_primary_enemy_view(enemy)
	if MP.UI and MP.UI.refresh_enemy_location_ui then
		MP.UI.refresh_enemy_location_ui()
	end
	request_match_lobby_info_refresh()
end

return STATE_APPLY_RUNTIME
