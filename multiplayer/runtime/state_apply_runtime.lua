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

local function request_group_options_overlay_refresh()
	if MP.UI and MP.UI.request_group_options_overlay_refresh then
		return MP.UI.request_group_options_overlay_refresh()
	end
	return false
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

	if snapshot_result.previous_lobby_type ~= snapshot_result.lobby_type then
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
	request_match_lobby_info_refresh()
end

return STATE_APPLY_RUNTIME
