function G.FUNCS.kick_player(e)
	if e and e.config and e.config.id then
		local player_id = string.match(e.config.id, "(.+)_kick")
		if player_id then
			MP.ACTIONS.kick_player(player_id)
		end
	end
end

function G.FUNCS.make_player_host(e)
	if e and e.config and e.config.id then
		local player_id = string.match(e.config.id, "(.+)_make_host")
		if player_id then
			MP.ACTIONS.make_player_host(player_id)
		end
	end
end
