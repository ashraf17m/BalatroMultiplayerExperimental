if MP.PLATFORM.SMODS.has_found_mod("StrangePencil") then
	sendDebugMessage("Strange Pencil compatibility detected", "MULTIPLAYER")
	MP.DECK.ban_cards({
		"j_pencil_calendar", -- potential desync
		"j_pencil_stonehenge", -- unfair advantage, also potential desync
		"c_pencil_chisel", -- might break phantom
		"c_pencil_peek", -- same reason as Matador

		-- cannot insta-win in multiplayer
		"j_pencil_forbidden_one",
		"j_pencil_left_arm",
		"j_pencil_left_leg",
		"j_pencil_right_arm",
		"j_pencil_right_leg",
	})
end
