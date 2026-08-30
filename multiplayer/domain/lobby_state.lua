MP.DOMAIN = MP.DOMAIN or {}
MP.DOMAIN.LOBBY = MP.DOMAIN.LOBBY or {}

local LOBBY_DOMAIN = MP.DOMAIN.LOBBY
local DEFAULT_LOBBY_ACCESS_MODE = "private"
local LOBBY_ACCESS_MODE_CONFIG_PATH = { "lobby", "creation_access_mode" }
local CREATION_RULESET_CONFIG_PATH = { "lobby", "creation_ruleset" }
local CREATION_GAMEMODE_CONFIG_PATH = { "lobby", "creation_gamemode" }
local VALID_LOBBY_ACCESS_MODES = {
	public = true,
	ask_first = true,
	private = true,
}

local function normalize_lobby_access_mode(access_mode)
	access_mode = tostring(access_mode or "")
	if VALID_LOBBY_ACCESS_MODES[access_mode] then
		return access_mode
	end
	return DEFAULT_LOBBY_ACCESS_MODE
end

local function get_saved_config_value(path, default)
	local smods = MP.PLATFORM and MP.PLATFORM.SMODS or nil
	if smods and type(smods.get_config_value) == "function" then
		local saved = smods.get_config_value(path, default, MP)
		if type(saved) == "string" and saved ~= "" then
			return saved
		end
	end
	return default
end

local function get_saved_lobby_access_mode()
	return normalize_lobby_access_mode(get_saved_config_value(
		LOBBY_ACCESS_MODE_CONFIG_PATH,
		DEFAULT_LOBBY_ACCESS_MODE
	))
end

local function save_lobby_access_mode(access_mode)
	local smods = MP.PLATFORM and MP.PLATFORM.SMODS or nil
	if not (smods and type(smods.set_config_value) == "function") then
		return false
	end

	smods.set_config_value(LOBBY_ACCESS_MODE_CONFIG_PATH, access_mode, MP)
	if MP.save_current_config then
		return MP.save_current_config()
	end
	return true
end

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
		blind_target_scale = nil,
		pending_lobby_ready = nil,
	}
end

