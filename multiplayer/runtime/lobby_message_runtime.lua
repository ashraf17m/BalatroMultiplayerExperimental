MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}

local lobby_message_runtime = {}
local load_required_service = MP.UTILS.load_required_service

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

function lobby_message_runtime.handle_lobby_info(players, is_host, is_in_game, lobby_type)
	apply_state_update("lobby_info", players, is_host, is_in_game, lobby_type)
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
MP.NETWORKING_INTERNAL.handle_lobby_player_joined = lobby_message_runtime.handle_lobby_player_joined
MP.NETWORKING_INTERNAL.handle_lobby_player_updated = lobby_message_runtime.handle_lobby_player_updated
MP.NETWORKING_INTERNAL.handle_lobby_player_left = lobby_message_runtime.handle_lobby_player_left
MP.NETWORKING_INTERNAL.handle_lobby_type_changed = lobby_message_runtime.handle_lobby_type_changed
MP.NETWORKING_INTERNAL.handle_lobby_player_team = lobby_message_runtime.handle_lobby_player_team
MP.NETWORKING_INTERNAL.handle_lobby_nemesis_assignments = lobby_message_runtime.handle_lobby_nemesis_assignments
MP.NETWORKING_INTERNAL.handle_lobby_options = lobby_message_runtime.handle_lobby_options
