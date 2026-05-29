function G.FUNCS.kick_player(e)
	if e and e.config and e.config.id then
		local player_id = string.match(e.config.id, "(.+)_kick")
		if player_id then
			MP.request_lobby_overlay_refresh("players")
			MP.ACTIONS.kick_player(player_id)
		end
	end
end

function G.FUNCS.make_player_host(e)
	if e and e.config and e.config.id then
		local player_id = string.match(e.config.id, "(.+)_make_host")
		if player_id then
			MP.request_lobby_overlay_refresh("players")
			MP.ACTIONS.make_player_host(player_id)
		end
	end
end

function G.FUNCS.switch_team(e)
	local new_team = MP.get_next_local_self_team_choice and MP.get_next_local_self_team_choice() or nil
	if not new_team then
		return
	end

	MP.ACTIONS.set_team(new_team)

	if G.OVERLAY_MENU then
		G.FUNCS.exit_overlay_menu()
		G.FUNCS.view_players_list()
	end
end
