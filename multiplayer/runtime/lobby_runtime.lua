MP.ACTIONS = MP.ACTIONS or {}
MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}
MP.LOBBY_PLAYER_SNAPSHOT = MP.LOBBY_PLAYER_SNAPSHOT or {}

local lobby_runtime = {}
local lobby_action_runtime = {}
local lobby_message_runtime = {}
local lobby_player_snapshot = MP.LOBBY_PLAYER_SNAPSHOT

-- ============================================================================
-- 1. Lobby Player Snapshot & Payload Normalization (from lobby_player_snapshot.lua)
-- ============================================================================
local lobby_player_snapshot = {}

local lobby_hash_parse_cache = {}

local function parse_modlist(mod_entries)
	if not mod_entries then return {} end

	local mods = {}

	for _, mod_entry in ipairs(mod_entries) do
		local mod_name, mod_version = string.match(mod_entry, "^(.-)%-([^%-]*)$")
		if not mod_name then
			mod_name = mod_entry
			mod_version = nil
		end

		mods[mod_name] = mod_version
	end

	return mods
end

local function parse_lobby_hash(hash)
	local config = {
		encryptID = nil,
		preview = nil,
		unlocked = nil,
		Mods = {},
		hash_str = hash or "",
	}
	local mod_entries = {}

	for part in string.gmatch(hash or "", "([^;]+)") do
		local key, val = string.match(part, "([^=]+)=([^=]+)")
		if key == "encryptID" then
			config.encryptID = tonumber(val)
		elseif key == "preview" then
			config.preview = val == "true"
		elseif key == "unlocked" then
			config.unlocked = val == "true"
		elseif key ~= "serversideConnectionID" and key == nil then
			table.insert(mod_entries, part)
		end
	end

	config.Mods = parse_modlist(mod_entries)
	return config
end

local function get_cached_lobby_hash_info(hash_value)
	hash_value = hash_value or ""
	local cached = lobby_hash_parse_cache[hash_value]
	if cached then
		return cached.config, cached.mod_count
	end

	local config = parse_lobby_hash(hash_value)
	local mod_count = 0
	for _ in pairs(config and config.Mods or {}) do
		mod_count = mod_count + 1
	end

	cached = {
		config = config,
		mod_count = mod_count,
	}
	lobby_hash_parse_cache[hash_value] = cached
	return cached.config, cached.mod_count
end

local function get_player_identity(player_payload)
	if type(player_payload) ~= "table" then
		return "Guest", 1
	end

	local username = player_payload.username
	if type(username) ~= "string" or username == "" then
		username = "Guest"
	end

	local blind_col = 1
	if MP.UTILS and MP.UTILS.clamp_blind_col then
		blind_col = MP.UTILS.clamp_blind_col(player_payload.blindCol)
	else
		blind_col = math.max(1, math.floor(tonumber(player_payload.blindCol) or 1))
	end

	return username, blind_col
end

local function get_player_wire_is_in_match(player_wire)
	return not not (type(player_wire) == "table" and player_wire.isInMatch)
end

local function get_player_wire_is_ready(player_wire, uses_lobby_ready)
	if not uses_lobby_ready or type(player_wire) ~= "table" then
		return nil
	end

	return player_wire.isReadyLobby
end

local function get_player_wire_can_manage(player_wire, is_host, is_self, is_saved_coop_restore)
	return is_host
		and not is_saved_coop_restore
		and (not is_self)
		and type(player_wire) == "table"
		and not player_wire.isOwner
end

local function get_player_wire_disconnect_state(player_wire)
	if type(player_wire) ~= "table" then
		return false, "loc_selecting"
	end

	local is_disconnected = not not player_wire.isDisconnected
	local raw_location = player_wire.location or "loc_selecting"

	if is_disconnected then
		raw_location = "loc_disconnected"
	end

	return is_disconnected, raw_location
end

function lobby_player_snapshot.get_local_player_in_match(players)
	local self_player_id = (G and G.MP_ID or nil)
	for _, player_wire in ipairs(players or {}) do
		if player_wire.id == self_player_id then
			return get_player_wire_is_in_match(player_wire)
		end
	end

	return false
end

