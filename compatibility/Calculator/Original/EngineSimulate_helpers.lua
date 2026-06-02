-- Shared Preview simulation helpers that do not own blind/deck integration.

if FN.SIM.run and not FN.SIM.simulate_scoring_cards then
	function FN.SIM.simulate_scoring_cards()
		for _, scoring_card in ipairs(FN.SIM.env.scoring_cards) do
			FN.SIM.simulate_card_in_context(scoring_card, G.play)
		end
	end

	function FN.SIM.simulate_held_cards()
		for _, held_card in ipairs(FN.SIM.env.held_cards) do
			FN.SIM.simulate_card_in_context(held_card, G.hand)
		end
	end

	function FN.SIM.simulate_joker_global_effects()
		for _, joker in ipairs(FN.SIM.env.jokers) do
			if joker.edition then
				if joker.edition.chips then FN.SIM.add_chips(joker.edition.chips) end
				if joker.edition.mult then FN.SIM.add_mult(joker.edition.mult) end
			end

			FN.SIM.simulate_joker(joker, FN.SIM.get_context(G.jokers, { global = true }))
			FN.SIM.simulate_all_jokers(G.jokers, { other_joker = joker })

			if joker.edition and joker.edition.x_mult then
				FN.SIM.x_mult(joker.edition.x_mult)
			end
			FN.SIM.apply_talisman_score_fields(joker.edition)
		end
	end

	function FN.SIM.simulate_consumable_effects()
		for _, consumable in ipairs(FN.SIM.env.consumables) do
			if consumable.ability.set == "Planet" and not consumable.debuff then
				if
					G.GAME.used_vouchers.v_observatory
					and consumable.ability.consumeable.hand_type == FN.SIM.env.scoring_name
				then
					FN.SIM.x_mult(G.P_CENTERS.v_observatory.config.extra)
				end
			end
		end
	end

	function FN.SIM.add_base_chips_and_mult()
		local played_hand_data = FN.SIM.get_hand_state(FN.SIM.env.scoring_name)
		if not played_hand_data then return end
		FN.SIM.add_chips(played_hand_data.chips)
		FN.SIM.add_mult(played_hand_data.mult)
	end

	function FN.SIM.simulate_joker_before_effects()
		for _, joker in ipairs(FN.SIM.env.jokers) do
			FN.SIM.simulate_joker(joker, FN.SIM.get_context(G.jokers, { before = true }))
		end
	end

	function FN.SIM.simulate_scoring_pipeline()
		FN.SIM.simulate_joker_before_effects()
		FN.SIM.add_base_chips_and_mult()
		FN.SIM.simulate_blind_effects()
		FN.SIM.simulate_scoring_cards()
		FN.SIM.simulate_held_cards()
		FN.SIM.simulate_joker_global_effects()
		FN.SIM.simulate_consumable_effects()
		FN.SIM.simulate_deck_effects()
	end

	function FN.SIM.simulate_joker_discard_effects(cards, card)
		for _, joker in ipairs(FN.SIM.env.jokers) do
			FN.SIM.simulate_joker(
				joker,
				FN.SIM.get_context(G.hand, { discard = true, cards = cards, other_card = card })
			)
		end
	end

	function FN.SIM.simulate_card_in_context(card, cardarea)
		FN.SIM.running.reps = 1
		if card.seal == "Red" then FN.SIM.add_reps(1) end
		if FN.SIM.is_deck("b_mp_echodeck") then FN.SIM.add_reps(1) end
		FN.SIM.simulate_all_jokers(cardarea, { other_card = card, repetition = true })

		for _ = 1, FN.SIM.running.reps do
			FN.SIM.simulate_card(card, FN.SIM.get_context(cardarea, {}))
			FN.SIM.simulate_all_jokers(cardarea, { other_card = card, individual = true })
		end
	end

	function FN.SIM.simulate_card(card_data, context)
		if card_data.debuff then return end

		if context.cardarea == G.play then
			if card_data.ability.effect == "Stone Card" then
				FN.SIM.add_chips(card_data.ability.bonus + (card_data.ability.perma_bonus or 0))
			else
				FN.SIM.add_chips(card_data.base_chips + card_data.ability.bonus + (card_data.ability.perma_bonus or 0))
			end

			if card_data.ability.effect == "Lucky Card" then
				local exact_mult, min_mult, max_mult =
					FN.SIM.get_probabilistic_extremes(pseudorandom("nope"), 5, card_data.ability.mult, 0)
				FN.SIM.add_mult(exact_mult, min_mult, max_mult)
				if exact_mult > 0 then card_data.lucky_trigger.exact = true end
				if min_mult > 0 then card_data.lucky_trigger.min = true end
				if max_mult > 0 then card_data.lucky_trigger.max = true end
			else
				FN.SIM.add_mult(card_data.ability.mult)
			end

			if card_data.ability.x_mult > 1 then FN.SIM.x_mult(card_data.ability.x_mult) end
			FN.SIM.apply_talisman_score_fields(card_data.ability)

			if card_data.seal == "Gold" then FN.SIM.add_dollars(3) end
			if card_data.ability.p_dollars > 0 then
				if card_data.ability.effect == "Lucky Card" then
					local exact_dollars, min_dollars, max_dollars = FN.SIM.get_probabilistic_extremes(
						pseudorandom("notthistime"),
						15,
						card_data.ability.p_dollars,
						0
					)
					FN.SIM.add_dollars(exact_dollars, min_dollars, max_dollars)
					if exact_dollars > 0 then card_data.lucky_trigger.exact = true end
					if min_dollars > 0 then card_data.lucky_trigger.min = true end
					if max_dollars > 0 then card_data.lucky_trigger.max = true end
				else
					FN.SIM.add_dollars(card_data.ability.p_dollars)
				end
			end

			if card_data.edition then
				if card_data.edition.chips then FN.SIM.add_chips(card_data.edition.chips) end
				if card_data.edition.mult then FN.SIM.add_mult(card_data.edition.mult) end
				if card_data.edition.x_mult then FN.SIM.x_mult(card_data.edition.x_mult) end
				FN.SIM.apply_talisman_score_fields(card_data.edition)
			end
		elseif context.cardarea == G.hand then
			if card_data.ability.h_mult > 0 then FN.SIM.add_mult(card_data.ability.h_mult) end
			if card_data.ability.h_x_mult > 0 then FN.SIM.x_mult(card_data.ability.h_x_mult) end
		end
	end

	function FN.SIM.simulate_all_jokers(cardarea, context_args)
		for _, joker in ipairs(FN.SIM.env.jokers) do
			FN.SIM.simulate_joker(joker, FN.SIM.get_context(cardarea, context_args))
		end
	end

	function FN.SIM.simulate_joker(joker_obj, context)
		if joker_obj.debuff then return end

		local joker_simulation_function = FN.SIM.JOKERS["simulate_" .. joker_obj.id]
		if joker_simulation_function then joker_simulation_function(joker_obj, context) end
	end
end
