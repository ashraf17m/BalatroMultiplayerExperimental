MP.EC.register_sandbox_joker({
	key = "alloy_sandbox",
	blueprint_compat = false,
	eternal_compat = true,

	rarity = 2,
	cost = 7,
	pos = { x = 4, y = 4 },
	loc_vars = function(self, info_queue, card)
		info_queue[#info_queue + 1] = G.P_CENTERS.m_gold
		info_queue[#info_queue + 1] = G.P_CENTERS.m_steel
		return
	end,

	calculate = function(self, card, context)
		if context.check_enhancement then
			if context.other_card.config.center.key == "m_gold" then return { m_steel = true } end
			if context.other_card.config.center.key == "m_steel" then return { m_gold = true } end
		end
	end,

	mp_credits = {
		code = { "CampfireCollective" },
		art = { "dottykitty" },
	},
})
