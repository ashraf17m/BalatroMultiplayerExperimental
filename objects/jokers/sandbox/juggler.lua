SMODS.Atlas({
	key = "juggler_sandbox",
	path = "j_juggler_sandbox.png",
	px = 71,
	py = 95,
})
SMODS.Joker({
	key = "juggler_sandbox",
	no_collection = MP.sandbox_no_collection,

	unlocked = true,
	discovered = true,
	blueprint_compat = false,
	rarity = 1,
	cost = 4,
	atlas = "juggler_sandbox",
	config = { extra = { h_size = 3 }, mp_sticker_balanced = true },
	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.h_size } }
	end,
	add_to_deck = function(self, card, from_debuff)
		G.hand:change_size(card.ability.extra.h_size)
	end,
	remove_from_deck = function(self, card, from_debuff)
		G.hand:change_size(-card.ability.extra.h_size)
	end,
	calculate = function(self, card, context)
		if context.before and context.main_eval and not context.blueprint then
			if #context.full_hand < 5 then
				card.ability.extra.h_size = card.ability.extra.h_size - 1
				G.hand:change_size(-1)
				card_eval_status_text(card, "extra", nil, nil, nil, { message = "-1 Hand Size" })

				if card.ability.extra.h_size <= 0 then
					MP.SANDBOX.destroy_joker(card)
					card_eval_status_text(card, "extra", nil, nil, nil, { message = localize("k_extinct_ex") })
				end
			end
		end
	end,
	mp_credits = { code = { "steph" } },
	mp_include = MP.SANDBOX.include_joker,
})
