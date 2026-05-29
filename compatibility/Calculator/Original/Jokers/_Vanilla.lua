-- Divvy's Simulation for Balatro - _Vanilla.lua
--
-- Foundation adapters for the vanilla Balatro jokers. Later vanilla groups are
-- loaded by the original calculator Lovely manifest from the sibling `_Vanilla_*.lua` files.

local FNSJ = FN.SIM.JOKERS

FNSJ.simulate_joker = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then FN.SIM.add_mult(joker_obj.ability.mult) end
end
FNSJ.simulate_greedy_joker = function(joker_obj, context)
	FN.SIM.JOKERS.add_suit_mult(joker_obj, context)
end
FNSJ.simulate_lusty_joker = function(joker_obj, context)
	FN.SIM.JOKERS.add_suit_mult(joker_obj, context)
end
FNSJ.simulate_wrathful_joker = function(joker_obj, context)
	FN.SIM.JOKERS.add_suit_mult(joker_obj, context)
end
FNSJ.simulate_gluttenous_joker = function(joker_obj, context)
	FN.SIM.JOKERS.add_suit_mult(joker_obj, context)
end
FNSJ.simulate_jolly = function(joker_obj, context)
	FN.SIM.JOKERS.add_type_mult(joker_obj, context)
end
FNSJ.simulate_zany = function(joker_obj, context)
	FN.SIM.JOKERS.add_type_mult(joker_obj, context)
end
FNSJ.simulate_mad = function(joker_obj, context)
	FN.SIM.JOKERS.add_type_mult(joker_obj, context)
end
FNSJ.simulate_crazy = function(joker_obj, context)
	FN.SIM.JOKERS.add_type_mult(joker_obj, context)
end
FNSJ.simulate_droll = function(joker_obj, context)
	FN.SIM.JOKERS.add_type_mult(joker_obj, context)
end
FNSJ.simulate_sly = function(joker_obj, context)
	FN.SIM.JOKERS.add_type_chips(joker_obj, context)
end
FNSJ.simulate_wily = function(joker_obj, context)
	FN.SIM.JOKERS.add_type_chips(joker_obj, context)
end
FNSJ.simulate_clever = function(joker_obj, context)
	FN.SIM.JOKERS.add_type_chips(joker_obj, context)
end
FNSJ.simulate_devious = function(joker_obj, context)
	FN.SIM.JOKERS.add_type_chips(joker_obj, context)
end
FNSJ.simulate_crafty = function(joker_obj, context)
	FN.SIM.JOKERS.add_type_chips(joker_obj, context)
end
FNSJ.simulate_half = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		if #context.full_hand <= joker_obj.ability.extra.size then FN.SIM.add_mult(joker_obj.ability.extra.mult) end
	end
end
FNSJ.simulate_stencil = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		local xmult = G.jokers.config.card_limit - #FN.SIM.env.jokers
		for _, joker in ipairs(FN.SIM.env.jokers) do
			if joker.ability.name == "Joker Stencil" then xmult = xmult + 1 end
		end
		if joker_obj.ability.x_mult > 1 then FN.SIM.x_mult(joker_obj.ability.x_mult) end
	end
end
FNSJ.simulate_four_fingers = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_mime = function(joker_obj, context)
	if context.cardarea == G.hand and context.repetition then FN.SIM.add_reps(joker_obj.ability.extra) end
end
FNSJ.simulate_credit_card = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_ceremonial = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then FN.SIM.add_mult(joker_obj.ability.mult) end
end
FNSJ.simulate_banner = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		if G.GAME.current_round.discards_left > 0 then
			local chips = G.GAME.current_round.discards_left * joker_obj.ability.extra
			FN.SIM.add_chips(chips)
		end
	end
end
FNSJ.simulate_mystic_summit = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		if G.GAME.current_round.discards_left == joker_obj.ability.extra.d_remaining then
			FN.SIM.add_mult(joker_obj.ability.extra.mult)
		end
	end
end
FNSJ.simulate_marble = function(joker_obj, context)
	-- Effect not relevant (Blind)
end
FNSJ.simulate_loyalty_card = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		local loyalty_diff = G.GAME.hands_played - joker_obj.ability.hands_played_at_create
		local loyalty_remaining = ((joker_obj.ability.extra.every - 1) - loyalty_diff)
			% (joker_obj.ability.extra.every + 1)
		if loyalty_remaining == joker_obj.ability.extra.every then FN.SIM.x_mult(joker_obj.ability.extra.Xmult) end
	end
end
FNSJ.simulate_8_ball = function(joker_obj, context)
	-- Effect might be relevant?
