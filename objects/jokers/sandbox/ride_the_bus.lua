SMODS.Atlas({
	key = "ride_the_bus_sandbox",
	path = "j_ride_the_bus_sandbox.png",
	px = 71,
	py = 95,
})

SMODS.Joker({
	key = "ride_the_bus_sandbox",
	blueprint_compat = true,
	perishable_compat = false,
	no_collection = MP.sandbox_no_collection,

	unlocked = true,
	discovered = true,
	rarity = 1,
	cost = 6,
	atlas = "ride_the_bus_sandbox",
	config = { extra = { mult_gain = 1, mult = 0, max_gain = 5 }, mp_sticker_balanced = true },
	loc_vars = function(self, info_queue, card)
		return { vars = { card.ability.extra.mult } }
	end,
	calculate = function(self, card, context)
		if context.before and context.main_eval and not context.blueprint then
			local faces = false
			for _, playing_card in ipairs(context.scoring_hand) do
				if playing_card:is_face() then
					faces = true
					break
				end
			end
			if faces then
				MP.SANDBOX.destroy_joker(card)
				card_eval_status_text(card, "extra", nil, nil, nil, { message = localize("k_extinct_ex") })
			else
				card.ability.extra.mult = card.ability.extra.mult + card.ability.extra.mult_gain
				if card.ability.extra.mult_gain < card.ability.extra.max_gain then
					card.ability.extra.mult_gain = card.ability.extra.mult_gain + 1
				end
			end
		end
		if context.joker_main then return {
			mult = card.ability.extra.mult,
		} end
	end,
	mp_credits = { code = { "steph" } },
	mp_include = MP.SANDBOX.include_joker,
})
