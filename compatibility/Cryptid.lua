if MP.PLATFORM.SMODS.is_mod_loadable("Cryptid") then
	sendDebugMessage("Cryptid compatibility detected", "MULTIPLAYER")
	MP.DECK.ban_cards({
		"j_cry_fleshpanopticon",
		"j_cry_candy_sticks",
		"j_cry_redeo",
		"j_cry_chocolate_dice",
		"j_cry_carved_pumpkin",
		"j_cry_pumpkin",
		"v_cry_asteroglyph",
		"c_cry_semicolon",
		"c_cry_crash",
		"c_cry_revert",
		"c_cry_analog",
		"c_cry_reboot",
	})
	MP.DECK.ban_blind("bl_cry_joke")

	MP.HOOKS.register_method_hook(Blind, "Blind", "defeat", "mp.cryptid.nil_blind_key", {
		before = function(ctx, self)
			if self.config.blind.key == nil then self.config.blind.key = "bl_nil" end
		end,
		after = function(ctx)
			ctx.results = { n = 0 }
		end,
	})

	function wheel_of_fortune_the_title_card()
		return true
	end

	local get_random_consumable_ref = get_random_consumable
	function get_random_consumable(seed, excluded_flags, banned_card, pool, no_undiscovered)
		if not MP.LOBBY.code then
			return get_random_consumable_ref(seed, excluded_flags, banned_card, pool, no_undiscovered)
		end
		local tries = 5
		local card
		repeat
			card = get_random_consumable_ref(seed, excluded_flags, banned_card, pool, no_undiscovered)
			local is_banned = false

			for _, banned in ipairs(MP.DECK.BANNED_CARDS) do
				if card.key == banned.id then
					sendWarnMessage("Attempted to create banned card: " .. card.key .. ", trying again", "MULTIPLAYER")
					tries = tries - 1
					is_banned = true
					if tries <= 0 then
						sendWarnMessage("Attempted to create banned cards too many times, giving up.", "MULTIPLAYER")
						return card
					end
					break
				end
			end
		until not is_banned
		return card
	end

	MP.DECK.set_max_stake("stake_cry_emerald")
end