function lobby_player_snapshot.normalize_player_payload(player_wire, is_host, uses_lobby_ready, is_saved_coop_restore)
	local username, blind_col = get_player_identity(player_wire)
	local config, mod_count = get_cached_lobby_hash_info(player_wire.modHash)
	local is_self = player_wire.id == (G and G.MP_ID or nil)
	local is_in_match = get_player_wire_is_in_match(player_wire)
	local is_ready = get_player_wire_is_ready(player_wire, uses_lobby_ready)
	local can_manage = get_player_wire_can_manage(player_wire, is_host, is_self, is_saved_coop_restore)
	local is_disconnected, raw_location = get_player_wire_disconnect_state(player_wire)
	local status_kind = uses_lobby_ready and (is_ready and "ready" or "waiting") or nil
	local location = MP.UI and MP.UI.localize_location and MP.UI.localize_location(raw_location) or raw_location
	local lives = tonumber(player_wire.lives)
	local blind_target_scale = tonumber(player_wire.blindTargetScale)
	local role = player_wire.role or (player_wire.isSpectator and "spectator") or "player"
	local is_spectator = not not (player_wire.isSpectator or player_wire.role == "spectator")

	-- Keep local spectator role in sync with the authoritative server state.
	if is_self and MP.SPECTATOR then
		local role_is_authoritative = (player_wire.role ~= nil or player_wire.isSpectator ~= nil)
		if role == "spectator" then
			MP.SPECTATOR.is_spectator_role = true
		elseif role_is_authoritative then
			MP.SPECTATOR.is_spectator_role = false
			if MP.SPECTATOR.is_spectating and MP.SPECTATOR.stop_spectating then
				MP.SPECTATOR.stop_spectating()
			end
		end
	end

	return {
		id = player_wire.id,
		username = username,
		blind_col = blind_col,
		blind_target_scale = blind_target_scale,
		nemesis_player_id = player_wire.nemesisPlayerId,
		cached = player_wire.isCached,
		config = config,
		hash_str = player_wire.modHash or "",
		is_owner = player_wire.isOwner,
		is_ready = is_ready,
		is_in_match = is_in_match,
		is_disconnected = is_disconnected,
		location = location,
		raw_location = raw_location,
		team = player_wire.team,
		team_name = MP.TEAM_NAMES[player_wire.team or 1] or "TEAM",
		is_team_locked = not not player_wire.isTeamLocked,
		is_self = is_self,
		lives = lives,
		role = role,
		is_spectator = is_spectator,
		status_text = uses_lobby_ready and (is_ready and localize("b_ready") or localize("b_unready")) or nil,
		status_kind = status_kind,
		can_kick = can_manage,
		can_make_host = can_manage,
		mod_count = mod_count,
	}
end

MP.LOBBY_PLAYER_SNAPSHOT.get_local_player_in_match = lobby_player_snapshot.get_local_player_in_match
MP.LOBBY_PLAYER_SNAPSHOT.normalize_player_payload = lobby_player_snapshot.normalize_player_payload

-- ============================================================================
-- 2. Outgoing Lobby Actions (from lobby_action_runtime.lua)
-- ============================================================================
local lobby_action_runtime = {}

local function copy_lobby_options()
	local full_update = {}
	local config = MP.LOBBY and MP.LOBBY.config or {}

	for option_key, option_value in pairs(config) do
		full_update[option_key] = option_value
	end

	return full_update
end

local function build_lobby_option_sync(options)
	local payload = copy_lobby_options()

	for key, value in pairs(options or {}) do
		payload[key] = value
	end

	return payload
end

local function resolve_create_lobby_type(gamemode)
	local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY or {}
	local normalized_gamemode = lobby_domain.normalize_gamemode
		and lobby_domain.normalize_gamemode(gamemode)
		or gamemode
	local current_lobby_type = MP.LOBBY and MP.LOBBY.lobby_type or nil

	if lobby_domain.get_lobby_type_for_gamemode then
		return lobby_domain.get_lobby_type_for_gamemode(normalized_gamemode, current_lobby_type)
	end

	return current_lobby_type
end

function lobby_action_runtime.create_lobby(gamemode)
	local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY or {}
	local access_mode = lobby_domain.get_creation_access_mode
		and lobby_domain.get_creation_access_mode()
		or "private"
	Client.send(MP.LOBBY_WIRE.build_create_lobby_payload(
		gamemode,
		resolve_create_lobby_type(gamemode),
		copy_lobby_options(),
		access_mode
	))
