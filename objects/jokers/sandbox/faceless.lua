SMODS.Atlas({
	key = "faceless_sandbox",
	path = "j_faceless_sandbox.png",
	px = 71,
	py = 95,
})

SMODS.Joker({
	key = "faceless_sandbox",
	no_collection = MP.sandbox_no_collection,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	rarity = 1,
	cost = 4,
	atlas = "faceless_sandbox",
	config = { extra = { dollars = 15 }, mp_sticker_balanced = true },
	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.dollars } }
	end,
	calculate = function(self, card, context)
		if context.discard and context.other_card == context.full_hand[#context.full_hand] then
			local jacks = 0
			local queens = 0
			local kings = 0

			for _, discarded_card in ipairs(context.full_hand) do
				if MP.GRADIENT.matches_rank(discarded_card, 11) then jacks = jacks + 1 end
				if MP.GRADIENT.matches_rank(discarded_card, 12) then queens = queens + 1 end
				if MP.GRADIENT.matches_rank(discarded_card, 13) then kings = kings + 1 end
			end

			if jacks >= 1 and queens >= 1 and kings >= 1 then
				return MP.CONTENT.RUNTIME.create_buffered_dollars_reward(card.ability.extra.dollars)
			end
		end
	end,
	mp_credits = { code = { "steph" } },
	mp_include = MP.SANDBOX.include_joker,
})
