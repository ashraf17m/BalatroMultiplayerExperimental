SMODS.Atlas({
	key = "vampire_sandbox",
	path = "j_vampire_sandbox.png",
	px = 71,
	py = 95,
})

local function has_stone_enhancement(card)
	return SMODS.has_enhancement(card, "m_stone")
end

MP.SANDBOX.register_joker({
	key = "vampire_sandbox",
	blueprint_compat = true,
	perishable_compat = false,
	rarity = 2,
	cost = 7,
	atlas = "vampire_sandbox",
	config = { extra = { Xmult_gain = 0.2, Xmult = 1, stone_money = 3 }, mp_sticker_balanced = true },
	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.Xmult_gain, card.ability.extra.Xmult, card.ability.extra.stone_money } }
	end,
	calculate = function(self, card, context)
		if context.before and context.main_eval and not context.blueprint then
			local enhanced = {}
			local stone_cards = {}
			for _, scored_card in ipairs(context.scoring_hand) do
				if
					next(SMODS.get_enhancements(scored_card))
					and not scored_card.debuff
					and not scored_card.vampired
					and not has_stone_enhancement(scored_card)
				then
					enhanced[#enhanced + 1] = scored_card
					scored_card.vampired = true
					scored_card:set_ability("m_stone", nil, true)
					G.E_MANAGER:add_event(Event({
						func = function()
							scored_card:juice_up()
							scored_card.vampired = nil
							return true
						end,
					}))
				elseif has_stone_enhancement(scored_card) and not scored_card.debuff then
					stone_cards[#stone_cards + 1] = scored_card
				end
			end

			if #enhanced > 0 then
				card.ability.extra.Xmult = card.ability.extra.Xmult + card.ability.extra.Xmult_gain * #enhanced
				return {
					message = localize({ type = "variable", key = "a_xmult", vars = { card.ability.extra.Xmult } }),
					colour = G.C.MULT,
				}
			end

			if #stone_cards > 0 then
				ease_dollars(card.ability.extra.stone_money * #stone_cards)
				return {
					message = localize("$") .. (card.ability.extra.stone_money * #stone_cards),
					colour = G.C.MONEY,
				}
			end
		end
		if context.joker_main then return {
			xmult = card.ability.extra.Xmult,
		} end
	end,
	mp_credits = { code = { "steph" } },
})
