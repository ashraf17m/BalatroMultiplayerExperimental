local content_runtime = MP.CONTENT.RUNTIME

SMODS.Joker({
	key = "ticket",
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	rarity = 2,
	cost = 6,
	pos = { x = 5, y = 3 },
	config = { extra = { dollars = 3 }, mp_sticker_balanced = true },
	loc_vars = function(self, info_queue, card)
		info_queue[#info_queue + 1] = G.P_CENTERS.m_gold
		return { vars = { card.ability.extra.dollars } }
	end,
	calculate = function(self, card, context)
		if
			context.individual
			and context.cardarea == G.play
			and SMODS.has_enhancement(context.other_card, "m_gold")
		then
			return content_runtime.create_buffered_dollars_reward(card.ability.extra.dollars)
		end
	end,
	mp_include = content_runtime.include_standard_ruleset,
})
