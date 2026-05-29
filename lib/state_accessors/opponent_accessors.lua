local BALATRO = MP.PLATFORM.BALATRO

local function is_player_match_active(player)
	if not player then
		return false
	end

	if not MP.LOBBY or not MP.LOBBY.match_in_progress then
		return true
	end

	return not not player.is_in_match
end

local function is_lobby_opponent_player(player, opts)
	if not MP.LOBBY or not MP.LOBBY.players then
		return false
	end

	if not player or player.id == nil or player.id == BALATRO.get_player_id() then
		return false
	end

	local options = opts or {}
	if options.require_active and not is_player_match_active(player) then
		return false
	end

	if MP.is_teams_mode and MP.is_teams_mode() then
		local self_team_id = MP.get_self_team_id and MP.get_self_team_id() or nil
		if self_team_id == nil then
			return false
		end

		local player_team_id = player.team or 1
		if player_team_id == self_team_id then
			return false
		end
	end

	return true
end

local function collect_lobby_opponents(opts)
	if not MP.LOBBY or not MP.LOBBY.players then
		return {}
	end

	local opponents = {}
	for _, player in ipairs(MP.LOBBY.players) do
		if is_lobby_opponent_player(player, opts) then
			opponents[#opponents + 1] = player
		end
	end

	return opponents
end

function MP.get_lobby_opponent_players()
	return collect_lobby_opponents()
end

function MP.get_active_opponent_lobby_players()
	return collect_lobby_opponents({ require_active = true })
end

local function get_nemesis_player_id()
	local self_player = MP.get_self_lobby_player and MP.get_self_lobby_player() or nil
	if not self_player then
		return nil
	end

	return self_player.nemesis_player_id
end

function MP.get_nemesis_lobby_player()
	if not MP.LOBBY or not MP.LOBBY.players then
		return nil
	end

	local nemesis_player_id = get_nemesis_player_id()
	if not nemesis_player_id then
		return nil
	end

	for _, player in ipairs(MP.LOBBY.players) do
		if player.id == nemesis_player_id and is_lobby_opponent_player(player) then
			return player
		end
	end

	return nil
end

function MP.get_primary_opponent_lobby_player()
	local nemesis_player = MP.get_nemesis_lobby_player and MP.get_nemesis_lobby_player() or nil
	if nemesis_player then
		return nemesis_player
	end

	local active_opponents = MP.get_active_opponent_lobby_players and MP.get_active_opponent_lobby_players() or nil
	if active_opponents and #active_opponents > 0 then
		return active_opponents[1]
	end

	local lobby_opponents = MP.get_lobby_opponent_players and MP.get_lobby_opponent_players() or nil
	if lobby_opponents and #lobby_opponents > 0 then
		return lobby_opponents[1]
	end

	return nil
end
