local BALATRO = MP.PLATFORM.BALATRO
MP.DOMAIN = MP.DOMAIN or {}
MP.DOMAIN.TEAMS = MP.DOMAIN.TEAMS or {}
local TEAMS_DOMAIN = MP.DOMAIN.TEAMS

local function get_team_display_name(team_idx)
	return MP.TEAM_NAMES[team_idx or 1] or ((localize("k_team") or "Team") .. " " .. tostring(team_idx or 1))
end

function TEAMS_DOMAIN.get_short_display_name(team_idx)
	local team_name = string.upper(get_team_display_name(team_idx))
	if #team_name <= 3 then
		return team_name
	end

	return string.sub(team_name, 1, 3)
end

local function set_local_lobby_player_team(player_id, team_id)
	local player = MP.get_lobby_player_by_id and MP.get_lobby_player_by_id(player_id) or nil
	if not player then
		return false
	end

	player.team = team_id
	player.team_name = MP.TEAM_NAMES[team_id] or player.team_name or "TEAM"
	return true
end

local function set_local_lobby_player_team_lock(player_id, locked)
	local player = MP.get_lobby_player_by_id and MP.get_lobby_player_by_id(player_id) or nil
	if not player then
		return false
	end

	player.is_team_locked = not not locked
	return true
end

function TEAMS_DOMAIN.can_edit_lobby_player_team(player_id, opts)
	local options = opts or {}
	local lobby_context = options.lobby_context or (MP.get_lobby_state_context and MP.get_lobby_state_context()) or {}
	if not lobby_context.is_teams_mode or lobby_context.match_in_progress then
		return false
	end

	if lobby_context.is_host then
		return true
	end

	local player = MP.get_lobby_player_by_id and MP.get_lobby_player_by_id(player_id) or nil
	return player_id == BALATRO.get_player_id() and not not player and not player.is_team_locked
end

local function can_toggle_lobby_player_team_lock(player_id, opts)
	local options = opts or {}
	local lobby_context = options.lobby_context or (MP.get_lobby_state_context and MP.get_lobby_state_context()) or {}
	if not player_id or player_id == BALATRO.get_player_id() then
		return false
	end

	if not lobby_context.is_host or not lobby_context.is_teams_mode or lobby_context.match_in_progress then
		return false
	end

	return not not (MP.get_lobby_player_by_id and MP.get_lobby_player_by_id(player_id))
end

function TEAMS_DOMAIN.apply_local_lobby_team_choice(player_id, team_id, opts)
	local numeric_team_id = tonumber(team_id)
	if not player_id or not numeric_team_id or not TEAMS_DOMAIN.can_edit_lobby_player_team(player_id, opts) then
		return nil
	end

	if numeric_team_id < 1 or numeric_team_id > MP.MAX_TEAMS then
		return nil
	end

	if not set_local_lobby_player_team(player_id, numeric_team_id) then
		return nil
	end

	return numeric_team_id
end

function TEAMS_DOMAIN.toggle_local_lobby_player_team_lock(player_id, opts)
	if not can_toggle_lobby_player_team_lock(player_id, opts) then
		return nil
	end

	local player = MP.get_lobby_player_by_id and MP.get_lobby_player_by_id(player_id) or nil
	local next_locked = not not (player and not player.is_team_locked)
	if not set_local_lobby_player_team_lock(player_id, next_locked) then
		return nil
	end

	return next_locked
end

function MP.get_self_team_id()
	local player = MP.get_self_lobby_player()
	if not player then
		return nil
	end
	if MP.LOBBY and MP.LOBBY.match_in_progress and not player.is_in_match then
		return nil
	end
	return player.team or 1
end
