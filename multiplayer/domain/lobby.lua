MP.DOMAIN = MP.DOMAIN or {}
MP.DOMAIN.LOBBY = MP.DOMAIN.LOBBY or {}

local LOBBY_DOMAIN = MP.DOMAIN.LOBBY

-- ============================================================================
-- 1. Lobby State Initialization & Accessors (from lobby_state.lua)
-- ============================================================================
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

-- ============================================================================
-- 2. Lobby Options & Gamemode Configuration (from lobby_options.lua)
-- ============================================================================

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

local function save_creation_pref(path, value)
	local smods = MP.PLATFORM and MP.PLATFORM.SMODS or nil
	if not (smods and type(smods.set_config_value) == "function") then
		return
	end
	smods.set_config_value(path, value, MP)
	if MP.save_current_config then
		MP.save_current_config()
	end
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
	local saved_ruleset = LOBBY_DOMAIN.set_setup_field("creation_ruleset", ruleset_key, state)
	save_creation_pref(CREATION_RULESET_CONFIG_PATH, saved_ruleset)
	local ruleset = MP.Rulesets and MP.Rulesets[saved_ruleset]
	if ruleset and ruleset.forced_gamemode then
		LOBBY_DOMAIN.set_creation_gamemode(ruleset.forced_gamemode, state)
	end
	return saved_ruleset
end

function LOBBY_DOMAIN.get_creation_ruleset(state)
	local setup = LOBBY_DOMAIN.ensure_setup_state(state)
	return setup.creation_ruleset or MP.DEFAULT_LOBBY_CREATION_RULESET
end

function LOBBY_DOMAIN.set_creation_gamemode(gamemode_key, state)
	state = state or LOBBY_DOMAIN.ensure_state()
	local normalized_gamemode = LOBBY_DOMAIN.normalize_gamemode(gamemode_key)
	apply_lobby_type_for_gamemode(normalized_gamemode, state)
	local saved_gamemode = LOBBY_DOMAIN.set_setup_field("creation_gamemode", normalized_gamemode, state)
	save_creation_pref(CREATION_GAMEMODE_CONFIG_PATH, saved_gamemode)
	return saved_gamemode
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
	config.modifier_layers = MP.modifiers_serialize and MP.modifiers_serialize() or ""
	local pending_custom_options = MP.CUSTOM
		and MP.CUSTOM.get_pending_lobby_options
		and MP.CUSTOM.get_pending_lobby_options()
		or nil
	if pending_custom_options then
		for key, value in pairs(pending_custom_options) do
			config[key] = value
		end
	else
		config.custom_bans = ""
	end

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

-- ============================================================================
-- 3. Run Deck Configuration & Sync (from lobby_run_deck.lua)
-- ============================================================================
function LOBBY_DOMAIN.ensure_run_deck_state(state)
	state = state or LOBBY_DOMAIN.ensure_state()

	if not state.run_deck then
		state.run_deck = LOBBY_DOMAIN.build_initial_run_deck_state()
	end

	return state.run_deck
end

function LOBBY_DOMAIN.build_run_deck_from_config(state)
	state = state or LOBBY_DOMAIN.ensure_state()
	return LOBBY_DOMAIN.build_deck_state(state.config or nil)
end

function LOBBY_DOMAIN.get_run_deck(state)
	return LOBBY_DOMAIN.ensure_run_deck_state(state)
end

function LOBBY_DOMAIN.sync_run_deck_from_config(state)
	state = state or LOBBY_DOMAIN.ensure_state()
	state.run_deck = LOBBY_DOMAIN.build_run_deck_from_config(state)
	LOBBY_DOMAIN.ensure_run_deck_state(state)
	return state.run_deck
end

