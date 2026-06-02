-- Candy Necklace - Extra Credit Joker ported to Sandbox
-- Random Booster Pack Tag at shop end (5 uses)

MP.EC.register_sandbox_joker({
	key = "candynecklace_sandbox",
	blueprint_compat = true,
	eternal_compat = false,
	rarity = 2,
	cost = 8,
	pos = { x = 9, y = 0 },
	config = {
		extra = {
			candies = 5,
			flavours = { "tag_buffoon", "tag_charm", "tag_meteor", "tag_standard", "tag_ethereal" },
		},
	},

	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.candies } }
	end,

	calculate = function(self, card, context)
		if context.ending_shop and card.ability.extra.candies > 0 then
			local tag_key = pseudorandom_element(card.ability.extra.flavours, pseudoseed("candy_tag"))
			add_tag(Tag(tag_key))

			if not context.blueprint then
				card.ability.extra.candies = card.ability.extra.candies - 1

				if card.ability.extra.candies <= 0 then
					MP.EC.destroy_joker(card)
					return {
						message = localize("k_eaten_ex"),
						colour = G.C.MONEY,
					}
				end
			end
		end
	end,

	mp_credits = { code = { "CampfireCollective" }, art = { "dottykitty" } },
})
