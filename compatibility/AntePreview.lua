if MP.PLATFORM.SMODS.has_found_mod("AntePreview") then
	sendDebugMessage("Next Ante Preview compatibility detected", "MULTIPLAYER")
	local teams_domain = MP.DOMAIN and MP.DOMAIN.TEAMS or {}
	local predict_next_ante_ref = predict_next_ante
	function predict_next_ante()
		local predictions = predict_next_ante_ref()
		if MP.LOBBY.code then
			local preview_ante = ((G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante) or 0) + 1
			local mp_small_choice, mp_big_choice, mp_boss_choice =
				teams_domain.resolve_lobby_blinds_for_ante(preview_ante)
			if predictions.Small and mp_small_choice then predictions.Small.blind = mp_small_choice end
			if predictions.Big and mp_big_choice then predictions.Big.blind = mp_big_choice end
			if predictions.Boss and mp_boss_choice then predictions.Boss.blind = mp_boss_choice end
		end
		return predictions
	end
end
