local content_runtime = MP.CONTENT.RUNTIME

SMODS.Atlas({
	key = "lets_go_gambling",
	path = "j_lets_go_gambling.png",
	px = 71,
	py = 95,
})

SMODS.Joker(content_runtime.with_phantom_sync_hooks({
	key = "lets_go_gambling",
	atlas = "lets_go_gambling",
	rarity = 2,
	cost = 6,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = true,
	perishable_compat = true,
	config = { extra = { odds = 4, xmult = 4, dollars = 10, nemesis_odds = 4, nemesis_dollars = 10 } },
	loc_vars = function(self, info_queue, card)
		local numerator, denominator =
			SMODS.get_probability_vars(card, 1, card.ability.extra.odds, "j_mp_lets_go_gambling")
		local nem_numerator, nem_denominator =
			SMODS.get_probability_vars(card, 1, card.ability.extra.nemesis_odds, "j_mp_lets_go_gambling_misfire")
		return {
			vars = {
				numerator,
				denominator,
				card.ability.extra.xmult,
				card.ability.extra.dollars,
				nem_numerator,
				nem_denominator,
				card.ability.extra.nemesis_dollars,
			},
		}
	end,
	mp_include = content_runtime.include_multiplayer_jokers,
	calculate = function(self, card, context)
		if
			context.cardarea == G.jokers
			and context.joker_main
			and not content_runtime.is_phantom_card(card)
		then
			local returns = nil
			if SMODS.pseudorandom_probability(card, "j_mp_lets_go_gambling", 1, card.ability.extra.odds) then
				returns = {}
				returns.x_mult = card.ability.extra.xmult
				returns.dollars = card.ability.extra.dollars
			end
			if
				content_runtime.is_pvp_boss()
				and SMODS.pseudorandom_probability(
					card,
					"j_mp_lets_go_gambling_misfire",
					1,
					card.ability.extra.nemesis_odds
				)
			then
				returns = returns or {}
				content_runtime.send_lets_go_gambling_nemesis()
				returns.message = localize("k_oops_ex")
			end
			return returns
		end
	end,
	mp_credits = {
		idea = { "Dr. Monty" },
		art = { "Carter" },
		code = { "Virtualized" },
	},
}, "j_mp_lets_go_gambling"))
