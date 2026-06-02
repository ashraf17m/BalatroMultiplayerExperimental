MP.DOMAIN = MP.DOMAIN or {}
MP.DOMAIN.END_GAME = MP.DOMAIN.END_GAME or {}

local END_GAME_DOMAIN = MP.DOMAIN.END_GAME

function END_GAME_DOMAIN.build_view_state()
	return {
		players = nil,
		standings_participants = nil,
		target_id = nil,
		target_index = 1,
	}
end

function END_GAME_DOMAIN.ensure_view_state()
	END_GAME_DOMAIN.view_state = END_GAME_DOMAIN.view_state or END_GAME_DOMAIN.build_view_state()
	return END_GAME_DOMAIN.view_state
end

function END_GAME_DOMAIN.reset_view_state()
	END_GAME_DOMAIN.view_state = END_GAME_DOMAIN.build_view_state()
	return END_GAME_DOMAIN.view_state
end

local function copy_player_snapshot(player)
	return {
		id = player.id,
		username = player.username,
		blind_col = player.blind_col,
		team = player.team,
		is_owner = player.is_owner,
		is_in_match = player.is_in_match,
		config = player.config,
	}
end

local function copy_standings_player_snapshot(player)
	return {
		id = player.id,
		username = player.username,
		blind_col = player.blind_col,
		team = player.team,
		is_self = player.is_self,
		lives = player.lives,
		hands = player.hands,
		score_text = player.score_target_text or player.score_text,
		config = player.config,
	}
end

local function build_standings_participant_snapshot(players)
	local snapshot = {}

	for _, player in ipairs(players or {}) do
		snapshot[#snapshot + 1] = copy_standings_player_snapshot(player)
	end

	return snapshot
end

local function build_viewable_player_snapshot(players, self_player_id)
	local snapshot = {}

	for _, player in ipairs(players or {}) do
		if player.id ~= self_player_id then
			snapshot[#snapshot + 1] = copy_player_snapshot(player)
		end
	end

	return snapshot
end

function END_GAME_DOMAIN.get_standings_participants()
	local state = END_GAME_DOMAIN.ensure_view_state()
	return state.standings_participants or {}
end

function END_GAME_DOMAIN.get_viewable_players(lobby_players, self_player_id)
	local state = END_GAME_DOMAIN.ensure_view_state()
	if state.players then
		return state.players
	end

	return build_viewable_player_snapshot(lobby_players, self_player_id)
end

function END_GAME_DOMAIN.capture_view_players(lobby_players, self_player_id, standings_players)
	local state = END_GAME_DOMAIN.ensure_view_state()
	local standings_participants = build_standings_participant_snapshot(standings_players)
	local snapshot = build_viewable_player_snapshot(lobby_players, self_player_id)

	state.standings_participants = standings_participants
	state.players = snapshot
	state.target_index = 1
	state.target_id = snapshot[1] and snapshot[1].id or nil

	return snapshot
end

function END_GAME_DOMAIN.resolve_view_target(lobby_players, self_player_id)
	local state = END_GAME_DOMAIN.ensure_view_state()
	local players = END_GAME_DOMAIN.get_viewable_players(lobby_players, self_player_id)

	if #players == 0 then
		state.target_index = 1
		state.target_id = nil
		return players, nil, nil
	end

	local target_index = nil
	if state.target_id then
		for i, player in ipairs(players) do
			if player.id == state.target_id then
				target_index = i
				break
			end
		end
	end

	if not target_index then
		target_index = state.target_index or 1
		target_index = math.min(math.max(target_index, 1), #players)
	end

	local target = players[target_index]
	state.target_index = target_index
	state.target_id = target and target.id or nil

	return players, target, target_index
end

function END_GAME_DOMAIN.select_view_target(target, lobby_players, self_player_id)
	local state = END_GAME_DOMAIN.ensure_view_state()
	state.target_id = target and target.id or nil

	if state.target_id == nil then
		state.target_index = 1
		return nil
	end

	local players = END_GAME_DOMAIN.get_viewable_players(lobby_players, self_player_id)
	for i, player in ipairs(players) do
		if player.id == state.target_id then
			state.target_index = i
			return player
		end
	end

	return target
end

return END_GAME_DOMAIN
