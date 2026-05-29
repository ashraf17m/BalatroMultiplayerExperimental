local BALATRO = MP.PLATFORM.BALATRO

local function find_lobby_player(predicate)
	local players = MP.LOBBY and MP.LOBBY.players or nil
	if not players then
		return nil
	end

	for _, player in ipairs(players) do
		if predicate(player) then
			return player
		end
	end

	return nil
end

function MP.get_self_lobby_player()
	local player_id = BALATRO.get_player_id()
	return find_lobby_player(function(player)
		return player.id == player_id
	end)
end

function MP.get_lobby_owner()
	return find_lobby_player(function(player)
		return player.is_owner
	end)
end

function MP.get_lobby_player_by_id(player_id)
	return find_lobby_player(function(player)
		return player.id == player_id
	end)
end

function MP.get_lobby_state_context()
	local lobby = MP.LOBBY or {}
	local client = lobby.client or {}
	local players = lobby.players or {}
	local self_player = MP.get_self_lobby_player and MP.get_self_lobby_player() or nil

	return {
		code = lobby.code,
		lobby_type = lobby.lobby_type,
		config = lobby.config or {},
		client = client,
		players = players,
		player_count = #players,
		is_host = not not lobby.is_host,
		match_in_progress = not not lobby.match_in_progress,
		uses_lobby_ready = not not (MP.lobby_uses_ready and MP.lobby_uses_ready()),
		is_group_mode = not not (MP.is_group_mode and MP.is_group_mode()),
		is_teams_mode = not not (MP.is_teams_mode and MP.is_teams_mode()),
		self_player = self_player,
		self_team_id = (self_player and (self_player.team or 1)) or 1,
		run_deck = MP.get_lobby_run_deck and MP.get_lobby_run_deck() or {},
		effective_deck = MP.get_effective_lobby_deck and MP.get_effective_lobby_deck() or (lobby.config or {}),
	}
end

function MP.get_lobby_view_players(opts)
	local options = opts or {}
	local lobby_context = options.lobby_context or (MP.get_lobby_state_context and MP.get_lobby_state_context()) or {}
	local visible_players = {}
	local show_only_match_players = options.match_only
		and lobby_context.match_in_progress
		and lobby_context.self_player
		and lobby_context.self_player.is_in_match ~= false

	for _, player in ipairs(lobby_context.players or {}) do
		if not show_only_match_players or player.is_in_match ~= false then
			visible_players[#visible_players + 1] = player
		end
	end

	if MP.get_testing_dummy_players then
		for _, player in ipairs(MP.get_testing_dummy_players()) do
			if not show_only_match_players or player.is_in_match ~= false then
				visible_players[#visible_players + 1] = player
			end
		end
	end

	if options.sort_by_team and lobby_context.is_teams_mode then
		table.sort(visible_players, function(a, b)
			local team_a = a.team or 1
			local team_b = b.team or 1
			if team_a == team_b then
				return (a.username or "") < (b.username or "")
			end
			return team_a < team_b
		end)
	end

	return visible_players, lobby_context
end

function MP.get_lobby_player_display_index(player_id, opts)
	local options = opts or {}
	local players = MP.get_lobby_view_players and MP.get_lobby_view_players({
		lobby_context = options.lobby_context or (MP.get_lobby_state_context and MP.get_lobby_state_context()) or nil,
		sort_by_team = options.sort_by_team ~= false,
		match_only = options.match_only,
	}) or nil

	for index, player in ipairs(players or {}) do
		if player.id == player_id then
			return index
		end
	end

	return 1
end
