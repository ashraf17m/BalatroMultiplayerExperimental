-- Pocket Aces - Extra Credit Joker ported to Sandbox
-- Gives $ at end of round, played Aces increase payout, resets each Ante

MP.EC.register_sandbox_joker({
	key = "pocketaces_sandbox",
	blueprint_compat = false,
	eternal_compat = true,
	perishable_compat = true,
	rarity = 2,
	cost = 7,
	pos = { x = 5, y = 0 },
	config = { extra = { money = 0, m_gain = 2 } },

	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.money, card.ability.extra.m_gain } }
	end,

	calc_dollar_bonus = function(self, card)
		local thunk = card.ability.extra.money
		if G.GAME.blind.boss then card.ability.extra.money = 0 end
		return thunk
	end,

	calculate = function(self, card, context)
		if
			context.individual
			and context.cardarea == G.play
			and MP.GRADIENT.matches_rank(context.other_card, 14)
			and not context.blueprint
		then
			card.ability.extra.money = card.ability.extra.money + card.ability.extra.m_gain
		end
	end,

	mp_credits = { code = { "CampfireCollective" }, art = { "Wingcap" } },
})
