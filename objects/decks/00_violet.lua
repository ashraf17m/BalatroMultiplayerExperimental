local voucher_discount_by_ante = {
	[1] = 0.5,
	[2] = 0.7,
}

SMODS.Back({
	key = "violet",
	config = {},
	atlas = "mp_decks",
	pos = { x = 0, y = 0 },
	mp_credits = { art = { "aura!" }, code = { "Toneblock" } },
	apply = function(self)
		SMODS.change_voucher_limit(1)
		G.GAME.modifiers.mp_violet = true
	end,
})

MP.HOOKS.register_method_hook(Card, "Card", "set_cost", "mp.violet_deck.voucher_discount", {
	after = function(ctx, self)
		local discount_multiplier = voucher_discount_by_ante[G.GAME.round_resets.ante]
		if G.GAME.modifiers.mp_violet and self.config.center.set == "Voucher" and discount_multiplier then
			self.cost = math.max(
				1,
				math.floor(discount_multiplier * (self.base_cost + self.extra_cost + 0.5) * (100 - G.GAME.discount_percent) / 100)
			)
		end
	end,
})
