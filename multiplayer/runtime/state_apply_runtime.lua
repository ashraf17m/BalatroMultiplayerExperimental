local STATE_APPLY_RUNTIME = {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function refresh_primary_enemy_view(enemy)
	if MP.UTILS and MP.UTILS.refresh_primary_enemy_view then
		MP.UTILS.refresh_primary_enemy_view(enemy)
	end
end

local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end

local function refresh_ffa_table(options)
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
		MP.UI.request_player_list_refresh()
	elseif MP.UI and MP.UI.refresh_ffa_table then
		MP.UI.refresh_ffa_table()
	end
end

local function request_lobby_main_menu_refresh()
	if MP.UI and MP.UI.request_lobby_main_menu_refresh then
		MP.UI.request_lobby_main_menu_refresh()
	elseif MP.refresh_lobby_main_menu then
		MP.refresh_lobby_main_menu()
	end
end

local function request_overlay_menu_close()
	if MP.UI and MP.UI.request_overlay_menu_close then
		MP.UI.request_overlay_menu_close()
	elseif MP.UI and MP.UI.close_active_overlay_menu then
		MP.UI.close_active_overlay_menu()
	end
end

local function request_pending_lobby_overlay_refresh()
	if MP.UI and MP.UI.request_pending_lobby_overlay_refresh then
		MP.UI.request_pending_lobby_overlay_refresh()
	elseif MP.refresh_pending_lobby_overlay then
		MP.refresh_pending_lobby_overlay()
	end
end

local function request_active_lobby_overlay_refresh()
	if MP.request_lobby_overlay_refresh and MP.request_lobby_overlay_refresh() then
		request_pending_lobby_overlay_refresh()
	end
end

local function request_pending_match_lobby_info_refresh()
	if MP.request_match_lobby_info_refresh then
		MP.request_match_lobby_info_refresh()
	elseif MP.UI and MP.UI.request_pending_match_lobby_info_refresh then
		MP.UI.request_pending_match_lobby_info_refresh()
	elseif MP.refresh_pending_match_lobby_info then
		MP.refresh_pending_match_lobby_info()
	end
end

local function request_group_options_overlay_refresh()
	if MP.UI and MP.UI.request_group_options_overlay_refresh then
		MP.UI.request_group_options_overlay_refresh()
	elseif MP.refresh_group_options_overlay then
		MP.refresh_group_options_overlay()
	end
end

local function refresh_lobby_main_menu_if_needed()
	if BALATRO.is_main_menu_stage and BALATRO.is_main_menu_stage() then
		request_lobby_main_menu_refresh()
	end
end

local function ease_lives(delta)
	if MP.UI and MP.UI.ease_lives then
		MP.UI.ease_lives(delta)
	end
end

local LIFE_LOSS_REASON_LABELS = {
	pvp_result = "PvP result",
	round_failed_death_on_round_loss = "failed blind with life-loss enabled",
	team_coop_blind_failed = "team blind failed",
	ante_timer_expired = "ante timer expired",
	speedlatro_client_timeout = "Speedlatro timeout",
}

local function emit_life_loss_log(message)
	if type(sendWarnMessage) == "function" then
		sendWarnMessage(message, "MULTIPLAYER")
	elseif type(sendDebugMessage) == "function" then
		sendDebugMessage(message, "MULTIPLAYER")
	elseif type(sendTraceMessage) == "function" then
		sendTraceMessage(message, "MULTIPLAYER")
	end
end

local function log_life_loss_reason(subject, update_result, options)
	if not (update_result and update_result.life_lost) then
		return
	end

	local reason = update_result.life_loss_reason
	if not reason and not (options and options.log_missing_reason) then
		return
	end

	local label = reason and (LIFE_LOSS_REASON_LABELS[reason] or tostring(reason)) or "reason not provided by server"
	local previous_lives = update_result.server_previous_lives or update_result.previous_lives
	local lives = update_result.lives
	local details = ""
	if previous_lives ~= nil and lives ~= nil then
		details = " (" .. tostring(previous_lives) .. " -> " .. tostring(lives) .. ")"
	end
	local message = tostring(subject or "Life lost") .. ": " .. label .. details

	emit_life_loss_log(message)
	trace_runtime_event(reason and "life_loss.reason" or "life_loss.missing_reason", {
		subject = subject,
		reason = reason,
		previous_lives = previous_lives,
		lives = lives,
	})
end

local function ease_enemy_score(enemy, score)
	local score_shared = MP.UI and MP.UI.PLAYERS_HUD_SHARED or nil
	if score_shared and score_shared.ease_standings_score_number then
		local cooperative_score_blind = (MP.is_team_cooperative_blind and MP.is_team_cooperative_blind())
			or (MP.is_coop_blind and MP.is_coop_blind())
		score_shared.ease_standings_score_number(enemy.score, score, {
			delay = cooperative_score_blind and 0.5 or score_shared.PVP_SCORE_EASE_DELAY,
		})
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

	request_pending_match_lobby_info_refresh()

	if snapshot_result.previous_lobby_type ~= snapshot_result.lobby_type then
		request_group_options_overlay_refresh()
	end

	if MP.recalculate_team_state then
		MP.recalculate_team_state()
	end
	refresh_primary_enemy_view()
	refresh_ffa_table()
end

function STATE_APPLY_RUNTIME.handle_lobby_player_joined(snapshot_result)
	STATE_APPLY_RUNTIME.handle_lobby_snapshot(snapshot_result)
end

function STATE_APPLY_RUNTIME.handle_lobby_player_updated(snapshot_result)
	STATE_APPLY_RUNTIME.handle_lobby_snapshot(snapshot_result)
end

function STATE_APPLY_RUNTIME.handle_lobby_team_assignment()
	refresh_lobby_main_menu_if_needed()
	request_active_lobby_overlay_refresh()

	if MP.recalculate_team_state then
		MP.recalculate_team_state()
	end
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
		ease_lives(update_result.lives - update_result.previous_lives)
		log_life_loss_reason("Life lost", update_result, { log_missing_reason = true })
		local blind = BALATRO.get_current_blind and BALATRO.get_current_blind() or nil
		if MP.LOBBY.config.no_gold_on_round_loss and blind and blind.dollars then
			blind.dollars = 0
		end
	end

	if MP.recalculate_team_state then
		MP.recalculate_team_state()
	end
	request_pending_match_lobby_info_refresh()
	refresh_ffa_table()
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
			if MP.set_match_applying_remote_money then
				MP.set_match_applying_remote_money(true)
			end
			local ok, err = pcall(function()
				ease_dollars(diff, true)
			end)
			if MP.set_match_applying_remote_money then
				MP.set_match_applying_remote_money(false)
			end
			if not ok then
				trace_runtime_event("team_money.remote_apply_failed", {
					money = money,
					diff = diff,
					source_player_id = source_player_id,
					error = tostring(err),
				})
				sendWarnMessage("Failed to apply remote money update: " .. tostring(err), "MULTIPLAYER")
				game.dollars = money
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

	if MP.handle_team_money_transfer_money_update then
		MP.handle_team_money_transfer_money_update(money, delta, source_player_id)
	end
end

function STATE_APPLY_RUNTIME.handle_enemy_info(update_result)
	if not update_result then
		return
	end

	if update_result.removed_self then
		if MP.recalculate_team_state then
			MP.recalculate_team_state()
		end
		refresh_ffa_table({ force_now = true })
		return
	end

	if update_result.invalid then
		sendDebugMessage("Invalid score or hands_left", "MULTIPLAYER")
		return
	end

	local enemy = update_result.enemy
	local score = update_result.score

	ease_enemy_score(enemy, score)

	if update_result.life_lost then
		log_life_loss_reason("Enemy life lost", update_result)
		BALATRO.play_sound("holo1", 0.865, 0.9)
		BALATRO.play_sound("gong", 0.765, 0.4)
	end

	if MP.recalculate_team_state then
		MP.recalculate_team_state()
	end
	refresh_primary_enemy_view(enemy)
	request_pending_match_lobby_info_refresh()
	refresh_ffa_table({ force_now = true })

	if MP.UI and MP.UI.juice_up_pvp_hud then
		MP.UI.juice_up_pvp_hud()
	end
end

function STATE_APPLY_RUNTIME.handle_enemy_location(enemy)
	refresh_primary_enemy_view(enemy)
	request_pending_match_lobby_info_refresh()
end

return STATE_APPLY_RUNTIME