local function build_initial_setup_state()
	return {
		temp_code = "",
		temp_seed = "",
		creation_ruleset = get_saved_config_value(
			CREATION_RULESET_CONFIG_PATH,
			MP.DEFAULT_LOBBY_CREATION_RULESET
		),
		creation_gamemode = get_saved_config_value(
			CREATION_GAMEMODE_CONFIG_PATH,
			MP.DEFAULT_LOBBY_CREATION_GAMEMODE
		),
		creation_access_mode = get_saved_lobby_access_mode(),
		browser_lobbies = {},
		browser_pending = false,
		pending_join_request = nil,
		pending_join_requests = {},
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
		is_saved_coop_restore = false,
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

function LOBBY_DOMAIN.set_saved_coop_restore(is_saved_coop_restore, state)
	return set_boolean_state_field("is_saved_coop_restore", is_saved_coop_restore, state)
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

function LOBBY_DOMAIN.normalize_lobby_access_mode(access_mode)
	return normalize_lobby_access_mode(access_mode)
end

function LOBBY_DOMAIN.set_creation_access_mode(access_mode, state)
	local normalized_access_mode = LOBBY_DOMAIN.normalize_lobby_access_mode(access_mode)
	local saved_access_mode = LOBBY_DOMAIN.set_setup_field(
		"creation_access_mode",
		normalized_access_mode,
		state
	)
	save_lobby_access_mode(saved_access_mode)
	return saved_access_mode
end

function LOBBY_DOMAIN.get_creation_access_mode(state)
	state = state or LOBBY_DOMAIN.ensure_state()
	local setup = LOBBY_DOMAIN.ensure_setup_state(state)
	return LOBBY_DOMAIN.normalize_lobby_access_mode(setup.creation_access_mode)
end

function LOBBY_DOMAIN.set_browser_lobbies(lobbies, state)
	return LOBBY_DOMAIN.set_setup_field("browser_lobbies", type(lobbies) == "table" and lobbies or {}, state)
end

function LOBBY_DOMAIN.get_browser_lobbies(state)
	state = state or LOBBY_DOMAIN.ensure_state()
	local setup = LOBBY_DOMAIN.ensure_setup_state(state)
	return type(setup.browser_lobbies) == "table" and setup.browser_lobbies or {}
end

function LOBBY_DOMAIN.set_browser_pending(is_pending, state)
	return set_boolean_setup_field("browser_pending", is_pending, state)
end

function LOBBY_DOMAIN.is_browser_pending(state)
	state = state or LOBBY_DOMAIN.ensure_state()
	local setup = LOBBY_DOMAIN.ensure_setup_state(state)
	return not not setup.browser_pending
end

local function get_real_time()
	if G and G.TIMERS and G.TIMERS.REAL then
		return G.TIMERS.REAL
	end
	if love and love.timer and love.timer.getTime then
		return love.timer.getTime()
	end
	return os.clock()
end

local function normalize_join_request_timer(request)
	if type(request) ~= "table" then
		return request
	end

	local expires_in_ms = tonumber(request.expiresInMs or request.expires_in_ms)
	if expires_in_ms and expires_in_ms == expires_in_ms and expires_in_ms >= 0 then
		request.local_expires_at = get_real_time() + (expires_in_ms / 1000)
	elseif request.expiresAt or request.expires_at then
		local expires_at_seconds = (tonumber(request.expiresAt or request.expires_at) or 0) / 1000
		request.local_expires_at = get_real_time() + math.max(0, expires_at_seconds - os.time())
	else
		request.local_expires_at = get_real_time() + 10
	end

	return request
end

function LOBBY_DOMAIN.get_join_request_remaining_seconds(request)
	if type(request) ~= "table" then
		return 0
	end

	local remaining = (tonumber(request.local_expires_at) or 0) - get_real_time()
	return math.max(0, math.ceil(remaining))
end

function LOBBY_DOMAIN.set_pending_join_request(request, state)
	if not (type(request) == "table" and request.requestId) then
		return nil
	end

	local setup = LOBBY_DOMAIN.ensure_setup_state(state)
	request = normalize_join_request_timer(request)
	setup.pending_join_request = request
	return request
end

function LOBBY_DOMAIN.get_pending_join_request(state)
	state = state or LOBBY_DOMAIN.ensure_state()
	local setup = LOBBY_DOMAIN.ensure_setup_state(state)
	local request = type(setup.pending_join_request) == "table" and setup.pending_join_request or nil
	if request and LOBBY_DOMAIN.get_join_request_remaining_seconds(request) <= 0 then
		setup.pending_join_request = nil
		return nil
	end
	return request
end

function LOBBY_DOMAIN.clear_pending_join_request(request_id, state)
	local setup = LOBBY_DOMAIN.ensure_setup_state(state)
	local request = type(setup.pending_join_request) == "table" and setup.pending_join_request or nil
	if request and request_id and tostring(request.requestId) ~= tostring(request_id) then
		return false
	end

	setup.pending_join_request = nil
	return request ~= nil
end

function LOBBY_DOMAIN.store_join_request(request, state)
	if not (type(request) == "table" and request.requestId) then
		return nil
	end

	local setup = LOBBY_DOMAIN.ensure_setup_state(state)
	setup.pending_join_requests = type(setup.pending_join_requests) == "table" and setup.pending_join_requests or {}
	request = normalize_join_request_timer(request)
	setup.pending_join_request_sequence = (tonumber(setup.pending_join_request_sequence) or 0) + 1
	request.queueOrder = request.queueOrder or setup.pending_join_request_sequence
	setup.pending_join_requests[tostring(request.requestId)] = request
	return request
end

function LOBBY_DOMAIN.remove_join_request(request_id, state)
	if not request_id then
		return nil
	end

	local setup = LOBBY_DOMAIN.ensure_setup_state(state)
	setup.pending_join_requests = type(setup.pending_join_requests) == "table" and setup.pending_join_requests or {}
	local key = tostring(request_id)
	local request = setup.pending_join_requests[key]
	setup.pending_join_requests[key] = nil
	return request
end

function LOBBY_DOMAIN.get_join_request(request_id, state)
	if not request_id then
		return nil
	end

	local setup = LOBBY_DOMAIN.ensure_setup_state(state)
	local requests = type(setup.pending_join_requests) == "table" and setup.pending_join_requests or {}
	return requests[tostring(request_id)]
end

function LOBBY_DOMAIN.get_pending_join_requests(state)
	state = state or LOBBY_DOMAIN.ensure_state()
	local setup = LOBBY_DOMAIN.ensure_setup_state(state)
	return type(setup.pending_join_requests) == "table" and setup.pending_join_requests or {}
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
