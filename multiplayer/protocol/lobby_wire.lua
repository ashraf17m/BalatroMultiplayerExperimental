MP.LOBBY_WIRE = MP.LOBBY_WIRE or {}

local function build_lobby_action_payload(action_name, extra_fields)
	return MP.PROTOCOL.build_v2_packet_for_schema("lobby", "intent", action_name, extra_fields)
end

local function build_match_action_payload(action_name, extra_fields)
	return MP.PROTOCOL.build_v2_packet_for_schema("match", "intent", action_name, extra_fields)
end

local function normalize_team_id(team_id)
	local numeric_team_id = tonumber(team_id) or tonumber(tostring(team_id)) or 1
	if numeric_team_id ~= numeric_team_id or numeric_team_id == math.huge or numeric_team_id == -math.huge then
		numeric_team_id = 1
	end
	return math.floor(numeric_team_id)
end

function MP.LOBBY_WIRE.build_create_lobby_payload(gamemode, lobby_type, options)
	return build_lobby_action_payload("create", {
		gameMode = gamemode,
		lobbyType = lobby_type,
		options = options or {},
	})
end

function MP.LOBBY_WIRE.build_join_lobby_payload(code)
	return build_lobby_action_payload("join", {
		code = code,
	})
end

function MP.LOBBY_WIRE.build_ready_lobby_payload()
	return build_lobby_action_payload("ready")
end

function MP.LOBBY_WIRE.build_unready_lobby_payload()
	return build_lobby_action_payload("unready")
end

function MP.LOBBY_WIRE.build_leave_lobby_payload()
	return build_lobby_action_payload("leave")
end

function MP.LOBBY_WIRE.build_return_to_lobby_payload()
	return build_match_action_payload("returnToLobby", {})
end

function MP.LOBBY_WIRE.build_kick_player_payload(player_id)
	return build_lobby_action_payload("kick", {
		playerId = player_id,
	})
end

function MP.LOBBY_WIRE.build_make_player_host_payload(player_id)
	return build_lobby_action_payload("makeHost", {
		playerId = player_id,
	})
end

function MP.LOBBY_WIRE.build_set_team_payload(team_id, player_id)
	local payload = {
		team = normalize_team_id(team_id),
	}

	if player_id and player_id ~= "" then
		payload.playerId = player_id
	end

	return build_lobby_action_payload("setTeam", payload)
end

function MP.LOBBY_WIRE.build_set_team_lock_payload(player_id, locked)
	return build_lobby_action_payload("setTeamLock", {
		playerId = player_id,
		locked = not not locked,
	})
end

function MP.LOBBY_WIRE.build_set_lobby_type_payload(lobby_type)
	return build_lobby_action_payload("setType", {
		lobbyType = lobby_type,
	})
end

function MP.LOBBY_WIRE.should_full_sync_lobby_options(options, force_full_sync)
	if force_full_sync then
		return true
	end

	options = type(options) == "table" and options or {}
	return options.ruleset ~= nil or options.gamemode ~= nil
end

function MP.LOBBY_WIRE.extract_lobby_option_payload(message)
	if type(message) ~= "table" then
		return {}
	end

	if type(message.options) == "table" then
		return message.options
	end

	local sanitized = {}
	for key, value in pairs(message) do
		if key ~= "action" then
			sanitized[key] = value
		end
	end
	return sanitized
end

function MP.LOBBY_WIRE.build_lobby_option_update_action_payload(options)
	if type(options) ~= "table" then
		return nil
	end

	if next(options) ~= nil then
		return build_match_action_payload("lobbyOptions", {
			options = options,
		})
	end

	return nil
end
