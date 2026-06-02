MP.BLIND_CHOICE_INTERNAL = MP.BLIND_CHOICE_INTERNAL or {}

local INTERNAL = MP.BLIND_CHOICE_INTERNAL
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}

function INTERNAL.get_team_skip_ready_progress(row)
	local target_location = "loc_ready_to_skip_for_team_row-" .. tostring(row)
	local self_team_id = MP.get_self_team_id and MP.get_self_team_id() or nil
	if not MP.LOBBY or not MP.LOBBY.players then
		return 0, 0
	end
	local use_coop_group = MP.is_coop_lobby_type and MP.is_coop_lobby_type()
	if not use_coop_group and not self_team_id then
		return 0, 0
	end

	local ready_count = 0
	local total_count = 0
	for _, player in ipairs(MP.LOBBY.players) do
		local is_active = player.is_in_match ~= false and player.is_disconnected ~= true
		local is_vote_member = is_active and (use_coop_group or (player.team or 1) == self_team_id)
		if is_vote_member then
			total_count = total_count + 1
			if player.id == (MP.PLATFORM.BALATRO.get_player_id and MP.PLATFORM.BALATRO.get_player_id() or nil) then
				if MP.GAME and MP.GAME.location == target_location then
					ready_count = ready_count + 1
				end
			else
				local enemy = MP.GAME and MP.GAME.enemies and MP.GAME.enemies[player.id]
				if enemy and enemy.raw_location == target_location then
					ready_count = ready_count + 1
				end
			end
		end
	end

	return ready_count, total_count
end

function INTERNAL.reset_ready_blind_state()
	if match_domain.reset_ready_blind_state then
		match_domain.reset_ready_blind_state()
	end
end

function INTERNAL.set_selecting_location()
	MP.ACTIONS.set_location("loc_selecting")
end

function INTERNAL.refresh_timer_hud()
	if MP.UI and MP.UI.refresh_timer_hud_binding then
		MP.UI.refresh_timer_hud_binding()
	end
end

function INTERNAL.finish_unready_blind(was_readying_pvp_blind, reset_location)
	if reset_location then
		INTERNAL.set_selecting_location()
	end
	local is_group_mode = MP.is_group_lobby_type and MP.is_group_lobby_type(MP.LOBBY and MP.LOBBY.lobby_type)
	if was_readying_pvp_blind and not is_group_mode then
		MP.ACTIONS.pause_ante_timer()
	end
	MP.ACTIONS.unready_blind()
end

function INTERNAL.get_ready_blind_location(row)
	local uses_row_ready_location = row
		and (
			(MP.is_teams_mode() and INTERNAL.is_teams_cooperative_row(row))
			or (MP.is_coop_lobby_type and MP.is_coop_lobby_type())
		)
	if uses_row_ready_location then
		return "loc_ready_for_team_row-" .. row
	end
	return "loc_ready"
end

function INTERNAL.clear_skip_ready_state()
	if MP.GAME and match_domain.set_skip_ready_blind_row then
		match_domain.set_skip_ready_blind_row(nil)
	end
end

function INTERNAL.clear_ready_blind_for_skip_toggle()
	if not MP.GAME.ready_blind then
		return
	end
	local was_readying_pvp_blind = INTERNAL.is_readying_pvp_blind and INTERNAL.is_readying_pvp_blind()
	INTERNAL.reset_ready_blind_state()
	INTERNAL.finish_unready_blind(was_readying_pvp_blind, false)
	INTERNAL.refresh_timer_hud()
end

function INTERNAL.clear_skip_ready_for_blind_toggle(reset_location)
	if not MP.GAME.skip_ready_blind_row then
		return
	end
	INTERNAL.clear_skip_ready_state()
	MP.ACTIONS.unready_skip_blind()
	if reset_location then
		INTERNAL.set_selecting_location()
	end
end

return INTERNAL