end

function lobby_action_runtime.request_lobby_list()
	Client.send(MP.LOBBY_WIRE.build_request_lobby_list_payload())
end

function lobby_action_runtime.join_lobby(code)
	Client.send(MP.LOBBY_WIRE.build_join_lobby_payload(code))
end

function lobby_action_runtime.respond_lobby_join_request(request_id, accepted, blocked)
	Client.send(MP.LOBBY_WIRE.build_respond_lobby_join_request_payload(request_id, accepted, blocked))
end

function lobby_action_runtime.cancel_lobby_join_request(request_id)
	Client.send(MP.LOBBY_WIRE.build_cancel_lobby_join_request_payload(request_id))
end

function lobby_action_runtime.rejoin_lobby(code, reconnect_token)
	MP.NETWORKING_INTERNAL.send_connection_rejoin(code, reconnect_token)
end

function lobby_action_runtime.ready_lobby()
	Client.send(MP.LOBBY_WIRE.build_ready_lobby_payload())
end

function lobby_action_runtime.unready_lobby()
	Client.send(MP.LOBBY_WIRE.build_unready_lobby_payload())
end

function lobby_action_runtime.leave_lobby()
	Client.send(MP.LOBBY_WIRE.build_leave_lobby_payload())
	if MP.RESUME and MP.RESUME.clear_saved_resume then
		MP.RESUME.clear_saved_resume()
	end
	if MP.CONNECTION_SESSION and MP.CONNECTION_SESSION.clear_reconnect_lobby_state then
		MP.CONNECTION_SESSION.clear_reconnect_lobby_state()
	end
end

function lobby_action_runtime.return_to_lobby()
	Client.send(MP.LOBBY_WIRE.build_return_to_lobby_payload())
end

local function send_lobby_option_update(options)
	local payload = MP.LOBBY_WIRE.build_lobby_option_update_action_payload(options)
	if payload then
		Client.send(payload)
	end
end

local function send_full_lobby_option_update(options)
	send_lobby_option_update(type(options) == "table" and options or copy_lobby_options())
end

function lobby_action_runtime.lobby_options(options, force_full_sync)
	if MP.LOBBY and MP.LOBBY.is_saved_coop_restore then
		return
	end

	if type(options) == "table" then
		if MP.LOBBY_WIRE.should_full_sync_lobby_options(options, force_full_sync) then
			send_full_lobby_option_update(build_lobby_option_sync(options))
		else
			send_lobby_option_update(options)
		end
	end
end

function lobby_action_runtime.kick_player(player_id)
	Client.send(MP.LOBBY_WIRE.build_kick_player_payload(player_id))
end

function lobby_action_runtime.make_player_host(player_id)
	Client.send(MP.LOBBY_WIRE.build_make_player_host_payload(player_id))
end

function lobby_action_runtime.set_team(team_id, player_id)
	Client.send(MP.LOBBY_WIRE.build_set_team_payload(team_id, player_id))
end

function lobby_action_runtime.set_team_lock(player_id, locked)
	Client.send(MP.LOBBY_WIRE.build_set_team_lock_payload(player_id, locked))
end

function lobby_action_runtime.set_lobby_type(lobby_type)
	if MP.LOBBY and MP.LOBBY.is_saved_coop_restore then
		return
	end

	Client.send(MP.LOBBY_WIRE.build_set_lobby_type_payload(lobby_type))
end

MP.ACTIONS.create_lobby = lobby_action_runtime.create_lobby
MP.ACTIONS.request_lobby_list = lobby_action_runtime.request_lobby_list
MP.ACTIONS.join_lobby = lobby_action_runtime.join_lobby
MP.ACTIONS.respond_lobby_join_request = lobby_action_runtime.respond_lobby_join_request
MP.ACTIONS.cancel_lobby_join_request = lobby_action_runtime.cancel_lobby_join_request
MP.ACTIONS.rejoin_lobby = lobby_action_runtime.rejoin_lobby
MP.ACTIONS.ready_lobby = lobby_action_runtime.ready_lobby
MP.ACTIONS.unready_lobby = lobby_action_runtime.unready_lobby
MP.ACTIONS.leave_lobby = lobby_action_runtime.leave_lobby
MP.ACTIONS.return_to_lobby = lobby_action_runtime.return_to_lobby
MP.ACTIONS.lobby_options = lobby_action_runtime.lobby_options
MP.ACTIONS.kick_player = lobby_action_runtime.kick_player
MP.ACTIONS.make_player_host = lobby_action_runtime.make_player_host
MP.ACTIONS.set_team = lobby_action_runtime.set_team
MP.ACTIONS.set_team_lock = lobby_action_runtime.set_team_lock
MP.ACTIONS.set_lobby_type = lobby_action_runtime.set_lobby_type

