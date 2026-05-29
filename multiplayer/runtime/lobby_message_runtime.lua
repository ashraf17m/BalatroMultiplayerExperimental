MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}

local lobby_message_runtime = {}
local has_required_methods = MP.UTILS.has_required_methods

local function get_returned_runtime_surface(loaded, surface_name, required_method)
	if type(loaded) ~= "table" then
		return nil
	end
	if has_required_methods(loaded, required_method) then
		return loaded
	end
	if surface_name == "CONNECTION_SESSION" and has_required_methods(loaded.CONNECTION, required_method) then
		return loaded.CONNECTION
	end
	if surface_name == "LOBBY_SESSION" and has_required_methods(loaded.LOBBY, required_method) then
		return loaded.LOBBY
	end

	return nil
end

local function ensure_runtime_surface(surface_name, required_method, file_path)
	local surface = MP[surface_name] or nil
	if has_required_methods(surface, required_method) then
		return surface
	end

	local loaded = MP.PLATFORM.SMODS.load_mod_file(file_path, { required = true })
	if loaded == nil then
		return nil
	end
	local returned_surface = get_returned_runtime_surface(loaded, surface_name, required_method)
	if returned_surface then
		return returned_surface
	end

	surface = MP[surface_name] or nil
	if has_required_methods(surface, required_method) then
		return surface
	end

	return nil
end

local function ensure_state_apply_runtime(required_method)
	return ensure_runtime_surface("STATE_APPLY", required_method, "multiplayer/runtime/network_state_apply.lua")
end

local function ensure_session_runtime()
	return ensure_runtime_surface("LOBBY_SESSION", "apply_lobby_options", "multiplayer/runtime/session_runtime.lua")
end

function lobby_message_runtime.handle_lobby_info(players, is_host, is_in_game, lobby_type)
	local state_apply = ensure_state_apply_runtime("lobby_info")
	if state_apply and state_apply.lobby_info then
		state_apply.lobby_info(players, is_host, is_in_game, lobby_type)
	end
end

function lobby_message_runtime.handle_lobby_player_joined(player)
	local state_apply = ensure_state_apply_runtime("lobby_player_joined")
	if state_apply and state_apply.lobby_player_joined then
		state_apply.lobby_player_joined(player)
	end
end

function lobby_message_runtime.handle_lobby_player_updated(player)
	local state_apply = ensure_state_apply_runtime("lobby_player_updated")
	if state_apply and state_apply.lobby_player_updated then
		state_apply.lobby_player_updated(player)
	end
end

function lobby_message_runtime.handle_lobby_player_team(player_id, team_id)
	local state_apply = ensure_state_apply_runtime("lobby_player_team")
	if state_apply and state_apply.lobby_player_team then
		state_apply.lobby_player_team(player_id, team_id)
	end
end

function lobby_message_runtime.handle_lobby_nemesis_assignments(assignments)
	local state_apply = ensure_state_apply_runtime("lobby_nemesis_assignments")
	if state_apply and state_apply.lobby_nemesis_assignments then
		state_apply.lobby_nemesis_assignments(assignments)
	end
end

function lobby_message_runtime.handle_lobby_options(message)
	local lobby_session = ensure_session_runtime()
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
MP.NETWORKING_INTERNAL.handle_lobby_player_team = lobby_message_runtime.handle_lobby_player_team
MP.NETWORKING_INTERNAL.handle_lobby_nemesis_assignments = lobby_message_runtime.handle_lobby_nemesis_assignments
MP.NETWORKING_INTERNAL.handle_lobby_options = lobby_message_runtime.handle_lobby_options
