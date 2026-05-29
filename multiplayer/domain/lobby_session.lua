MP.DOMAIN = MP.DOMAIN or {}
MP.DOMAIN.LOBBY = MP.DOMAIN.LOBBY or {}

local LOBBY_DOMAIN = MP.DOMAIN.LOBBY
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

function LOBBY_DOMAIN.clear_session(state)
	state = state or LOBBY_DOMAIN.ensure_state()

	state.code = nil
	LOBBY_DOMAIN.set_host_state(false, state)
	LOBBY_DOMAIN.set_match_in_progress(false, state)
	LOBBY_DOMAIN.set_players({}, state)
	LOBBY_DOMAIN.set_pending_ready(nil, state)

	return state
end

function LOBBY_DOMAIN.apply_info_snapshot(args, state)
	state = state or LOBBY_DOMAIN.ensure_state()
	args = args or {}

	local previous_match_in_progress = not not state.match_in_progress
	local previous_lobby_type = state.lobby_type or nil

	if args.lobby_type ~= nil then
		LOBBY_DOMAIN.set_lobby_type(args.lobby_type, state)
	end

	LOBBY_DOMAIN.set_host_state(args.is_host, state)
	LOBBY_DOMAIN.set_match_in_progress(args.is_in_game, state)
	LOBBY_DOMAIN.set_players(args.players, state)
	LOBBY_DOMAIN.set_pending_ready(nil, state)

	return {
		previous_match_in_progress = previous_match_in_progress,
		previous_lobby_type = previous_lobby_type,
		match_in_progress = not not state.match_in_progress,
		lobby_type = state.lobby_type or nil,
	}
end

local function upsert_player(player, state)
	state = state or LOBBY_DOMAIN.ensure_state()

	local previous_match_in_progress = not not state.match_in_progress
	local previous_lobby_type = state.lobby_type or nil
	local players = LOBBY_DOMAIN.get_players(state)
	local replaced = false

	for index, existing_player in ipairs(players) do
		if existing_player.id == player.id then
			players[index] = player
			replaced = true
			break
		end
	end

	if not replaced then
		table.insert(players, player)
	end

	return {
		previous_match_in_progress = previous_match_in_progress,
		previous_lobby_type = previous_lobby_type,
		match_in_progress = not not state.match_in_progress,
		lobby_type = state.lobby_type or nil,
	}
end

function LOBBY_DOMAIN.apply_player_joined(player, state)
	return upsert_player(player, state)
end

function LOBBY_DOMAIN.apply_player_updated(player, state)
	return upsert_player(player, state)
end

function LOBBY_DOMAIN.apply_nemesis_assignments(assignments, state)
	local players = LOBBY_DOMAIN.get_players(state)
	local changed = false

	for _, assignment in ipairs(assignments or {}) do
		local player_id = assignment.playerId
		for _, player in ipairs(players) do
			if player.id == player_id then
				player.nemesis_player_id = assignment.nemesisPlayerId
				changed = true
				break
			end
		end
	end

	return changed
end

function LOBBY_DOMAIN.begin_session(args, state)
	state = state or LOBBY_DOMAIN.ensure_state()
	args = args or {}

	state.code = args.code
	LOBBY_DOMAIN.set_match_in_progress(args.match_in_progress, state)
	LOBBY_DOMAIN.set_host_state(args.is_host, state)
	LOBBY_DOMAIN.set_players(args.players, state)
	LOBBY_DOMAIN.set_lobby_type(args.lobby_type or state.lobby_type or "", state)

	if args.gamemode then
		state.config.gamemode = LOBBY_DOMAIN.normalize_gamemode(args.gamemode)
	end

	if args.player_id ~= nil then
		BALATRO.set_player_id(args.player_id)
	end

	LOBBY_DOMAIN.set_pending_ready(nil, state)
	return state
end

return LOBBY_DOMAIN
