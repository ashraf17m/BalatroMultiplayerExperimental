MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}
MP.CONNECTION_IDENTITY = MP.CONNECTION_IDENTITY or {}

local network_client_state = {}

local connection_identity = MP.CONNECTION_IDENTITY
local load_required_service = MP.UTILS.load_required_service
local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY or {}

local CONNECTION_SESSION_METHODS = {
	"get_reconnect_lobby_state",
	"set_reconnect_lobby_state",
	"clear_reconnect_lobby_state",
}

local function ensure_connection_session()
	return load_required_service(
		"multiplayer/runtime/session_runtime.lua",
		CONNECTION_SESSION_METHODS,
		"Multiplayer connection session runtime service is missing.",
		function()
			return MP.CONNECTION_SESSION
		end
	)
end

local function resend_identity_if_connected()
	if
		MP.LOBBY
		and MP.LOBBY.client
		and MP.LOBBY.client.connected
		and MP.NETWORKING_INTERNAL
		and MP.NETWORKING_INTERNAL.send_connection_identity
	then
		MP.NETWORKING_INTERNAL.send_connection_identity()
	end
end

function connection_identity.set_username(username)
	local next_username = lobby_domain.set_client_username and lobby_domain.set_client_username(username)
		or (username or "Guest")
	resend_identity_if_connected()
	return next_username
end

function connection_identity.set_blind_col(num)
	if MP.UTILS and MP.UTILS.clamp_blind_col then
		num = MP.UTILS.clamp_blind_col(num)
	end
	local blind_col = lobby_domain.set_client_blind_col and lobby_domain.set_client_blind_col(num) or (num or 1)
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

MP.NETWORKING_INTERNAL.clear_reconnect_lobby_state = network_client_state.clear_reconnect_lobby_state
MP.NETWORKING_INTERNAL.get_reconnect_lobby_state = network_client_state.get_reconnect_lobby_state
MP.NETWORKING_INTERNAL.set_reconnect_lobby_state = network_client_state.set_reconnect_lobby_state
MP.NETWORKING_INTERNAL.ensure_server_player_id = network_client_state.ensure_server_player_id

return network_client_state
