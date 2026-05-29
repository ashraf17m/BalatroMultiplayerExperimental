if MP.PLATFORM.SMODS.is_mod_loadable("Pokermon") then
	sendDebugMessage("Pokermon compatibility detected", "MULTIPLAYER")
	MP.DECK.ban_cards({
		"j_poke_koffing",
		"j_poke_weezing",
		"j_poke_mimikyu",
	})
end
