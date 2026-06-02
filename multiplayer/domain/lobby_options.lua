MP.DOMAIN = MP.DOMAIN or {}
MP.DOMAIN.LOBBY = MP.DOMAIN.LOBBY or {}

local LOBBY_DOMAIN = MP.DOMAIN.LOBBY

function LOBBY_DOMAIN.normalize_gamemode(gamemode)
	local normalized_gamemode = tostring(gamemode or "")
	if normalized_gamemode ~= "" and string.sub(normalized_gamemode, 1, 12) ~= "gamemode_mp_" then
		normalized_gamemode = "gamemode_mp_" .. normalized_gamemode
	end
	return normalized_gamemode
end

local function get_valid_gamemode(gamemode)
	local normalized_gamemode = LOBBY_DOMAIN.normalize_gamemode(gamemode)
	if MP.Gamemodes[normalized_gamemode] then
		return normalized_gamemode
	end

	return "gamemode_mp_attrition"
end

function LOBBY_DOMAIN.get_lobby_type_for_gamemode(gamemode, current_lobby_type)
	if gamemode == "gamemode_mp_coop" then
		return MP.LOBBY_TYPES.COOP
	end

	if current_lobby_type == MP.LOBBY_TYPES.COOP then
		return MP.LOBBY_TYPES.FFA
	end

	return current_lobby_type
end

local function apply_lobby_type_for_gamemode(gamemode, state)
	state = state or LOBBY_DOMAIN.ensure_state()
	return LOBBY_DOMAIN.set_lobby_type(
		LOBBY_DOMAIN.get_lobby_type_for_gamemode(gamemode, state.lobby_type),
		state
	)
end

function LOBBY_DOMAIN.set_creation_ruleset(ruleset_key, state)
	return LOBBY_DOMAIN.set_setup_field("creation_ruleset", ruleset_key, state)
end

function LOBBY_DOMAIN.get_creation_ruleset(state)
	local setup = LOBBY_DOMAIN.ensure_setup_state(state)
	return setup.creation_ruleset or MP.DEFAULT_LOBBY_CREATION_RULESET
end

function LOBBY_DOMAIN.set_creation_gamemode(gamemode_key, state)
	state = state or LOBBY_DOMAIN.ensure_state()
	local normalized_gamemode = LOBBY_DOMAIN.normalize_gamemode(gamemode_key)
	apply_lobby_type_for_gamemode(normalized_gamemode, state)
	return LOBBY_DOMAIN.set_setup_field("creation_gamemode", normalized_gamemode, state)
end

function LOBBY_DOMAIN.get_creation_gamemode(state)
	local setup = LOBBY_DOMAIN.ensure_setup_state(state)
	return setup.creation_gamemode or MP.DEFAULT_LOBBY_CREATION_GAMEMODE
end

local function build_default_config(persist_ruleset_and_gamemode, lobby_type, state)
	state = state or LOBBY_DOMAIN.ensure_state()
	local effective_lobby_type = lobby_type or state.lobby_type or nil
	local config = MP.build_lobby_option_defaults and MP.build_lobby_option_defaults(effective_lobby_type) or {}
	local default_ruleset = config.ruleset or MP.DEFAULT_LOBBY_CREATION_RULESET or "ruleset_mp_standard_ranked"
	local default_gamemode = MP.DEFAULT_LOBBY_CREATION_GAMEMODE or "gamemode_mp_attrition"
	local current_config = LOBBY_DOMAIN.ensure_config_state(state)

	config.ruleset = persist_ruleset_and_gamemode and current_config.ruleset or default_ruleset
	config.gamemode = persist_ruleset_and_gamemode and current_config.gamemode or default_gamemode
	config.weekly = nil
	return config
end

function LOBBY_DOMAIN.reset_config(persist_ruleset_and_gamemode, lobby_type, state)
	state = state or LOBBY_DOMAIN.ensure_state()
	sendDebugMessage("Resetting lobby options", "MULTIPLAYER")
	LOBBY_DOMAIN.set_config(build_default_config(persist_ruleset_and_gamemode, lobby_type, state), state)
	if LOBBY_DOMAIN.sync_run_deck_from_config then
		LOBBY_DOMAIN.sync_run_deck_from_config(state)
	end
	return state.config
end

function LOBBY_DOMAIN.prepare_config_for_creation(state)
	state = state or LOBBY_DOMAIN.ensure_state()
	local selected_ruleset = LOBBY_DOMAIN.get_creation_ruleset(state)
	local selected_gamemode = LOBBY_DOMAIN.get_creation_gamemode(state)

	LOBBY_DOMAIN.reset_config(false, nil, state)
	local config = LOBBY_DOMAIN.ensure_config_state(state)
	config.ruleset = selected_ruleset
	config.gamemode = selected_gamemode

	local ruleset = MP.Rulesets[config.ruleset]
	if not ruleset then
		return false, "ruleset_not_found"
	end

	config.gamemode = get_valid_gamemode(config.gamemode)
	LOBBY_DOMAIN.set_creation_ruleset(config.ruleset, state)
	LOBBY_DOMAIN.set_creation_gamemode(config.gamemode, state)
	config.multiplayer_jokers = ruleset.multiplayer_content
	config.forced_config = ruleset.force_lobby_options()
	config.cocktail = MP.PLATFORM.SMODS.get_config_value("cocktail")

	local hides_lives_hud = config.gamemode == "gamemode_mp_coop"

	if hides_lives_hud then
		config.starting_lives = 1
		config.disable_live_and_timer_hud = true
	else
		config.disable_live_and_timer_hud = false
	end

	if config.gamemode == "gamemode_mp_survival" then
		config.starting_lives = 1
	end

	if config.gamemode == "gamemode_mp_coop" then
		config.timer = false
	end

	if LOBBY_DOMAIN.sync_run_deck_from_config then
		LOBBY_DOMAIN.sync_run_deck_from_config(state)
	end

	return true
end

return LOBBY_DOMAIN