-- ============================================================================
-- 3. Incoming Lobby Message Handlers (from lobby_message_runtime.lua)
-- ============================================================================
local lobby_message_runtime = {}
local load_required_service = MP.UTILS.load_required_service

local function get_lobby_domain()
	return MP.DOMAIN and MP.DOMAIN.LOBBY or {}
end

local function get_main_menu_play_ui()
	return MP.UI and MP.UI.MAIN_MENU_PLAY or {}
end

local function ensure_state_apply_runtime(required_method)
	return load_required_service(
		"multiplayer/runtime/network_state_apply.lua",
		required_method,
		"Multiplayer state apply runtime service is missing.",
		function()
			return MP.STATE_APPLY
		end
	)
end

local function apply_state_update(method_name, ...)
	local state_apply = ensure_state_apply_runtime(method_name)
	local method = state_apply and state_apply[method_name] or nil
	if method then
		return method(...)
	end

	return nil
end

function lobby_message_runtime.handle_lobby_info(players, is_host, is_in_game, lobby_type, is_coop_save_restore)
	apply_state_update("lobby_info", players, is_host, is_in_game, lobby_type, is_coop_save_restore)
end

function lobby_message_runtime.handle_lobby_list(lobbies)
	local lobby_domain = get_lobby_domain()
	if lobby_domain.set_browser_pending then
		lobby_domain.set_browser_pending(false)
	end
	if lobby_domain.set_browser_lobbies then
		lobby_domain.set_browser_lobbies(lobbies)
	end

	local main_menu_play_ui = get_main_menu_play_ui()
	if main_menu_play_ui.refresh_browse_lobbies_overlay then
		main_menu_play_ui.refresh_browse_lobbies_overlay()
	end
end

function lobby_message_runtime.handle_lobby_join_request_received(request)
	local lobby_domain = get_lobby_domain()
	if lobby_domain.store_join_request then
		lobby_domain.store_join_request(request)
	end

	local main_menu_play_ui = get_main_menu_play_ui()
	if main_menu_play_ui.open_join_request_notification then
		main_menu_play_ui.open_join_request_notification(request)
		return
	end

	if MP.UI and MP.UI.UTILS and MP.UI.UTILS.overlay_message then
		MP.UI.UTILS.overlay_message(tostring(request and request.username or "A player") .. " wants to join.")
	end
end

function lobby_message_runtime.handle_lobby_join_request_pending(code, request_id, expires_at, expires_in_ms)
	local lobby_domain = get_lobby_domain()
	if lobby_domain.set_setup_temp_code then
		lobby_domain.set_setup_temp_code(code or "")
	end
	if lobby_domain.set_pending_join_request and request_id then
		lobby_domain.set_pending_join_request({
			code = code,
			requestId = request_id,
			expiresAt = expires_at,
			expiresInMs = expires_in_ms,
		})
	end

	local main_menu_play_ui = get_main_menu_play_ui()
	if MP.UI and MP.UI.refresh_main_menu_multiplayer_buttons then
		MP.UI.refresh_main_menu_multiplayer_buttons()
	end
	if main_menu_play_ui.refresh_browse_lobbies_overlay then
		main_menu_play_ui.refresh_browse_lobbies_overlay()
	end
end

function lobby_message_runtime.handle_lobby_join_request_rejected(code, message, request_id, reason)
	local lobby_domain = get_lobby_domain()
	if lobby_domain.set_setup_temp_code then
		lobby_domain.set_setup_temp_code(code or "")
	end
	if lobby_domain.clear_pending_join_request then
		lobby_domain.clear_pending_join_request(request_id)
	end

	local main_menu_play_ui = get_main_menu_play_ui()
	if MP.UI and MP.UI.refresh_main_menu_multiplayer_buttons then
		MP.UI.refresh_main_menu_multiplayer_buttons()
	end
	if main_menu_play_ui.refresh_browse_lobbies_overlay then
		main_menu_play_ui.refresh_browse_lobbies_overlay()
	end

	if reason ~= "expired" and reason ~= "cancelled" and MP.UI and MP.UI.UTILS and MP.UI.UTILS.overlay_message then
		MP.UI.UTILS.overlay_message(message or localize("k_join_request_denied"))
	end
