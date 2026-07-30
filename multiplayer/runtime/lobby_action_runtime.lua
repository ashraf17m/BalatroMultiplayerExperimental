MP.ACTIONS = MP.ACTIONS or {}

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
