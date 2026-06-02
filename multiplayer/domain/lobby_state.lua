MP.DOMAIN = MP.DOMAIN or {}
MP.DOMAIN.LOBBY = MP.DOMAIN.LOBBY or {}

local LOBBY_DOMAIN = MP.DOMAIN.LOBBY

local function set_state_field(field, value, state)
	state = state or LOBBY_DOMAIN.ensure_state()
	state[field] = value
	return state[field]
end

local function set_boolean_state_field(field, value, state)
	return set_state_field(field, not not value, state)
end

local function set_client_field(field, value, state)
	local client = LOBBY_DOMAIN.ensure_client_state(state)
	client[field] = value
	return client[field]
end

local function set_defaulted_client_field(field, value, default_value, state)
	if value == nil then
		value = default_value
	end
	return set_client_field(field, value, state)
end

local function set_boolean_client_field(field, value, state)
	return set_client_field(field, not not value, state)
end

function LOBBY_DOMAIN.set_setup_field(field, value, state)
	local setup = LOBBY_DOMAIN.ensure_setup_state(state)
	setup[field] = value
	return setup[field]
end

local function set_boolean_setup_field(field, value, state)
	return LOBBY_DOMAIN.set_setup_field(field, not not value, state)
end

function LOBBY_DOMAIN.build_deck_state(source)
	source = source or {}

	return {
		back = source.back or "Red Deck",
		sleeve = source.sleeve or "sleeve_casl_none",
		stake = source.stake or 1,
		challenge = source.challenge or "",
		cocktail = source.cocktail or "",
	}
end

local function build_initial_client_state()
	return {
		connected = false,
		username = "Guest",
		blind_col = 1,
		pending_lobby_ready = nil,
	}
end

local function build_initial_setup_state()
	return {
		temp_code = "",
		temp_seed = "",
		creation_ruleset = MP.DEFAULT_LOBBY_CREATION_RULESET,
		creation_gamemode = MP.DEFAULT_LOBBY_CREATION_GAMEMODE,
		fetched_weekly = nil,
		ruleset_preview = false,
		gamemode_preview = false,
	}
end

function LOBBY_DOMAIN.build_initial_run_deck_state()
	return LOBBY_DOMAIN.build_deck_state()
end

function LOBBY_DOMAIN.build_initial_state()
	local run_deck = LOBBY_DOMAIN.build_initial_run_deck_state()

	return {
		code = nil,
		lobby_type = "",
		config = {},
		run_deck = run_deck,
		client = build_initial_client_state(),
		setup = build_initial_setup_state(),
		players = {},
		is_host = false,
		match_in_progress = false,
	}
end

function LOBBY_DOMAIN.ensure_client_state(state)
	state = state or LOBBY_DOMAIN.ensure_state()
	state.client = state.client or build_initial_client_state()
	return state.client
end

function LOBBY_DOMAIN.ensure_setup_state(state)
	state = state or LOBBY_DOMAIN.ensure_state()
	state.setup = state.setup or build_initial_setup_state()
	return state.setup
end

function LOBBY_DOMAIN.ensure_config_state(state)
	state = state or LOBBY_DOMAIN.ensure_state()
	state.config = state.config or {}
	return state.config
end

function LOBBY_DOMAIN.ensure_state()
	if not MP.LOBBY then
		MP.LOBBY = LOBBY_DOMAIN.build_initial_state()
	end

	return MP.LOBBY
end

function LOBBY_DOMAIN.initialize_runtime_state()
	MP.LOBBY = LOBBY_DOMAIN.build_initial_state()
	return MP.LOBBY
end

function LOBBY_DOMAIN.set_players(players, state)
	return set_state_field("players", players or {}, state)
end

function LOBBY_DOMAIN.get_players(state)
	state = state or LOBBY_DOMAIN.ensure_state()
	return state.players or {}
end

function LOBBY_DOMAIN.set_host_state(is_host, state)
	return set_boolean_state_field("is_host", is_host, state)
end

function LOBBY_DOMAIN.set_match_in_progress(is_in_progress, state)
	return set_boolean_state_field("match_in_progress", is_in_progress, state)
end

function LOBBY_DOMAIN.set_lobby_type(lobby_type, state)
	return set_state_field("lobby_type", lobby_type or "", state)
end

function LOBBY_DOMAIN.set_config(config, state)
	return set_state_field("config", config or {}, state)
end

function LOBBY_DOMAIN.set_config_field(key, value, state)
	local config = LOBBY_DOMAIN.ensure_config_state(state)
	config[key] = value
	return config[key]
end

function LOBBY_DOMAIN.clear_config_selection(state)
	local config = LOBBY_DOMAIN.ensure_config_state(state)
	config.ruleset = nil
	config.gamemode = nil
	return config
end

function LOBBY_DOMAIN.set_pending_ready(is_ready, state)
	state = state or LOBBY_DOMAIN.ensure_state()
	state.client = LOBBY_DOMAIN.ensure_client_state(state)

	if is_ready == nil then
		state.client.pending_lobby_ready = nil
	else
		state.client.pending_lobby_ready = not not is_ready
	end

	return state.client.pending_lobby_ready
end

function LOBBY_DOMAIN.set_client_username(username, state)
	return set_defaulted_client_field("username", username, "Guest", state)
end

function LOBBY_DOMAIN.set_client_connected(is_connected, state)
	return set_boolean_client_field("connected", is_connected, state)
end

function LOBBY_DOMAIN.set_client_blind_col(blind_col, state)
	if MP.UTILS and MP.UTILS.clamp_blind_col then
		blind_col = MP.UTILS.clamp_blind_col(blind_col)
	end
	return set_defaulted_client_field("blind_col", blind_col, 1, state)
end

function LOBBY_DOMAIN.set_setup_temp_code(temp_code, state)
	return LOBBY_DOMAIN.set_setup_field("temp_code", tostring(temp_code or ""), state)
end

function LOBBY_DOMAIN.set_setup_fetched_weekly(fetched_weekly, state)
	return LOBBY_DOMAIN.set_setup_field("fetched_weekly", fetched_weekly, state)
end

function LOBBY_DOMAIN.set_setup_ruleset_preview(is_preview, state)
	return set_boolean_setup_field("ruleset_preview", is_preview, state)
end

function LOBBY_DOMAIN.set_setup_gamemode_preview(is_preview, state)
	return set_boolean_setup_field("gamemode_preview", is_preview, state)
end

return LOBBY_DOMAIN
