MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}
MP.CONNECTION_IDENTITY = MP.CONNECTION_IDENTITY or {}

local network_client_state = {}

local connection_identity = MP.CONNECTION_IDENTITY
local BALATRO = MP.PLATFORM.BALATRO
local has_required_methods = MP.UTILS.has_required_methods

local CONNECTION_SESSION_METHODS = {
	"get_reconnect_lobby_state",
	"set_reconnect_lobby_state",
	"clear_reconnect_lobby_state",
}

local function ensure_connection_session()
	local connection_session = MP.CONNECTION_SESSION or nil
	if has_required_methods(connection_session, CONNECTION_SESSION_METHODS) then
		return connection_session
	end

	local loaded = MP.PLATFORM.SMODS.load_mod_file("multiplayer/runtime/session_runtime.lua", { required = true })
	if loaded == nil then
		return nil
	end
	if type(loaded) == "table" and has_required_methods(loaded.CONNECTION, CONNECTION_SESSION_METHODS) then
		return loaded.CONNECTION
	end

	connection_session = MP.CONNECTION_SESSION or nil
	if has_required_methods(connection_session, CONNECTION_SESSION_METHODS) then
		return connection_session
	end

	return nil
end

local function resend_identity_if_connected()
	if
		MP.LOBBY
		and MP.LOBBY.client
		and MP.LOBBY.client.connected
		and MP.CONNECTION_WIRE
		and MP.CONNECTION_WIRE.send_identity
	then
		MP.CONNECTION_WIRE.send_identity()
	end
end

function connection_identity.is_player_id_valid()
	return BALATRO.get_player_id() ~= nil
end

function connection_identity.set_username(username)
	local next_username = MP.set_lobby_client_username and MP.set_lobby_client_username(username)
		or (username or "Guest")
	resend_identity_if_connected()
	return next_username
end

function connection_identity.set_blind_col(num)
	if MP.UTILS and MP.UTILS.clamp_blind_col then
		num = MP.UTILS.clamp_blind_col(num)
	end
	local blind_col = MP.set_lobby_client_blind_col and MP.set_lobby_client_blind_col(num) or (num or 1)
	resend_identity_if_connected()
	return blind_col
end

function network_client_state.clear_reconnect_lobby_state()
	local connection_session = ensure_connection_session()
	if connection_session and connection_session.clear_reconnect_lobby_state then
		return connection_session.clear_reconnect_lobby_state()
	end
end

function network_client_state.get_reconnect_lobby_state()
	local connection_session = ensure_connection_session()
	if connection_session and connection_session.get_reconnect_lobby_state then
		return connection_session.get_reconnect_lobby_state()
	end

	return nil, nil
end

function network_client_state.set_reconnect_lobby_state(token, code)
	local connection_session = ensure_connection_session()
	if connection_session and connection_session.set_reconnect_lobby_state then
		return connection_session.set_reconnect_lobby_state(token, code)
	end
end

function network_client_state.ensure_server_player_id(player_id, failure_message)
	if player_id then
		return true
	end

	sendWarnMessage("Server error: playerId not provided. " .. failure_message, "MULTIPLAYER")
	return false
end

function network_client_state.get_or_create_enemy_state(player_id, username)
	return MP.get_or_create_match_enemy_state(player_id, username)
end

MP.NETWORKING_INTERNAL.clear_reconnect_lobby_state = network_client_state.clear_reconnect_lobby_state
MP.NETWORKING_INTERNAL.get_reconnect_lobby_state = network_client_state.get_reconnect_lobby_state
MP.NETWORKING_INTERNAL.set_reconnect_lobby_state = network_client_state.set_reconnect_lobby_state
MP.NETWORKING_INTERNAL.ensure_server_player_id = network_client_state.ensure_server_player_id
MP.NETWORKING_INTERNAL.get_or_create_enemy_state = network_client_state.get_or_create_enemy_state

return network_client_state