end
FNSJ.simulate_misprint = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		local exact_mult = pseudorandom("nope", joker_obj.ability.extra.min, joker_obj.ability.extra.max)
		FN.SIM.add_mult(exact_mult, joker_obj.ability.extra.min, joker_obj.ability.extra.max)
	end
end
FNSJ.simulate_dusk = function(joker_obj, context)
	if context.cardarea == G.play and context.repetition then
		if G.GAME.current_round.hands_left == 1 then FN.SIM.add_reps(joker_obj.ability.extra) end
	end
end
FNSJ.simulate_raised_fist = function(joker_obj, context)
	if context.cardarea == G.hand and context.individual then
		local cur_mult, cur_rank = 15, 15
		local raised_card = nil
		for _, card in ipairs(FN.SIM.env.held_cards) do
			if cur_rank >= card.rank and card.ability.effect ~= "Stone Card" then
				cur_mult = card.base_chips
				cur_rank = card.rank
				raised_card = card
			end
		end
		if raised_card == context.other_card and not context.other_card.debuff then FN.SIM.add_mult(2 * cur_mult) end
	end
end
FNSJ.simulate_chaos = function(joker_obj, context)
	-- Effect not relevant (Free Reroll)
end
FNSJ.simulate_fibonacci = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_rank(context.other_card, { 2, 3, 5, 8, 14 }) and not context.other_card.debuff then
			FN.SIM.add_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_steel_joker = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		FN.SIM.x_mult(1 + joker_obj.ability.extra * joker_obj.ability.steel_tally)
	end
end
FNSJ.simulate_scary_face = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_face(context.other_card) and not context.other_card.debuff then
			FN.SIM.add_chips(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_abstract = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		FN.SIM.add_mult(#FN.SIM.env.jokers * joker_obj.ability.extra)
	end
end
FNSJ.simulate_delayed_grat = function(joker_obj, context)
	-- Effect not relevant (End of Round)
end
FNSJ.simulate_hack = function(joker_obj, context)
	if context.cardarea == G.play and context.repetition then
		if not context.other_card.debuff and FN.SIM.is_rank(context.other_card, { 2, 3, 4, 5 }) then
			FN.SIM.add_reps(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_pareidolia = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_gros_michel = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then FN.SIM.add_mult(joker_obj.ability.extra.mult) end
end
FNSJ.simulate_even_steven = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if not context.other_card.debuff and FN.SIM.check_rank_parity(context.other_card, true) then
			FN.SIM.add_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_odd_todd = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if not context.other_card.debuff and FN.SIM.check_rank_parity(context.other_card, false) then
			FN.SIM.add_chips(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_scholar = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_rank(context.other_card, 14) and not context.other_card.debuff then
			FN.SIM.add_chips(joker_obj.ability.extra.chips)
			FN.SIM.add_mult(joker_obj.ability.extra.mult)
		end
	end
end
FNSJ.simulate_business = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_face(context.other_card) and not context.other_card.debuff then
			local exact_dollars, min_dollars, max_dollars =
				FN.SIM.get_probabilistic_extremes(pseudorandom("false"), joker_obj.ability.extra, 2, 0)
			FN.SIM.add_dollars(exact_dollars, min_dollars, max_dollars)
		end
	end
end
FNSJ.simulate_supernova = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		local hand_data = FN.SIM.get_hand_state(context.scoring_name)
		if hand_data then FN.SIM.add_mult(hand_data.played) end
	end
end
FNSJ.simulate_ride_the_bus = function(joker_obj, context)
	if context.cardarea == G.jokers and context.before and not context.blueprint then
		local faces = false
		for _, scoring_card in ipairs(context.scoring_hand) do
			if FN.SIM.is_face(scoring_card) then faces = true end
		end
		if faces then
			joker_obj.ability.mult = 0
		else
			joker_obj.ability.mult = joker_obj.ability.mult + joker_obj.ability.extra
		end
	end
	if context.cardarea == G.jokers and context.global then FN.SIM.add_mult(joker_obj.ability.mult) end
end
FNSJ.simulate_space = function(joker_obj, context)
	if context.cardarea == G.jokers and context.before then
		local hand_data = FN.SIM.get_hand_state(FN.SIM.env.scoring_name)
		if not hand_data then return end

		local rand = pseudorandom("bad")
		local exact_chips, min_chips, max_chips =
			FN.SIM.get_probabilistic_extremes(rand, joker_obj.ability.extra, hand_data.l_chips, 0)
		local exact_mult, min_mult, max_mult =
			FN.SIM.get_probabilistic_extremes(rand, joker_obj.ability.extra, hand_data.l_mult, 0)

		FN.SIM.add_chips(exact_chips, min_chips, max_chips)
		FN.SIM.add_mult(exact_mult, min_mult, max_mult)
	end
end
