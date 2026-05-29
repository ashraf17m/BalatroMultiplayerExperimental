-- Divvy's Simulation for Balatro - _Vanilla_progression.lua
--
-- Progression, scaling, and economy-oriented vanilla joker simulation adapters.

local FNSJ = FN.SIM.JOKERS

FNSJ.simulate_egg = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_burglar = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_blackboard = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		local black_suits, all_cards = 0, 0
		for _, card in ipairs(FN.SIM.env.held_cards) do
			all_cards = all_cards + 1
			if FN.SIM.is_suit(card, "Clubs", true) or FN.SIM.is_suit(card, "Spades", true) then
				black_suits = black_suits + 1
			end
		end
		if black_suits == all_cards then FN.SIM.x_mult(joker_obj.ability.extra) end
	end
end
FNSJ.simulate_runner = function(joker_obj, context)
	if context.cardarea == G.jokers and context.before and not context.blueprint then
		if next(context.poker_hands["Straight"]) then
			joker_obj.ability.extra.chips = joker_obj.ability.extra.chips + joker_obj.ability.extra.chip_mod
		end
	end
	if context.cardarea == G.jokers and context.global then FN.SIM.add_chips(joker_obj.ability.extra.chips) end
end
FNSJ.simulate_ice_cream = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then FN.SIM.add_chips(joker_obj.ability.extra.chips) end
end
FNSJ.simulate_dna = function(joker_obj, context)
	if context.cardarea == G.jokers and context.before then
		if G.GAME.current_round.hands_played == 0 and #context.full_hand == 1 then
			local new_card = copy_table(context.full_hand[1])
			table.insert(FN.SIM.env.held_cards, new_card)
		end
	end
