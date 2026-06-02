if MP.PLATFORM.SMODS.is_mod_loadable("upgrademod") then
	function action_asteroid()
		local hand_type = MP.PLATFORM.BALATRO.get_highest_level_poker_hand(function(_, hand_state)
			return hand_state.visible
		end)

		MP.PLATFORM.SMODS.upgrade_poker_hands({
			hands = hand_type,
			level_up = -((asteroid_factor or 1) * (planet_level or 1)),
		})
	end
end
