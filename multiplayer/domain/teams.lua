MP.DOMAIN = MP.DOMAIN or {}
MP.DOMAIN.TEAMS = MP.DOMAIN.TEAMS or {}

local TEAMS_DOMAIN = MP.DOMAIN.TEAMS
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function get_normalized_score_text(score_value)
	if type(score_value) == "string" then
		return string.gsub(score_value, ",", "")
	end

	local score_text = tostring(to_big(score_value or 0))
	if string.match(score_text, "[eE]") == nil and string.match(score_text, "[.]") then
		score_text = string.sub(string.gsub(score_text, "%.", ","), 1, -3)
	end
	return string.gsub(score_text, ",", "")
end

local function get_local_score_text_from_context(is_cooperative_blind, chips)
	if MP.GAME and MP.GAME.force_zero_round_score then
		return "0"
	end

	if is_cooperative_blind and chips ~= nil then
		return get_normalized_score_text(chips)
	end

	return get_normalized_score_text((MP.GAME and MP.GAME.score_text) or 0)
end

local function refresh_shared_score_ui_if_changed(previous_team_score_text, previous_team_lives)
	if (BALATRO.is_game_over_or_win and BALATRO.is_game_over_or_win()) or MP.GAME.won then
		return
	end

	if previous_team_score_text ~= MP.GAME.team_score_text or previous_team_lives ~= MP.GAME.team_lives then
		if MP.UI and MP.UI.request_shared_score_refresh then
			MP.UI.request_shared_score_refresh()
		end
	end
end

local function uses_global_coop_blind()
	return MP.is_coop_blind and MP.is_coop_blind()
end

local function uses_cooperative_score_context()
	return TEAMS_DOMAIN.is_cooperative_blind() or uses_global_coop_blind()
end

local function get_blind_choice_internal()
	return MP.BLIND_CHOICE_INTERNAL or nil
end

function TEAMS_DOMAIN.get_current_blind_row()
	if not (BALATRO.get_game and BALATRO.get_game()) then
		return nil
	end

	local blind_on_deck = BALATRO.get_game_value and BALATRO.get_game_value("blind_on_deck") or nil
	if blind_on_deck then
		return blind_on_deck
	end

	local location = tostring((MP.GAME and MP.GAME.location) or "")
	local row = string.match(location, "^loc_playing%-(.+)$")
	if row and row ~= "" then
		return row
	end

	row = string.match(location, "^loc_ready_for_team_row%-(.+)$")
	if row and row ~= "" then
		return row
	end

	row = string.match(location, "^loc_ready_to_skip_for_team_row%-(.+)$")
	if row and row ~= "" then
		return row
	end

	return MP.GAME and MP.GAME.skip_ready_blind_row or nil
end

function TEAMS_DOMAIN.resolve_lobby_blinds_for_ante(ante)
	if not (MP.LOBBY and MP.LOBBY.code and MP.LOBBY.config and MP.Gamemodes) then
		return nil, nil, nil, {}
	end

	local gamemode = MP.Gamemodes[MP.LOBBY.config.gamemode]
	if not gamemode or not gamemode.get_blinds_by_ante then
		return nil, nil, nil, {}
	end

	local round_resets = BALATRO.get_round_resets and BALATRO.get_round_resets() or nil
	local previous_pvp_blind_choices = round_resets and round_resets.pvp_blind_choices or nil
	local resolved_pvp_blind_choices = {}

	if round_resets then
		round_resets.pvp_blind_choices = resolved_pvp_blind_choices
	end

	local ok, small_choice, big_choice, boss_choice = pcall(function()
		return gamemode:get_blinds_by_ante(ante)
	end)

	if round_resets then
		round_resets.pvp_blind_choices = previous_pvp_blind_choices
	end

	if not ok then
		sendWarnMessage(
			"Failed to resolve lobby blinds for ante " .. tostring(ante) .. ": " .. tostring(small_choice),
			"MULTIPLAYER"
		)
		return nil, nil, nil, {}
	end

	return small_choice, big_choice, boss_choice, resolved_pvp_blind_choices
end

function TEAMS_DOMAIN.is_cooperative_blind()
	if not MP.is_teams_mode() or not (BALATRO.get_game and BALATRO.get_game()) then
		return false
	end
	if MP.is_survival_gamemode and MP.is_survival_gamemode() then
		return false
	end

	local row = TEAMS_DOMAIN.get_current_blind_row()
	if not row then
		return false
	end

	local blind_choice = get_blind_choice_internal()
	if blind_choice and blind_choice.is_teams_cooperative_row then
		return blind_choice.is_teams_cooperative_row(row)
	end

	local round_resets = BALATRO.get_round_resets and BALATRO.get_round_resets() or nil
	local blind_choices = round_resets and round_resets.pvp_blind_choices or nil
	if blind_choices and blind_choices[row] ~= nil then
		return not blind_choices[row]
	end

	if round_resets and round_resets.ante then
		local _, _, _, resolved_pvp_blind_choices = TEAMS_DOMAIN.resolve_lobby_blinds_for_ante(
			round_resets.ante
		)
		if type(resolved_pvp_blind_choices) == "table" and resolved_pvp_blind_choices[row] ~= nil then
			return not resolved_pvp_blind_choices[row]
		end
	end

	return false
end

function TEAMS_DOMAIN.get_local_score_text()
	local chips = BALATRO.get_game_value and BALATRO.get_game_value("chips") or nil
	local is_cooperative_blind = uses_cooperative_score_context()
	return get_local_score_text_from_context(is_cooperative_blind, chips)
end