end
FNSJ.simulate_splash = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_blue_joker = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		FN.SIM.add_chips(joker_obj.ability.extra * #G.deck.cards)
	end
end
FNSJ.simulate_sixth_sense = function(joker_obj, context)
	-- Effect might be relevant?
end
FNSJ.simulate_constellation = function(joker_obj, context)
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_hiker = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if not context.other_card.debuff then
			context.other_card.ability.perma_bonus = (context.other_card.ability.perma_bonus or 0)
				+ joker_obj.ability.extra
		end
	end
end
FNSJ.simulate_faceless = function(joker_obj, context)
	-- Effect not relevant (Discard)
end
FNSJ.simulate_green_joker = function(joker_obj, context)
	if context.cardarea == G.jokers and context.before and not context.blueprint then
		joker_obj.ability.mult = joker_obj.ability.mult + joker_obj.ability.extra.hand_add
	end
	if
		context.cardarea == G.hand
		and context.discard
		and context.other_card == context.cards[1]
		and not context.blueprint
	then
		joker_obj.ability.mult = math.max(0, joker_obj.ability.mult - joker_obj.ability.extra.discard_sub)
	end
	if context.cardarea == G.jokers and context.global then FN.SIM.add_mult(joker_obj.ability.mult) end
end
FNSJ.simulate_superposition = function(joker_obj, context)
	-- Effect might be relevant?
end
FNSJ.simulate_todo_list = function(joker_obj, context)
	if context.cardarea == G.jokers and context.before then
		if context.scoring_name == joker_obj.ability.to_do_poker_hand then
			FN.SIM.add_dollars(joker_obj.ability.extra.dollars)
		end
	end
end
FNSJ.simulate_cavendish = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then FN.SIM.x_mult(joker_obj.ability.extra.Xmult) end
end
FNSJ.simulate_card_sharp = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		local hand_data = FN.SIM.get_hand_state(context.scoring_name)
		if hand_data and hand_data.played_this_round > 1 then
			FN.SIM.x_mult(joker_obj.ability.extra.Xmult)
		end
	end
end
FNSJ.simulate_red_card = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then FN.SIM.add_mult(joker_obj.ability.mult) end
end
FNSJ.simulate_madness = function(joker_obj, context)
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_square = function(joker_obj, context)
	if context.cardarea == G.jokers and context.before and not context.blueprint then
		if #context.full_hand == 4 then
			joker_obj.ability.extra.chips = joker_obj.ability.extra.chips + joker_obj.ability.extra.chip_mod
		end
	end
	if context.cardarea == G.jokers and context.global then FN.SIM.add_chips(joker_obj.ability.extra.chips) end
end
FNSJ.simulate_seance = function(joker_obj, context)
	-- Effect might be relevant? (Consumable)
end
FNSJ.simulate_riff_raff = function(joker_obj, context)
	-- Effect not relevant (Blind)
end
FNSJ.simulate_vampire = function(joker_obj, context)
	if context.cardarea == G.jokers and context.before and not context.blueprint then
		local num_enhanced = 0
		for _, card in ipairs(context.scoring_hand) do
			if card.ability.name ~= "Default Base" and not card.debuff then
				num_enhanced = num_enhanced + 1
				FN.SIM.set_ability(card, G.P_CENTERS.c_base)
			end
		end
		if num_enhanced > 0 then
			joker_obj.ability.x_mult = joker_obj.ability.x_mult + (joker_obj.ability.extra * num_enhanced)
		end
	end

	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_shortcut = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_hologram = function(joker_obj, context)
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_vagabond = function(joker_obj, context)
	-- Effect might be relevant? (Consumable)
end
FNSJ.simulate_baron = function(joker_obj, context)
	if context.cardarea == G.hand and context.individual then
		if FN.SIM.is_rank(context.other_card, 13) and not context.other_card.debuff then
			FN.SIM.x_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_cloud_9 = function(joker_obj, context)
	-- Effect not relevant (End of Round)
end
FNSJ.simulate_rocket = function(joker_obj, context)
	-- Effect not relevant (End of Round)
end
FNSJ.simulate_obelisk = function(joker_obj, context)
	if context.cardarea == G.jokers and context.before and not context.blueprint then
		local reset = true
		local scoring_hand = FN.SIM.get_hand_state(context.scoring_name)
		local play_more_than = scoring_hand and (scoring_hand.played or 0) or 0
		for hand_name, hand in FN.SIM.iter_hand_state() do
			if hand_name ~= context.scoring_name and hand.played >= play_more_than and hand.visible then
				reset = false
			end
		end
		if reset then
			joker_obj.ability.x_mult = 1
		else
			joker_obj.ability.x_mult = joker_obj.ability.x_mult + joker_obj.ability.extra
		end
	end
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_midas_mask = function(joker_obj, context)
	if context.cardarea == G.jokers and context.before and not context.blueprint then
		for _, card in ipairs(context.scoring_hand) do
			if FN.SIM.is_face(card) then FN.SIM.set_ability(card, G.P_CENTERS.m_gold) end
		end
	end
end
FNSJ.simulate_luchador = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_photograph = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		local first_face = nil
		for i = 1, #context.scoring_hand do
			if FN.SIM.is_face(context.scoring_hand[i]) then
				first_face = context.scoring_hand[i]
				break
			end
		end
		if context.other_card == first_face and not context.other_card.debuff then
			FN.SIM.x_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_gift = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_turtle_bean = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_erosion = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		local diff = G.GAME.starting_deck_size - #G.playing_cards
		if diff > 0 then FN.SIM.add_mult(joker_obj.ability.extra * diff) end
	end
end
FNSJ.simulate_reserved_parking = function(joker_obj, context)
	if context.cardarea == G.hand and context.individual then
		if FN.SIM.is_face(context.other_card) and not context.other_card.debuff then
			local exact_dollars, min_dollars, max_dollars = FN.SIM.get_probabilistic_extremes(
				pseudorandom("notthistime"),
				joker_obj.ability.extra.odds,
				joker_obj.ability.extra.dollars,
				0
			)
			FN.SIM.add_dollars(exact_dollars, min_dollars, max_dollars)
		end
	end
end
FNSJ.simulate_mail = function(joker_obj, context)
	if context.cardarea == G.hand and context.discard then
		if context.other_card.id == G.GAME.current_round.mail_card.id and not context.other_card.debuff then
			FN.SIM.add_dollars(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_to_the_moon = function(joker_obj, context)
	-- Effect not relevant (End of Round)
end
FNSJ.simulate_hallucination = function(joker_obj, context)
	-- Effect not relevant (Outside of Play)
end
FNSJ.simulate_fortune_teller = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		if G.GAME.consumeable_usage_total and G.GAME.consumeable_usage_total.tarot then
			FN.SIM.add_mult(G.GAME.consumeable_usage_total.tarot)
		end
	end
end
