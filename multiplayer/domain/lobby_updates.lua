MP.DOMAIN = MP.DOMAIN or {}
MP.DOMAIN.LOBBY = MP.DOMAIN.LOBBY or {}

local LOBBY_DOMAIN = MP.DOMAIN.LOBBY

local function normalize_team_id(team_id)
	return math.max(1, math.min(MP.MAX_TEAMS, tonumber(team_id) or 1))
end

local function normalize_lobby_option_value(option_key, option_value)
	if option_key == "ruleset" then
		if not MP.Rulesets[option_value] then
			return nil, { type = "ruleset_not_found" }
		end

		local disabled_reason = MP.Rulesets[option_value].is_disabled()
		if disabled_reason then
			return nil, { type = "ruleset_disabled", reason = disabled_reason }
		end

		return option_value
	end

	if option_key == "gamemode" then
		return LOBBY_DOMAIN.normalize_gamemode(option_value)
	end

	local normalized_value = option_value
	if normalized_value == "true" then
		normalized_value = true
	elseif normalized_value == "false" then
		normalized_value = false
	end

	if MP.LOBBY_OPTION_NUMERIC_KEYS and MP.LOBBY_OPTION_NUMERIC_KEYS[option_key] then
		normalized_value = tonumber(normalized_value)
	end

	return normalized_value
end

function LOBBY_DOMAIN.apply_option_update(options, state)
	state = state or LOBBY_DOMAIN.ensure_state()
	local normalized_options = {}
	local config = LOBBY_DOMAIN.ensure_config_state(state)
	local different_decks_before = config.different_decks
	local shared_deck_changed = false

	for option_key, option_value in pairs(options or {}) do
		local normalized_value, error_details = normalize_lobby_option_value(option_key, option_value)
		if error_details then
			return false, error_details
		end
		normalized_options[option_key] = normalized_value
	end

	for option_key, option_value in pairs(normalized_options) do
		config[option_key] = option_value
		if MP.SHARED_LOBBY_DECK_OPTION_KEYS and MP.SHARED_LOBBY_DECK_OPTION_KEYS[option_key] then
			shared_deck_changed = true
		end
		if MP.UI.update_lobby_option_toggle then
			MP.UI.update_lobby_option_toggle(option_key)
		end
	end

	if (not config.different_decks) and (shared_deck_changed or different_decks_before ~= config.different_decks) then
		if LOBBY_DOMAIN.sync_run_deck_from_config then
			LOBBY_DOMAIN.sync_run_deck_from_config(state)
		end
	end

	return true, {
		different_decks_changed = (different_decks_before ~= config.different_decks),
		shared_deck_changed = shared_deck_changed,
	}
end

function LOBBY_DOMAIN.update_run_deck(deck_changes, state)
	state = state or LOBBY_DOMAIN.ensure_state()

	local run_deck = LOBBY_DOMAIN.get_run_deck(state) or LOBBY_DOMAIN.build_initial_run_deck_state()
	for key, value in pairs(deck_changes or {}) do
		run_deck[key] = value
	end

	state.run_deck = run_deck
	LOBBY_DOMAIN.ensure_run_deck_state(state)
	return run_deck
end

function LOBBY_DOMAIN.update_player_team(player_id, team_id, state)
	local normalized_team = normalize_team_id(team_id)

	for _, player in ipairs(LOBBY_DOMAIN.get_players(state)) do
		if player.id == player_id then
			player.team = normalized_team
			player.team_name = MP.TEAM_NAMES[normalized_team] or "TEAM"
			return player, normalized_team
		end
	end

	return nil, normalized_team
end

return LOBBY_DOMAIN
