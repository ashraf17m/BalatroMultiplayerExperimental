function MP.should_use_the_order()
	return MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.the_order and MP.LOBBY.code
end

function MP.is_major_league_ruleset()
	return MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.ruleset == "ruleset_mp_majorleague" and MP.LOBBY.code
end

function MP.is_ffa_mode()
	return MP.LOBBY and MP.LOBBY.lobby_type == MP.LOBBY_TYPES.FFA
end

function MP.is_teams_mode()
	return MP.LOBBY and MP.is_team_lobby_type and MP.is_team_lobby_type(MP.LOBBY.lobby_type)
end

function MP.is_1v1_mode()
	return MP.LOBBY and MP.is_head_to_head_lobby_type and MP.is_head_to_head_lobby_type(MP.LOBBY.lobby_type)
end

function MP.is_group_mode()
	return MP.LOBBY and MP.is_group_lobby_type and MP.is_group_lobby_type(MP.LOBBY.lobby_type)
end

function MP.is_in_lobby_session()
	return not not (MP.LOBBY and MP.LOBBY.code)
end

function MP.is_coop_gamemode()
	return MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.gamemode == "gamemode_mp_coop"
end

function MP.get_coop_player_count()
	local count = 0
	for _, player in pairs((MP.LOBBY and MP.LOBBY.players) or {}) do
		if player and player.is_in_match ~= false and player.is_disconnected ~= true then
			count = count + 1
		end
	end
	return math.max(1, count)
end

function MP.get_coop_blind_multiplier()
	local per_player = tonumber(MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.coop_blind_scaling_per_player) or 1
	per_player = math.max(0, per_player)
	return math.max(1, 1 + (MP.get_coop_player_count() - 1) * per_player)
end

function MP.scale_coop_blind_amount(amount)
	if not (MP.is_coop_gamemode and MP.is_coop_gamemode()) then return amount end

	local numeric_amount = tonumber(amount)
	if not numeric_amount then return amount end

	return math.max(1, math.floor(numeric_amount * MP.get_coop_blind_multiplier() + 0.5))
end

function MP.is_coop_blind()
	return (MP.is_coop_gamemode and MP.is_coop_gamemode()) and not (MP.is_pvp_boss and MP.is_pvp_boss())
end

function MP.is_server_resolved_blind()
	return MP.is_pvp_boss() or MP.is_team_cooperative_blind() or (MP.is_coop_blind and MP.is_coop_blind())
end
