if MP.PLATFORM.SMODS.is_mod_loadable("ExtraCredit") then
	sendDebugMessage("ExtraCredit compatibility detected", "MULTIPLAYER")
	MP.DECK.ban_card("j_ExtraCredit_permanentmarker")
end