end

function lobby_message_runtime.handle_lobby_join_request_closed(code, request_id, reason)
	local lobby_domain = get_lobby_domain()
	if lobby_domain.remove_join_request then
		lobby_domain.remove_join_request(request_id)
	end

	local main_menu_play_ui = get_main_menu_play_ui()
	if main_menu_play_ui.close_join_request_notification then
		local closed_notification = main_menu_play_ui.close_join_request_notification(request_id)
		if not closed_notification and main_menu_play_ui.show_next_join_request_notification then
			main_menu_play_ui.show_next_join_request_notification()
		end
	end
end

function lobby_message_runtime.handle_lobby_player_joined(player)
	apply_state_update("lobby_player_joined", player)
end

function lobby_message_runtime.handle_lobby_player_updated(player)
	apply_state_update("lobby_player_updated", player)
end

function lobby_message_runtime.handle_lobby_player_left(player_id, is_host, owner_player_id, assignments)
	apply_state_update("lobby_player_left", player_id, is_host, owner_player_id, assignments)
end

function lobby_message_runtime.handle_lobby_type_changed(lobby_type, players)
	apply_state_update("lobby_type_changed", lobby_type, players)
end

function lobby_message_runtime.handle_lobby_player_team(player_id, team_id)
	apply_state_update("lobby_player_team", player_id, team_id)
end

function lobby_message_runtime.handle_lobby_nemesis_assignments(assignments)
	apply_state_update("lobby_nemesis_assignments", assignments)
end

function lobby_message_runtime.handle_lobby_options(message)
	local lobby_session = load_required_service(
		"multiplayer/runtime/session_runtime.lua",
		"apply_lobby_options",
		"Multiplayer lobby session runtime service is missing.",
		function()
			return MP.LOBBY_SESSION
		end
	)
	if not (lobby_session and lobby_session.apply_lobby_options) then
		return
	end

	local options = MP.LOBBY_WIRE.extract_lobby_option_payload(message)
	local applied, result = lobby_session.apply_lobby_options(options)
	if not applied and lobby_session.handle_lobby_option_failure then
		lobby_session.handle_lobby_option_failure(result)
	end
end

MP.NETWORKING_INTERNAL.handle_lobby_info = lobby_message_runtime.handle_lobby_info
MP.NETWORKING_INTERNAL.handle_lobby_list = lobby_message_runtime.handle_lobby_list
MP.NETWORKING_INTERNAL.handle_lobby_join_request_received = lobby_message_runtime.handle_lobby_join_request_received
MP.NETWORKING_INTERNAL.handle_lobby_join_request_pending = lobby_message_runtime.handle_lobby_join_request_pending
MP.NETWORKING_INTERNAL.handle_lobby_join_request_rejected = lobby_message_runtime.handle_lobby_join_request_rejected
MP.NETWORKING_INTERNAL.handle_lobby_join_request_closed = lobby_message_runtime.handle_lobby_join_request_closed
MP.NETWORKING_INTERNAL.handle_lobby_player_joined = lobby_message_runtime.handle_lobby_player_joined
MP.NETWORKING_INTERNAL.handle_lobby_player_updated = lobby_message_runtime.handle_lobby_player_updated
MP.NETWORKING_INTERNAL.handle_lobby_player_left = lobby_message_runtime.handle_lobby_player_left
MP.NETWORKING_INTERNAL.handle_lobby_type_changed = lobby_message_runtime.handle_lobby_type_changed
MP.NETWORKING_INTERNAL.handle_lobby_player_team = lobby_message_runtime.handle_lobby_player_team
MP.NETWORKING_INTERNAL.handle_lobby_nemesis_assignments = lobby_message_runtime.handle_lobby_nemesis_assignments
MP.NETWORKING_INTERNAL.handle_lobby_options = lobby_message_runtime.handle_lobby_options

return lobby_runtime
