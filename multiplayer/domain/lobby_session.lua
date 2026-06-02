MP.DOMAIN = MP.DOMAIN or {}
MP.DOMAIN.LOBBY = MP.DOMAIN.LOBBY or {}

local LOBBY_DOMAIN = MP.DOMAIN.LOBBY
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function build_session_update_result(state, previous_match_in_progress, previous_lobby_type)
	return {
		previous_match_in_progress = previous_match_in_progress,
		previous_lobby_type = previous_lobby_type,
		match_in_progress = not not state.match_in_progress,
		lobby_type = state.lobby_type or nil,
	}
end

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

	return build_session_update_result(state, previous_match_in_progress, previous_lobby_type)
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

	return build_session_update_result(state, previous_match_in_progress, previous_lobby_type)
end

function LOBBY_DOMAIN.apply_player_joined(player, state)
	return upsert_player(player, state)
end

function LOBBY_DOMAIN.apply_player_updated(player, state)
	state = state or LOBBY_DOMAIN.ensure_state()
	local result = upsert_player(player, state)

	local self_player_id = BALATRO.get_player_id and BALATRO.get_player_id() or nil
	local pending_ready = state.client and state.client.pending_lobby_ready
	if player and player.id == self_player_id and pending_ready ~= nil then
		LOBBY_DOMAIN.set_pending_ready(nil, state)
	end

	return result
end

local function refresh_player_management_flags(players, state, owner_player_id)
	local self_player_id = BALATRO.get_player_id and BALATRO.get_player_id() or nil
	for _, player in ipairs(players or LOBBY_DOMAIN.get_players(state)) do
		if owner_player_id ~= nil then
			player.is_owner = player.id == owner_player_id
		end
		local can_manage = state.is_host and player.id ~= self_player_id and not player.is_owner
		player.can_kick = can_manage
		player.can_make_host = can_manage
	end
end

function LOBBY_DOMAIN.apply_player_left(player_id, is_host, owner_player_id, assignments, state)
	state = state or LOBBY_DOMAIN.ensure_state()

	local previous_match_in_progress = not not state.match_in_progress
	local previous_lobby_type = state.lobby_type or nil
	local remaining_players = {}

	for _, player in ipairs(LOBBY_DOMAIN.get_players(state)) do
		if player.id ~= player_id then
			table.insert(remaining_players, player)
		end
	end

	LOBBY_DOMAIN.set_players(remaining_players, state)
	LOBBY_DOMAIN.set_host_state(is_host, state)
	LOBBY_DOMAIN.apply_nemesis_assignments(assignments, state)

	refresh_player_management_flags(remaining_players, state, owner_player_id)

	return build_session_update_result(state, previous_match_in_progress, previous_lobby_type)
end

function LOBBY_DOMAIN.apply_type_changed(lobby_type, player_updates, state)
	state = state or LOBBY_DOMAIN.ensure_state()

	local previous_match_in_progress = not not state.match_in_progress
	local previous_lobby_type = state.lobby_type or nil

	if lobby_type ~= nil then
		LOBBY_DOMAIN.set_lobby_type(lobby_type, state)
	end

	local updates_by_id = {}
	for _, update in ipairs(player_updates or {}) do
		if type(update) == "table" and update.playerId ~= nil then
			updates_by_id[update.playerId] = update
		end
	end

	local uses_lobby_ready = MP.lobby_uses_ready and MP.lobby_uses_ready() or false
	local players = LOBBY_DOMAIN.get_players(state)
	for _, player in ipairs(players) do
		local update = updates_by_id[player.id]
		if update then
			local team = update.team
			local is_ready = update.isReadyLobby

			player.team = team
			player.team_name = MP.TEAM_NAMES[team or 1] or "TEAM"
			player.is_team_locked = not not update.isTeamLocked
			player.is_ready = is_ready
			player.nemesis_player_id = update.nemesisPlayerId

			if uses_lobby_ready then
				player.status_text = is_ready and localize("b_ready") or localize("b_unready")
				player.status_kind = is_ready and "ready" or "waiting"
			else
				player.status_text = nil
				player.status_kind = nil
			end
		end
	end

	LOBBY_DOMAIN.set_pending_ready(nil, state)
	refresh_player_management_flags(players, state)

	return build_session_update_result(state, previous_match_in_progress, previous_lobby_type)
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
