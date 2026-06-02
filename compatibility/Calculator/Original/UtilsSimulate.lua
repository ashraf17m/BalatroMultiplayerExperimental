-- Utilities for writing simulation functions for jokers.
--
-- In general, these functions replicate the game's internal calculations and
-- variables in order to avoid affecting the game's state during simulation.
-- These functions ensure that the score calculation remains identical to the
-- game; DO NOT directly modify the `FN.SIM.running` score variables.

--
-- HIGH-LEVEL:
--

function FN.SIM.JOKERS.add_suit_mult(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_suit(context.other_card, joker_obj.ability.extra.suit) and not context.other_card.debuff then
			FN.SIM.add_mult(joker_obj.ability.extra.s_mult)
		end
	end
end

function FN.SIM.JOKERS.add_type_mult(joker_obj, context)
	if context.cardarea == G.jokers and context.global and next(context.poker_hands[joker_obj.ability.type]) then
		FN.SIM.add_mult(joker_obj.ability.t_mult)
	end
end

function FN.SIM.JOKERS.add_type_chips(joker_obj, context)
	if context.cardarea == G.jokers and context.global and next(context.poker_hands[joker_obj.ability.type]) then
		FN.SIM.add_chips(joker_obj.ability.t_chips)
	end
end

function FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		if
			joker_obj.ability.x_mult > 1
			and (joker_obj.ability.type == "" or next(context.poker_hands[joker_obj.ability.type]))
		then
			FN.SIM.x_mult(joker_obj.ability.x_mult)
		end
	end
end

function FN.SIM.JOKERS.x_mult_if_suit_probability(joker_obj, context, suit, seed)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_suit(context.other_card, suit) and not context.other_card.debuff then
			local exact_xmult, min_xmult, max_xmult = FN.SIM.get_probabilistic_extremes(
				pseudorandom(seed),
				joker_obj.ability.extra.odds,
				joker_obj.ability.extra.Xmult,
				1
			)
			FN.SIM.x_mult(exact_xmult, min_xmult, max_xmult)
		end
	end
end

function FN.SIM.get_probabilistic_extremes(random_value, odds, reward, default)
	-- Exact mirrors the game's probability calculation
	local exact = default
	if random_value < G.GAME.probabilities.normal / odds then exact = reward end

	-- Minimum is default unless probability is guaranteed (eg. 2 in 2 chance)
	local min = default
	if G.GAME.probabilities.normal >= odds then min = reward end

	-- Maximum is always reward (probability is always > 0); redundant variable is for readability
	local max = reward

	return exact, min, max
end

function FN.SIM.adjust_field_with_range(adj_func, field, mod_func, exact_value, min_value, max_value)
	if not exact_value then error("Cannot adjust field, exact_value is missing.") end

	if not min_value or not max_value then
		min_value = exact_value
		max_value = exact_value
	end

	FN.SIM.running.min[field] = mod_func(adj_func(FN.SIM.running.min[field], min_value))
	FN.SIM.running.exact[field] = mod_func(adj_func(FN.SIM.running.exact[field], exact_value))
	FN.SIM.running.max[field] = mod_func(adj_func(FN.SIM.running.max[field], max_value))
end

function FN.SIM.add_chips(exact, min, max)
	FN.SIM.adjust_field_with_range(function(x, y)
		return FN.SIM.add_values(x, y)
	end, "chips", FN.SIM.mod_chips, exact, min, max)
end

function FN.SIM.add_mult(exact, min, max)
	FN.SIM.adjust_field_with_range(function(x, y)
		return FN.SIM.add_values(x, y)
	end, "mult", FN.SIM.mod_mult, exact, min, max)
end

function FN.SIM.x_mult(exact, min, max)
	FN.SIM.adjust_field_with_range(function(x, y)
		return FN.SIM.mul_values(x, y)
	end, "mult", FN.SIM.mod_mult, exact, min, max)
end

function FN.SIM.add_dollars(exact, min, max)
	-- NOTE: no mod_func for dollars, so have to declare an identity function
	FN.SIM.adjust_field_with_range(
		function(x, y)
			return x + y
		end,
		"dollars",
		function(x)
			return x
		end,
		exact,
		min,
		max
	)
end

function FN.SIM.add_reps(n)
	FN.SIM.running.reps = FN.SIM.running.reps + n
end

function FN.SIM.JOKERS.add_reps_for_first_scoring_cards(joker_obj, context, count)
	if context.cardarea ~= G.play or not context.repetition then return end
	for index = 1, count do
		if context.other_card == context.scoring_hand[index] and not context.other_card.debuff then
			FN.SIM.add_reps(joker_obj.ability.extra)
		end
	end
end

--
-- LOW-LEVEL:
--

function FN.SIM.to_score_number(value)
	if type(to_big) == "function" and (type(value) == "number" or type(value) == "table") then
		local ok, converted = pcall(to_big, value)
		if ok then return converted end
	end
	return value or 0
end

function FN.SIM.zero()
	return FN.SIM.to_score_number(0)
end

function FN.SIM.one()
	return FN.SIM.to_score_number(1)
end

function FN.SIM.add_values(a, b)
	return FN.SIM.to_score_number(a) + FN.SIM.to_score_number(b)
end

function FN.SIM.sub_values(a, b)
	return FN.SIM.to_score_number(a) - FN.SIM.to_score_number(b)
end

function FN.SIM.mul_values(a, b)
	return FN.SIM.to_score_number(a) * FN.SIM.to_score_number(b)
end

function FN.SIM.div_values(a, b)
	return FN.SIM.to_score_number(a) / FN.SIM.to_score_number(b)
end

function FN.SIM.pow_values(a, b)
	return FN.SIM.to_score_number(a) ^ FN.SIM.to_score_number(b)
end

function FN.SIM.arrow_values(base, arrows, value)
	base = FN.SIM.to_score_number(base)
	if type(base) == "table" and type(base.arrow) == "function" then
		return base:arrow(arrows, value)
	end
	if arrows == 1 then return FN.SIM.pow_values(base, value) end
	return base
end

function FN.SIM.floor_value(value)
	return math.floor(FN.SIM.to_score_number(value))
end

function FN.SIM.min_value(a, b)
	return math.min(FN.SIM.to_score_number(a), FN.SIM.to_score_number(b))
end

function FN.SIM.max_value(a, b)
	return math.max(FN.SIM.to_score_number(a), FN.SIM.to_score_number(b))
end

function FN.SIM.is_gt(a, b)
	return FN.SIM.to_score_number(a) > FN.SIM.to_score_number(b)
end

function FN.SIM.is_lt(a, b)
	return FN.SIM.to_score_number(a) < FN.SIM.to_score_number(b)
end

function FN.SIM.copy_score_value(value)
	if type(value) == "number" or type(value) == "table" then return FN.SIM.to_score_number(value) end
	return value
end

function FN.SIM.copy_hand_data(hand_data)
	if not hand_data then return nil end
	local copy = {}
	for key, value in pairs(hand_data) do
		if
			key == "chips"
			or key == "mult"
			or key == "s_chips"
			or key == "s_mult"
			or key == "l_chips"
			or key == "l_mult"
			or key == "level"
		then
			copy[key] = FN.SIM.copy_score_value(value)
		else
			copy[key] = value
		end
	end
	return copy
end

function FN.SIM.build_hand_state()
	local hand_state = {}
	for hand_name, hand_data in pairs(G.GAME.hands or {}) do
		hand_state[hand_name] = FN.SIM.copy_hand_data(hand_data)
	end
	return hand_state
end

function FN.SIM.get_hand_state(hand_name)
	return FN.SIM.env.hand_state[hand_name] or (G.GAME.hands and G.GAME.hands[hand_name])
end

function FN.SIM.iter_hand_state()
	return pairs(FN.SIM.env.hand_state or {})
end

function FN.SIM.recalculate_hand_base(hand_data)
	if not hand_data then return end
	local level_minus_one = FN.SIM.sub_values(hand_data.level or 1, 1)
	hand_data.mult = FN.SIM.max_value(1, FN.SIM.add_values(hand_data.s_mult or 0, FN.SIM.mul_values(level_minus_one, hand_data.l_mult or 0)))
	hand_data.chips = FN.SIM.max_value(0, FN.SIM.add_values(hand_data.s_chips or 0, FN.SIM.mul_values(level_minus_one, hand_data.l_chips or 0)))
end

function FN.SIM.reset_running()
	FN.SIM.running = {
		min = { chips = FN.SIM.zero(), mult = FN.SIM.zero(), dollars = 0 },
		exact = { chips = FN.SIM.zero(), mult = FN.SIM.zero(), dollars = 0 },
		max = { chips = FN.SIM.zero(), mult = FN.SIM.zero(), dollars = 0 },
		reps = 0,
	}
end

function FN.SIM.is_suit(card_data, suit, ignore_scorability)
	if card_data.debuff and not ignore_scorability then return end
	if card_data.ability.effect == "Stone Card" then return false end
	if card_data.ability.effect == "Wild Card" and not card_data.debuff then return true end
	if next(find_joker("Smeared Joker")) then
		local is_card_suit_light = (card_data.suit == "Hearts" or card_data.suit == "Diamonds")
		local is_check_suit_light = (suit == "Hearts" or suit == "Diamonds")
		if is_card_suit_light == is_check_suit_light then return true end
	end
	return card_data.suit == suit
end

function FN.SIM.get_rank(card_data)
	if card_data.ability.effect == "Stone Card" and not card_data.vampired then
		FN.SIM.misc.next_stone_id = FN.SIM.misc.next_stone_id - 1
		return FN.SIM.misc.next_stone_id
	end
	return card_data.rank
end

function FN.SIM.is_rank(card_data, ranks)
	if card_data.ability.effect == "Stone Card" then return false end

	if type(ranks) == "number" then ranks = { ranks } end
	if FN.SIM.is_deck("b_mp_gradient") then
		local temp = {}

		for i, v in ipairs(ranks) do
			temp[v - 1] = true
			temp[v] = true
			temp[v + 1] = true
		end

		ranks = {}
		for k, v in pairs(temp) do
			if k == 15 then
				k = 2
			elseif k == 1 then
				k = 14
			end
			table.insert(ranks, k)
		end
		table.sort(ranks)
	end
	for _, r in ipairs(ranks) do
		if card_data.rank == r then return true end
	end
	return false
end

function FN.SIM.check_rank_parity(card_data, check_even)
	if check_even then
		return FN.SIM.is_rank(card_data, { 2, 4, 6, 8, 10 })
	else
		return FN.SIM.is_rank(card_data, { 3, 5, 7, 9, 14 })
	end
end

function FN.SIM.is_face(card_data)
	return (FN.SIM.is_rank(card_data, { 11, 12, 13 }) or next(find_joker("Pareidolia")))
end

function FN.SIM.set_ability(card_data, center)
	-- See Card:set_ability()
	card_data.ability = {
		name = center.name,
		effect = center.effect,
		set = center.set,
		mult = center.config.mult or 0,
		h_mult = center.config.h_mult or 0,
		h_x_mult = center.config.h_x_mult or 0,
		h_dollars = center.config.h_dollars or 0,
		p_dollars = center.config.p_dollars or 0,
		t_mult = center.config.t_mult or 0,
		t_chips = center.config.t_chips or 0,
		x_mult = center.config.Xmult or 1,
		h_size = center.config.h_size or 0,
		d_size = center.config.d_size or 0,
		extra = copy_table(center.config.extra) or nil,
		extra_value = 0,
		type = center.config.type or "",
		order = center.order or nil,
		forced_selection = card_data.ability and card_data.ability.forced_selection or nil,
		perma_bonus = card_data.ability and card_data.ability.perma_bonus or 0,
		bonus = center.config.bonus or 0,
	}
end

function FN.SIM.set_edition(card_data, edition)
	card_data.edition = nil
	if not edition then return end

	if edition.holo then
		if not card_data.edition then card_data.edition = {} end
		card_data.edition.mult = G.P_CENTERS.e_holo.config.extra
		card_data.edition.holo = true
		card_data.edition.type = "holo"
	elseif edition.foil then
		if not card_data.edition then card_data.edition = {} end
		card_data.edition.chips = G.P_CENTERS.e_foil.config.extra
		card_data.edition.foil = true
		card_data.edition.type = "foil"
	elseif edition.polychrome then
		if not card_data.edition then card_data.edition = {} end
		card_data.edition.x_mult = G.P_CENTERS.e_polychrome.config.extra
		card_data.edition.polychrome = true
		card_data.edition.type = "polychrome"
	elseif edition.negative then
		if not card_data.edition then card_data.edition = {} end
		card_data.edition.negative = true
		card_data.edition.type = "negative"
	end
end

function FN.SIM.is_deck(deck)
	if G.GAME.selected_back.effect.center.key == deck then
		return true
	elseif G.GAME.selected_back.effect.center.key == "b_mp_cocktail" then
		for i = 1, 3 do
			if G.GAME.modifiers.mp_cocktail[i] == deck then return true end
		end
	end
	return false
end

function FN.SIM.mod_chips(_chips)
	return FN.SIM.to_score_number(_chips)
end

function FN.SIM.mod_mult(_mult)
	return FN.SIM.to_score_number(_mult)
end

function FN.SIM.x_chips(exact, min, max)
	FN.SIM.adjust_field_with_range(function(x, y)
		return FN.SIM.mul_values(x, y)
	end, "chips", FN.SIM.mod_chips, exact, min, max)
end

function FN.SIM.e_chips(exact, min, max)
	FN.SIM.adjust_field_with_range(function(x, y)
		return FN.SIM.pow_values(x, y)
	end, "chips", FN.SIM.mod_chips, exact, min, max)
end

function FN.SIM.ee_chips(exact, min, max)
	FN.SIM.adjust_field_with_range(function(x, y)
		return FN.SIM.arrow_values(x, 2, y)
	end, "chips", FN.SIM.mod_chips, exact, min, max)
end

function FN.SIM.eee_chips(exact, min, max)
	FN.SIM.adjust_field_with_range(function(x, y)
		return FN.SIM.arrow_values(x, 3, y)
	end, "chips", FN.SIM.mod_chips, exact, min, max)
end

function FN.SIM.hyper_chips(value)
	if type(value) ~= "table" then return end
	FN.SIM.adjust_field_with_range(function(x, y)
		return FN.SIM.arrow_values(x, y[1], y[2])
	end, "chips", FN.SIM.mod_chips, value)
end

function FN.SIM.e_mult(exact, min, max)
	FN.SIM.adjust_field_with_range(function(x, y)
		return FN.SIM.pow_values(x, y)
	end, "mult", FN.SIM.mod_mult, exact, min, max)
end

function FN.SIM.ee_mult(exact, min, max)
	FN.SIM.adjust_field_with_range(function(x, y)
		return FN.SIM.arrow_values(x, 2, y)
	end, "mult", FN.SIM.mod_mult, exact, min, max)
end

function FN.SIM.eee_mult(exact, min, max)
	FN.SIM.adjust_field_with_range(function(x, y)
		return FN.SIM.arrow_values(x, 3, y)
	end, "mult", FN.SIM.mod_mult, exact, min, max)
end

function FN.SIM.hyper_mult(value)
	if type(value) ~= "table" then return end
	FN.SIM.adjust_field_with_range(function(x, y)
		return FN.SIM.arrow_values(x, y[1], y[2])
	end, "mult", FN.SIM.mod_mult, value)
end

function FN.SIM.apply_talisman_score_fields(source)
	if not source then return end
	if source.x_chips and FN.SIM.is_gt(source.x_chips, 0) then FN.SIM.x_chips(source.x_chips) end
	if source.e_chips and FN.SIM.is_gt(source.e_chips, 0) then FN.SIM.e_chips(source.e_chips) end
	if source.ee_chips and FN.SIM.is_gt(source.ee_chips, 0) then FN.SIM.ee_chips(source.ee_chips) end
	if source.eee_chips and FN.SIM.is_gt(source.eee_chips, 0) then FN.SIM.eee_chips(source.eee_chips) end
	if source.hyper_chips and type(source.hyper_chips) == "table" and FN.SIM.is_gt(source.hyper_chips[1] or 0, 0) then
		FN.SIM.hyper_chips(source.hyper_chips)
	end
	if source.e_mult and FN.SIM.is_gt(source.e_mult, 0) then FN.SIM.e_mult(source.e_mult) end
	if source.ee_mult and FN.SIM.is_gt(source.ee_mult, 0) then FN.SIM.ee_mult(source.ee_mult) end
	if source.eee_mult and FN.SIM.is_gt(source.eee_mult, 0) then FN.SIM.eee_mult(source.eee_mult) end
	if source.hyper_mult and type(source.hyper_mult) == "table" and FN.SIM.is_gt(source.hyper_mult[1] or 0, 0) then
		FN.SIM.hyper_mult(source.hyper_mult)
	end
end
