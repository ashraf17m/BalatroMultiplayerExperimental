MP.UI = MP.UI or {}
MP.UI.STATE_APPLY_EFFECTS = MP.UI.STATE_APPLY_EFFECTS or {}

local effects = MP.UI.STATE_APPLY_EFFECTS
local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end

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

function effects.ease_lives(delta)
	if MP.UI and MP.UI.ease_lives then
		MP.UI.ease_lives(delta)
	end
end

function effects.log_life_loss_reason(subject, update_result, options)
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

function effects.ease_enemy_score(enemy, score)
	local score_shared = MP.UI and MP.UI.PLAYERS_HUD_SHARED or nil
	if not (score_shared and score_shared.ease_standings_score_number) then
		return
	end

	local teams_domain = MP.DOMAIN and MP.DOMAIN.TEAMS or {}
	local cooperative_score_blind = (teams_domain.is_cooperative_blind and teams_domain.is_cooperative_blind())
		or (MP.is_coop_blind and MP.is_coop_blind())
	score_shared.ease_standings_score_number(enemy.score, score, {
		delay = cooperative_score_blind and 0.5 or score_shared.PVP_SCORE_EASE_DELAY,
	})
end

function effects.handle_money_update(money, delta, source_player_id)
	local team_money_ui = MP.UI and MP.UI.TEAM_MONEY or nil
	if team_money_ui and team_money_ui.handle_money_update then
		team_money_ui.handle_money_update(money, delta, source_player_id)
	end
end

function effects.play_enemy_life_loss_sounds()
	local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
	if BALATRO.play_sound then
		BALATRO.play_sound("holo1", 0.865, 0.9)
		BALATRO.play_sound("gong", 0.765, 0.4)
	end
end

function effects.juice_up_pvp_hud()
	if MP.UI and MP.UI.juice_up_pvp_hud then
		MP.UI.juice_up_pvp_hud()
	end
end
