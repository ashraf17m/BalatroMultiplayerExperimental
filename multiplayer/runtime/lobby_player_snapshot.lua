local lobby_player_snapshot = {}
local BALATRO = MP.PLATFORM.BALATRO

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

local function parse_lobby_player_identity(encoded_name)
	local username, col_str = string.match(encoded_name or "", "([^~]+)~(%d+)")
	username = username or "Guest"
	local blind_col = MP.UTILS.clamp_blind_col(col_str)
	return username, blind_col
end

local function get_player_identity(player_payload)
	if type(player_payload) ~= "table" then
		return "Guest", 1
	end

	local username = player_payload.username or "Guest"
	local blind_col = tonumber(player_payload.blindCol)

	if blind_col ~= nil then
		blind_col = MP.UTILS.clamp_blind_col(blind_col)
		return username, blind_col
	end

	return parse_lobby_player_identity(username)
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
	local self_player_id = BALATRO.get_player_id()
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
	local is_self = player_wire.id == BALATRO.get_player_id()
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

return lobby_player_snapshot
