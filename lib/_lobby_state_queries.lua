function MP.get_effective_lobby_deck()
	if not MP.LOBBY then
		return MP.build_lobby_deck_state()
	end

	local run_deck = MP.get_lobby_run_deck and MP.get_lobby_run_deck() or nil

	-- Let the host preview a local deck selection while waiting for the
	-- authoritative lobbyOptions echo to come back from the server.
	if MP.LOBBY.is_host and MP.LOBBY.code and run_deck then
		return run_deck
	end

	if MP.LOBBY.config and MP.LOBBY.config.different_decks then
		return run_deck or MP.build_initial_lobby_run_deck_state()
	end

	return MP.build_lobby_run_deck_from_config()
end

function MP.get_lobby_player_count()
	if not MP.LOBBY or not MP.LOBBY.players then
		return 0
	end

	return #MP.LOBBY.players
end

function MP.lobby_uses_ready()
	return MP.is_1v1_mode()
end

function MP.is_self_lobby_ready()
	local player = MP.get_self_lobby_player()
	return not not (player and player.is_ready)
end

function MP.is_lobby_match_in_progress()
	return not not (MP.LOBBY and MP.LOBBY.match_in_progress)
end

local function get_lobby_team_count()
	if not MP.LOBBY or not MP.LOBBY.players then
		return 0
	end

	local teams = {}

	for _, player in ipairs(MP.LOBBY.players or {}) do
		teams[player.team or 1] = true
	end

	local count = 0
	for _, _ in pairs(teams) do
		count = count + 1
	end

	return count
end

function MP.get_lobby_start_block_reason()
	if MP.is_lobby_match_in_progress() then
		return "match_in_progress"
	end

	local player_count = MP.get_lobby_player_count()

	if MP.lobby_uses_ready() then
		if player_count ~= 2 then
			return "waiting_for_players"
		end

		for _, player in ipairs(MP.LOBBY.players or {}) do
			if not player.is_owner then
				if player.is_ready == true then
					return nil
				end

				return "waiting_for_guest_ready"
			end
		end

		return "waiting_for_players"
	end

	if player_count < 2 then
		return "waiting_for_players"
	end

	if MP.is_teams_mode() and get_lobby_team_count() < 2 then
		return "waiting_for_teams"
	end

	return nil
end

function MP.can_host_start_lobby()
	return MP.get_lobby_start_block_reason() == nil
end