-- ============================================================================
-- 4. Lobby Updates & Team Management (from lobby_updates.lua)
-- ============================================================================
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

	if option_key == "modifier_layers" then
		return tostring(option_value or "")
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
		if option_key == "modifier_layers" and MP.modifiers_parse then
			MP.modifiers_parse(option_value or "")
		end
		if MP.SHARED_LOBBY_DECK_OPTION_KEYS and MP.SHARED_LOBBY_DECK_OPTION_KEYS[option_key] then
			shared_deck_changed = true
		end
		if MP.UI.update_lobby_option_toggle then
			MP.UI.update_lobby_option_toggle(option_key)
		end
	end

	if different_decks_before ~= config.different_decks or ((not config.different_decks) and shared_deck_changed) then
		if LOBBY_DOMAIN.sync_run_deck_from_config then
			LOBBY_DOMAIN.sync_run_deck_from_config(state)
		end
	end

	if shared_deck_changed and MP.UI and MP.UI.update_coop_blind_curve_demonstration then
		MP.UI.update_coop_blind_curve_demonstration()
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
	local config = LOBBY_DOMAIN.ensure_config_state(state)
	if not config.different_decks then
		for key, value in pairs(deck_changes or {}) do
			if MP.SHARED_LOBBY_DECK_OPTION_KEYS and MP.SHARED_LOBBY_DECK_OPTION_KEYS[key] then
				config[key] = value
			end
		end
	end
	LOBBY_DOMAIN.ensure_run_deck_state(state)
	if MP.UI and MP.UI.update_coop_blind_curve_demonstration then
		MP.UI.update_coop_blind_curve_demonstration()
	end
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

-- ============================================================================
-- 5. Lobby Session Lifecycle (from lobby_session.lua)
-- ============================================================================
local function build_session_update_result(state, previous_match_in_progress, previous_lobby_type)
	return {
		previous_match_in_progress = previous_match_in_progress,
		previous_lobby_type = previous_lobby_type,
		match_in_progress = not not state.match_in_progress,
		lobby_type = state.lobby_type or nil,
	}
end

function LOBBY_DOMAIN.clear_session(state)
	state = state or LOBBY_DOMAIN.ensure_state()

	state.code = nil
	LOBBY_DOMAIN.set_host_state(false, state)
	LOBBY_DOMAIN.set_match_in_progress(false, state)
	LOBBY_DOMAIN.set_saved_coop_restore(false, state)
	LOBBY_DOMAIN.set_players({}, state)
	LOBBY_DOMAIN.set_pending_ready(nil, state)

	return state
end

function LOBBY_DOMAIN.apply_info_snapshot(args, state)
	state = state or LOBBY_DOMAIN.ensure_state()
	args = args or {}

	local previous_match_in_progress = not not state.match_in_progress
	local previous_lobby_type = state.lobby_type or nil

	if args.lobby_type ~= nil then
		LOBBY_DOMAIN.set_lobby_type(args.lobby_type, state)
	end

	LOBBY_DOMAIN.set_host_state(args.is_host, state)
	LOBBY_DOMAIN.set_match_in_progress(args.is_in_game, state)
	LOBBY_DOMAIN.set_saved_coop_restore(args.is_coop_save_restore, state)
	LOBBY_DOMAIN.set_players(args.players, state)
	LOBBY_DOMAIN.set_pending_ready(nil, state)

	return build_session_update_result(state, previous_match_in_progress, previous_lobby_type)
end

local function upsert_player(player, state)
	state = state or LOBBY_DOMAIN.ensure_state()

	local previous_match_in_progress = not not state.match_in_progress
	local previous_lobby_type = state.lobby_type or nil
	local players = LOBBY_DOMAIN.get_players(state)
	local replaced = false

	for index, existing_player in ipairs(players) do
		if existing_player.id == player.id then
			players[index] = player
			replaced = true
			break
		end
	end

	if not replaced then
		table.insert(players, player)
	end

	return build_session_update_result(state, previous_match_in_progress, previous_lobby_type)
end

function LOBBY_DOMAIN.apply_player_joined(player, state)
	return upsert_player(player, state)
end

function LOBBY_DOMAIN.apply_player_updated(player, state)
	state = state or LOBBY_DOMAIN.ensure_state()
	local result = upsert_player(player, state)

	local self_player_id = (G and G.MP_ID or nil)
	local pending_ready = state.client and state.client.pending_lobby_ready
	if player and player.id == self_player_id and pending_ready ~= nil then
		LOBBY_DOMAIN.set_pending_ready(nil, state)
	end

	return result
end