local function get_relevant_shared_score(is_global_coop, team_id)
	local total_score = MP.INSANE_INT.from_string(TEAMS_DOMAIN.get_local_score_text())

	for _, enemy in pairs(MP.GAME and MP.GAME.enemies or {}) do
		if enemy and enemy.in_match ~= false and (is_global_coop or (team_id and enemy.team == team_id)) then
			local enemy_score = enemy.synced_score or enemy.score or MP.INSANE_INT.empty()
			total_score = MP.INSANE_INT.add(total_score, enemy_score)
		end
	end

	return total_score
end

function TEAMS_DOMAIN.get_cooperative_blind_score()
	if not MP.GAME then
		return nil
	end

	local is_global_coop = uses_global_coop_blind()
	if is_global_coop then
		return get_relevant_shared_score(true)
	end

	if not TEAMS_DOMAIN.is_cooperative_blind() then
		return nil
	end

	local team_id = MP.get_self_team_id and MP.get_self_team_id() or nil
	if not team_id then
		return MP.INSANE_INT.from_string(TEAMS_DOMAIN.get_local_score_text())
	end

	return get_relevant_shared_score(false, team_id)
end

function TEAMS_DOMAIN.get_cooperative_blind_target()
	if not (MP.GAME and uses_cooperative_score_context()) then
		return nil
	end

	if MP.GAME.coop_blind_target_chips ~= nil then
		return MP.GAME.coop_blind_target_chips
	end
	if MP.GAME.coop_blind_server_target_chips ~= nil then
		return MP.GAME.coop_blind_server_target_chips
	end

	local blind = BALATRO.get_current_blind and BALATRO.get_current_blind() or nil
	if blind and blind.mp_coop_scaled_chips ~= nil then
		return blind.mp_coop_scaled_chips
	end
	return blind and blind.chips or nil
end

function TEAMS_DOMAIN.reset_round_score_state()
	if not MP.GAME then
		return
	end

	MP.GAME.score_text = "0"
	MP.GAME.score_display = MP.INSANE_INT.empty()
	MP.GAME.shared_score_text = "0"
	MP.GAME.team_score = MP.INSANE_INT.empty()
	MP.GAME.team_score_text = "0"
	MP.GAME.live_team_local_score_cache = nil
	MP.GAME.force_zero_round_score = true

	local round_hands = nil
	local round_resets = BALATRO.get_round_resets and BALATRO.get_round_resets() or nil
	if round_resets and round_resets.hands then
		round_hands = round_resets.hands
	end

	for _, enemy in pairs(MP.GAME.enemies or {}) do
		if enemy then
			enemy.score = MP.INSANE_INT.empty()
			enemy.synced_score = MP.INSANE_INT.empty()
			enemy.score_text = "0"
			if round_hands ~= nil then
				enemy.hands = round_hands
			end
		end
	end
end

function TEAMS_DOMAIN.refresh_live_score()
	if not MP.GAME then
		return
	end

	local is_cooperative_blind = uses_cooperative_score_context()
	if not is_cooperative_blind then
		MP.GAME.live_team_local_score_cache = nil
		return
	end

	local chips = BALATRO.get_game_value and BALATRO.get_game_value("chips") or nil
	if MP.GAME.force_zero_round_score and chips ~= nil then
		local current_local_score = get_normalized_score_text(chips)
		if current_local_score == "0" then
			MP.GAME.force_zero_round_score = false
		end
	end

	local live_local_score = get_local_score_text_from_context(is_cooperative_blind, chips)
	if MP.GAME.live_team_local_score_cache == live_local_score then
		return
	end

	MP.GAME.live_team_local_score_cache = live_local_score
	TEAMS_DOMAIN.recalculate_state()
end

function TEAMS_DOMAIN.recalculate_state()
	if not MP.GAME then
		return
	end

	local previous_team_score_text = MP.GAME.team_score_text or "0"
	local previous_team_lives = MP.GAME.team_lives

	if uses_global_coop_blind() then
		local total_score = TEAMS_DOMAIN.get_cooperative_blind_score() or MP.INSANE_INT.empty()

		MP.GAME.team_score = total_score
		MP.GAME.team_score_text = MP.INSANE_INT.to_string(total_score)
		MP.GAME.team_lives = MP.GAME.lives or MP.LOBBY.config.starting_lives or 0
		MP.GAME.shared_score_text = MP.GAME.team_score_text
		refresh_shared_score_ui_if_changed(previous_team_score_text, previous_team_lives)
		return
	end

	local team_id = MP.get_self_team_id()
	if not team_id then
		MP.GAME.team_score = MP.INSANE_INT.empty()
		MP.GAME.team_score_text = "0"
		MP.GAME.team_lives = MP.GAME.lives or 0
		refresh_shared_score_ui_if_changed(previous_team_score_text, previous_team_lives)
		return
	end

	local total_score = get_relevant_shared_score(false, team_id)
	local shared_lives = MP.GAME.lives or MP.LOBBY.config.starting_lives or 0

	for _, enemy in pairs(MP.GAME and MP.GAME.enemies or {}) do
		if enemy and enemy.in_match ~= false and enemy.team == team_id then
			if enemy.team_lives ~= nil then
				shared_lives = enemy.team_lives
			elseif enemy.lives ~= nil then
				shared_lives = enemy.lives
			end
		end
	end

	MP.GAME.team_score = total_score
	MP.GAME.team_score_text = MP.INSANE_INT.to_string(total_score)
	MP.GAME.team_lives = shared_lives
	if TEAMS_DOMAIN.is_cooperative_blind() then
		MP.GAME.shared_score_text = MP.GAME.team_score_text
	end

	refresh_shared_score_ui_if_changed(previous_team_score_text, previous_team_lives)
end

return TEAMS_DOMAIN
