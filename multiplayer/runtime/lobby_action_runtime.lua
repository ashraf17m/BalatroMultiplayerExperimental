MP.ACTIONS = MP.ACTIONS or {}

local lobby_action_runtime = {}

function lobby_action_runtime.create_lobby(gamemode)
	Client.send(MP.LOBBY_WIRE.build_create_lobby_payload(gamemode))
end

function lobby_action_runtime.join_lobby(code)
	Client.send(MP.LOBBY_WIRE.build_join_lobby_payload(code))
end

function lobby_action_runtime.rejoin_lobby(code, reconnect_token)
	MP.CONNECTION_WIRE.send_rejoin(code, reconnect_token)
end

function lobby_action_runtime.ready_lobby()
	Client.send(MP.LOBBY_WIRE.build_ready_lobby_payload())
end

function lobby_action_runtime.unready_lobby()
	Client.send(MP.LOBBY_WIRE.build_unready_lobby_payload())
end

function lobby_action_runtime.lobby_info()
	Client.send(MP.LOBBY_WIRE.build_lobby_info_payload())
end

function lobby_action_runtime.leave_lobby()
	if MP.RESUME and MP.RESUME.clear_saved_resume then
		MP.RESUME.clear_saved_resume()
	end
	if MP.CONNECTION_SESSION and MP.CONNECTION_SESSION.clear_reconnect_lobby_state then
		MP.CONNECTION_SESSION.clear_reconnect_lobby_state()
	end
	Client.send(MP.LOBBY_WIRE.build_leave_lobby_payload())
end

function lobby_action_runtime.return_to_lobby()
	Client.send(MP.LOBBY_WIRE.build_return_to_lobby_payload())
end

function lobby_action_runtime.lobby_options(options, force_full_sync)
	if type(options) == "table" then
		if MP.LOBBY_WIRE.should_full_sync_lobby_options(options, force_full_sync) then
			lobby_action_runtime.sync_lobby_options_full(MP.LOBBY_WIRE.build_lobby_option_sync_payload(options))
		else
			MP.LOBBY_WIRE.send_lobby_option_update(options)
		end
	end
end

function lobby_action_runtime.lobby_options_full(options)
	lobby_action_runtime.lobby_options(options, true)
end

function lobby_action_runtime.sync_lobby_options_full(options)
	MP.LOBBY_WIRE.send_lobby_option_update(
		type(options) == "table" and options or MP.LOBBY_WIRE.build_full_lobby_option_update()
	)
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
	Client.send(MP.LOBBY_WIRE.build_set_lobby_type_payload(lobby_type))
end

MP.ACTIONS.create_lobby = lobby_action_runtime.create_lobby
MP.ACTIONS.join_lobby = lobby_action_runtime.join_lobby
MP.ACTIONS.rejoin_lobby = lobby_action_runtime.rejoin_lobby
MP.ACTIONS.ready_lobby = lobby_action_runtime.ready_lobby
MP.ACTIONS.unready_lobby = lobby_action_runtime.unready_lobby
MP.ACTIONS.lobby_info = lobby_action_runtime.lobby_info
MP.ACTIONS.leave_lobby = lobby_action_runtime.leave_lobby
MP.ACTIONS.return_to_lobby = lobby_action_runtime.return_to_lobby
MP.ACTIONS.lobby_options = lobby_action_runtime.lobby_options
MP.ACTIONS.lobby_options_full = lobby_action_runtime.lobby_options_full
MP.ACTIONS.sync_lobby_options_full = lobby_action_runtime.sync_lobby_options_full
MP.ACTIONS.kick_player = lobby_action_runtime.kick_player
MP.ACTIONS.make_player_host = lobby_action_runtime.make_player_host
MP.ACTIONS.set_team = lobby_action_runtime.set_team
MP.ACTIONS.set_team_lock = lobby_action_runtime.set_team_lock
MP.ACTIONS.set_lobby_type = lobby_action_runtime.set_lobby_type