local function refresh_player_management_flags(players, state, owner_player_id)
	local self_player_id = (G and G.MP_ID or nil)
	for _, player in ipairs(players or LOBBY_DOMAIN.get_players(state)) do
		if owner_player_id ~= nil then
			player.is_owner = player.id == owner_player_id
		end
		local can_manage = state.is_host
			and not state.is_saved_coop_restore
			and player.id ~= self_player_id
			and not player.is_owner
		player.can_kick = can_manage
		player.can_make_host = can_manage
	end
end

function LOBBY_DOMAIN.apply_player_left(player_id, is_host, owner_player_id, assignments, state)
	state = state or LOBBY_DOMAIN.ensure_state()

	local previous_match_in_progress = not not state.match_in_progress
	local previous_lobby_type = state.lobby_type or nil
	local remaining_players = {}

	for _, player in ipairs(LOBBY_DOMAIN.get_players(state)) do
		if player.id ~= player_id then
			table.insert(remaining_players, player)
		end
	end

	LOBBY_DOMAIN.set_players(remaining_players, state)
	LOBBY_DOMAIN.set_host_state(is_host, state)
	LOBBY_DOMAIN.apply_nemesis_assignments(assignments, state)

	refresh_player_management_flags(remaining_players, state, owner_player_id)

	return build_session_update_result(state, previous_match_in_progress, previous_lobby_type)
end

function LOBBY_DOMAIN.apply_type_changed(lobby_type, player_updates, state)
	state = state or LOBBY_DOMAIN.ensure_state()

	local previous_match_in_progress = not not state.match_in_progress
	local previous_lobby_type = state.lobby_type or nil

	if lobby_type ~= nil then
		LOBBY_DOMAIN.set_lobby_type(lobby_type, state)
	end

	local updates_by_id = {}
	for _, update in ipairs(player_updates or {}) do
		if type(update) == "table" and update.playerId ~= nil then
			updates_by_id[update.playerId] = update
		end
	end

	local uses_lobby_ready = MP.lobby_uses_ready and MP.lobby_uses_ready() or false
	local players = LOBBY_DOMAIN.get_players(state)
	for _, player in ipairs(players) do
		local update = updates_by_id[player.id]
		if update then
			local team = update.team
			local is_ready = update.isReadyLobby

			player.team = team
			player.team_name = MP.TEAM_NAMES[team or 1] or "TEAM"
			player.is_team_locked = not not update.isTeamLocked
			player.is_ready = is_ready
			player.nemesis_player_id = update.nemesisPlayerId

			if uses_lobby_ready then
				player.status_text = is_ready and localize("b_ready") or localize("b_unready")
				player.status_kind = is_ready and "ready" or "waiting"
			else
				player.status_text = nil
				player.status_kind = nil
			end
		end
	end

	LOBBY_DOMAIN.set_pending_ready(nil, state)
	refresh_player_management_flags(players, state)

	return build_session_update_result(state, previous_match_in_progress, previous_lobby_type)
end

function LOBBY_DOMAIN.apply_nemesis_assignments(assignments, state)
	local players = LOBBY_DOMAIN.get_players(state)
	local changed = false

	for _, assignment in ipairs(assignments or {}) do
		local player_id = assignment.playerId
		for _, player in ipairs(players) do
			if player.id == player_id then
				player.nemesis_player_id = assignment.nemesisPlayerId
				changed = true
				break
			end
		end
	end

	return changed
end

function LOBBY_DOMAIN.begin_session(args, state)
	state = state or LOBBY_DOMAIN.ensure_state()
	args = args or {}

	state.code = args.code
	LOBBY_DOMAIN.set_match_in_progress(args.match_in_progress, state)
	LOBBY_DOMAIN.set_host_state(args.is_host, state)
	LOBBY_DOMAIN.set_saved_coop_restore(args.is_coop_save_restore, state)
	LOBBY_DOMAIN.set_players(args.players, state)
	LOBBY_DOMAIN.set_lobby_type(args.lobby_type or state.lobby_type or "", state)

	if args.gamemode then
		state.config.gamemode = LOBBY_DOMAIN.normalize_gamemode(args.gamemode)
	end

	if args.player_id ~= nil then
		G.MP_ID = args.player_id
	end

	LOBBY_DOMAIN.set_pending_ready(nil, state)
	return state
end

return LOBBY_DOMAIN
