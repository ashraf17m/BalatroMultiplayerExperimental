local content_runtime = MP.CONTENT.RUNTIME

SMODS.Joker({
	key = "seltzer",
	no_collection = MP.should_hide_collection_item(),
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = false,
	rarity = 2,
	cost = 6,
	pos = { x = 3, y = 15 },
	config = { extra = { hands_left = 8 }, mp_sticker_balanced = true },
	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.hands_left } }
	end,
	calculate = function(self, card, context)
		if context.repetition and context.cardarea == G.play then return {
			repetitions = 1,
		} end
		if (context.after or (context.mp_pvp_loss and MP.is_layer_active("pvp_timer"))) and not context.blueprint then
			local hands_decrease = context.mp_pvp_loss and context.mp_hands_left or 1
			if card.ability.extra.hands_left - hands_decrease <= 0 then
				SMODS.destroy_cards(card, nil, nil, true)
				return {
					message = localize("k_drank_ex"),
					colour = G.C.FILTER,
				}
			else
				card.ability.extra.hands_left = card.ability.extra.hands_left - hands_decrease
				return {
					message = card.ability.extra.hands_left .. "",
					colour = G.C.FILTER,
				}
			end
		end
	end,
	mp_include = content_runtime.include_standard_ruleset,
})
