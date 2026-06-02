if MP.PLATFORM.SMODS.is_mod_loadable("ortalab") then
	sendDebugMessage("Ortalab compatibility detected", "MULTIPLAYER")
	MP.DECK.ban_cards({
		"j_ortalab_miracle_cure",
		"j_ortalab_grave_digger",
		"v_ortalab_abacus",
		"v_ortalab_calculator",
	})
end
