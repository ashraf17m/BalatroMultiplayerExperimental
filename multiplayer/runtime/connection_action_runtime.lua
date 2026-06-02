MP.ACTIONS = MP.ACTIONS or {}
MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}

local connection_action_runtime = {}
local cached_connection_identity = nil
local load_required_service = MP.UTILS.load_required_service

local CONNECTION_IDENTITY_METHODS = {
	"set_username",
	"set_blind_col",
}

local function send_payload(payload)
	if payload then
		Client.send(payload)
	end
end

local function ensure_connection_identity()
	if cached_connection_identity then
		return cached_connection_identity
	end

	cached_connection_identity = load_required_service(
		"multiplayer/runtime/network_client_state.lua",
		CONNECTION_IDENTITY_METHODS,
		"Multiplayer network client identity service is missing.",
		function()
			return MP.CONNECTION_IDENTITY
		end
	)
	return cached_connection_identity
end

local function get_identity_payload_values()
	local client = MP.LOBBY and MP.LOBBY.client or {}
	return client.username, client.blind_col, MP.MOD_STRING
end

function connection_action_runtime.connect()
	send_payload(MP.CONNECTION_WIRE.build_connect_payload())
end

function connection_action_runtime.send_identity()
	local username, blind_col, mod_hash = get_identity_payload_values()
	send_payload(MP.CONNECTION_WIRE.build_identity_payload(username, blind_col, mod_hash))
end

function connection_action_runtime.send_rejoin(code, reconnect_token)
	send_payload(MP.CONNECTION_WIRE.build_rejoin_payload(code, reconnect_token))
end

function connection_action_runtime.send_keep_alive_ack()
	send_payload(MP.CONNECTION_WIRE.build_keep_alive_ack_payload())
end

function connection_action_runtime.set_username(username)
	if not ensure_connection_identity() then
		return nil
	end

	return MP.CONNECTION_IDENTITY.set_username(username)
end

function connection_action_runtime.set_blind_col(num)
	if not ensure_connection_identity() then
		return nil
	end

	return MP.CONNECTION_IDENTITY.set_blind_col(num)
end

MP.ACTIONS.connect = connection_action_runtime.connect
MP.ACTIONS.set_username = connection_action_runtime.set_username
MP.ACTIONS.set_blind_col = connection_action_runtime.set_blind_col

MP.NETWORKING_INTERNAL.send_connection_identity = connection_action_runtime.send_identity
MP.NETWORKING_INTERNAL.send_connection_rejoin = connection_action_runtime.send_rejoin
MP.NETWORKING_INTERNAL.send_keep_alive_ack = connection_action_runtime.send_keep_alive_ack
