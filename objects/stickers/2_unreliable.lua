SMODS.Sticker({
	key = "sticker_unreliable",
	atlas = "alt_stickers",
	pos = { x = 1, y = 0 },
	badge_colour = HEX("7CA39A"),
	default_compat = false,
	needs_enable_flag = true,
})

MP.HOOKS.register_method_hook(Card, "Card", "calculate_joker", "mp.unreliable_sticker.phantom_only_on_last_hand", {
	before = function(ctx, self)
		if self.ability.mp_sticker_unreliable and G.GAME.current_round.hands_left == 0 then
			if not self.edition or self.edition.type ~= "mp_phantom" then
				ctx.skip_original = true
				ctx.results = { n = 0 }
			end
		end
	end,
})
