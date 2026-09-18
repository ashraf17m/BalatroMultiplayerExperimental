local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function create_lives_hud_text()
	return DynaText({
		string = { { ref_table = MP.GAME, ref_value = "lives" } },
		colours = { G.C.IMPORTANT },
		shadow = true,
		font = G.LANGUAGES["en-us"].font,
		scale = 0.8,
	})
end

local function should_show_lives_hud(options)
	if options and options.force then
		return true
	end

	local lobby_config = MP.LOBBY and MP.LOBBY.config or nil
	local gamemode = lobby_config and lobby_config.gamemode or nil
	if gamemode == "gamemode_mp_coop" or gamemode == "coop" then
		return false
	end
	if MP.is_coop_gamemode and MP.is_coop_gamemode() then
		return false
	end
	if lobby_config and lobby_config.disable_live_and_timer_hud then
		return false
	end
	if MP.GAME and MP.GAME.disable_live_and_timer_hud then
		return false
	end
	return true
end

function MP.UI.refresh_lives_hud_binding(options)
	options = options or {}

	if not should_show_lives_hud(options) then
		return false
	end

	if
		not (
			MP
			and MP.GAME
			and G
			and G.HUD
			and G.HUD.get_UIE_by_ID
			and G.hand_text_area
			and DynaText
		)
	then
		return false
	end

	local hud_ante = G.HUD:get_UIE_by_ID("hud_ante")
	if not (hud_ante and hud_ante.children and hud_ante.children[1] and hud_ante.children[2]) then
		return false
	end

	local label_container = hud_ante.children[1].children
	local label = label_container and label_container[1]
	if label and label.config then
		label.config.text = localize("k_lives")
	end

	local value_container = hud_ante.children[2].children
	local lives_UI = value_container and value_container[1]
	if not (lives_UI and lives_UI.config) then
		return false
	end

	MP.UI.UTILS.replace_config_object(lives_UI, create_lives_hud_text(), {
		recalculate_object = false,
		recalculate_ui_box = false,
	})
	G.hand_text_area.ante = lives_UI

	value_container[2] = nil
	value_container[3] = nil
	value_container[4] = nil

	if options.recalculate ~= false and G.HUD.recalculate then
		G.HUD:recalculate()
	end

	return true
end

function MP.UI.ease_lives(mod)
	BALATRO.queue_event({
		trigger = "immediate",
		func = function()
			if not G.hand_text_area then return end

			if MP.LOBBY.config.disable_live_and_timer_hud then
				return true
			end

			if MP.UI.refresh_lives_hud_binding then
				MP.UI.refresh_lives_hud_binding({ recalculate = false })
			end

			local lives_UI = G.hand_text_area.ante
			if not (lives_UI and lives_UI.config and lives_UI.config.object) then return true end

			mod = mod or 0
			local text = "+"
			local col = G.C.IMPORTANT
			if mod < 0 then
				text = "-"
				col = G.C.RED
			end
			if lives_UI.config.object.update then
				lives_UI.config.object:update()
			end
			if G.HUD and G.HUD.recalculate then
				G.HUD:recalculate()
			end
			attention_text({
				text = text .. tostring(math.abs(mod)),
				scale = 1,
				hold = 0.7,
				cover = lives_UI.parent,
				cover_colour = col,
				align = "cm",
			})
			play_sound("highlight2", 0.685, 0.2)
			play_sound("generic1")
			return true
		end,
	})
end

function MP.UI.show_asteroid_hand_level_up()
	local hand_type = MP.UTILS.get_highest_level_poker_hand(function(key)
		return MP.PLATFORM.SMODS.is_poker_hand_visible(key)
	end)
	MP.PLATFORM.SMODS.upgrade_poker_hands({ hands = hand_type, level_up = -1 })
end

-- ============================================================================
-- SECTION 2: STATE APPLY EFFECTS
-- (Consolidated from state_apply_effects.lua)
-- ============================================================================

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
	local delay = cooperative_score_blind and 0.5 or (score_shared.PVP_SCORE_EASE_DELAY or 0.8)
	score_shared.ease_standings_score_number(enemy.score, score, { delay = delay })
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
