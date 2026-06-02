local content_runtime = MP.CONTENT.RUNTIME

SMODS.Atlas({
	key = "magnet",
	path = "j_magnet.png",
	px = 71,
	py = 95,
})

SMODS.Joker(content_runtime.with_phantom_sync_hooks({
	key = "magnet_sandbox",
	atlas = "magnet",
	rarity = 3,
	cost = 7,
	unlocked = true,
	discovered = true,
	no_collection = MP.sandbox_no_collection,
	blueprint_compat = false,
	eternal_compat = false,
	perishable_compat = true,
	config = { extra = { rounds = 2, current_rounds = 0, max_rounds = 5 } },
	loc_vars = function(self, info_queue, card)
		MP.UTILS.add_nemesis_info(info_queue)
		return {
			vars = {
				card.ability.extra.rounds,
				card.ability.extra.current_rounds,
				card.ability.extra.max_rounds,
			},
		}
	end,
	calculate = function(self, card, context)
		if
			context.end_of_round
			and not context.other_card
			and not context.blueprint
			and not context.debuffed
			and (not card.edition or card.edition.type ~= "mp_phantom")
		then
			local removed = false
			card.ability.extra.current_rounds = card.ability.extra.current_rounds + 1
			if card.ability.extra.current_rounds > card.ability.extra.max_rounds then
				removed = true
				MP.SANDBOX.destroy_joker(card)
				card_eval_status_text(card, "extra", nil, nil, nil, { message = localize("k_no_reward") })
			end
			if card.ability.extra.current_rounds == card.ability.extra.rounds then
				local eval = function(target_card)
					return not target_card.REMOVED
				end
				juice_card_until(card, eval, true)
			end
			if not removed then
				return {
					message = (card.ability.extra.current_rounds < card.ability.extra.rounds)
							and (card.ability.extra.current_rounds .. "/" .. card.ability.extra.rounds)
						or localize("k_active_ex"),
					colour = G.C.FILTER,
				}
			end
		end
		if
			context.selling_self
			and (card.ability.extra.current_rounds >= card.ability.extra.rounds)
			and not context.blueprint
		then
			content_runtime.send_magnet()
		end
	end,

	mp_credits = {
		idea = { "Zilver" },
		art = { "Ganpan140" },
		code = { "Virtualized" },
	},
	mp_include = function(self)
		return MP.SANDBOX.is_joker_allowed(self.key) and content_runtime.include_multiplayer_jokers()
	end,
}, "j_mp_magnet_sandbox"))
