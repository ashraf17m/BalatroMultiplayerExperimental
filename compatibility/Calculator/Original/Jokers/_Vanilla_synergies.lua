-- Divvy's Simulation for Balatro - _Vanilla_synergies.lua
--
-- Midgame synergy and retrigger-oriented vanilla joker simulation adapters.

local FNSJ = FN.SIM.JOKERS

FNSJ.simulate_juggler = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_drunkard = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_stone = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		FN.SIM.add_chips(joker_obj.ability.extra * joker_obj.ability.stone_tally)
	end
end
FNSJ.simulate_golden = function(joker_obj, context)
	-- Effect not relevant (End of Round)
end
FNSJ.simulate_lucky_cat = function(joker_obj, context)
	if not joker_obj.ability.x_mult_range then
		joker_obj.ability.x_mult_range = {
			min = joker_obj.ability.x_mult,
			exact = joker_obj.ability.x_mult,
			max = joker_obj.ability.x_mult,
		}
	end

	if context.cardarea == G.play and context.individual and not context.blueprint then
		local function lucky_cat(field)
			if context.other_card.lucky_trigger and context.other_card.lucky_trigger[field] then
				joker_obj.ability.x_mult_range[field] = joker_obj.ability.x_mult_range[field] + joker_obj.ability.extra
				if joker_obj.ability.x_mult_range[field] < 1 then joker_obj.ability.x_mult_range[field] = 1 end
			end
		end
		lucky_cat("min")
		lucky_cat("exact")
		lucky_cat("max")
	end

	if context.cardarea == G.jokers and context.global then
		FN.SIM.x_mult(
			joker_obj.ability.x_mult_range.exact,
			joker_obj.ability.x_mult_range.min,
			joker_obj.ability.x_mult_range.max
		)
	end
end
FNSJ.simulate_baseball = function(joker_obj, context)
	if context.cardarea == G.jokers and context.other_joker then
		if context.other_joker.rarity == 2 and context.other_joker ~= joker_obj then
			FN.SIM.x_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_bull = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		local function bull(data)
			return joker_obj.ability.extra * math.max(0, G.GAME.dollars + data.dollars)
		end
		local min_chips = bull(FN.SIM.running.min)
		local exact_chips = bull(FN.SIM.running.exact)
		local max_chips = bull(FN.SIM.running.max)
		FN.SIM.add_chips(exact_chips, min_chips, max_chips)
	end
end
FNSJ.simulate_diet_cola = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_trading = function(joker_obj, context)
	-- Effect not relevant (Discard)
end
FNSJ.simulate_flash = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then FN.SIM.add_mult(joker_obj.ability.mult) end
end
FNSJ.simulate_popcorn = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then FN.SIM.add_mult(joker_obj.ability.mult) end
end
FNSJ.simulate_trousers = function(joker_obj, context)
	if context.cardarea == G.jokers and context.before and not context.blueprint then
		if next(context.poker_hands["Two Pair"]) or next(context.poker_hands["Full House"]) then
			joker_obj.ability.mult = joker_obj.ability.mult + joker_obj.ability.extra
		end
	end
	if context.cardarea == G.jokers and context.global then FN.SIM.add_mult(joker_obj.ability.mult) end
end
FNSJ.simulate_ancient = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if
			FN.SIM.is_suit(context.other_card, G.GAME.current_round.ancient_card.suit)
			and not context.other_card.debuff
		then
			FN.SIM.x_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_ramen = function(joker_obj, context)
	if context.cardarea == G.hand and context.discard then
		joker_obj.ability.x_mult = math.max(1, joker_obj.ability.x_mult - joker_obj.ability.extra)
	end
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_walkie_talkie = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_rank(context.other_card, { 10, 4 }) and not context.other_card.debuff then
			FN.SIM.add_chips(joker_obj.ability.extra.chips)
			FN.SIM.add_mult(joker_obj.ability.extra.mult)
		end
	end
end
FNSJ.simulate_selzer = function(joker_obj, context)
	if context.cardarea == G.play and context.repetition then FN.SIM.add_reps(1) end
end
FNSJ.simulate_castle = function(joker_obj, context)
	if context.cardarea == G.hand and context.discard and not context.blueprint then
		if
			FN.SIM.is_suit(context.other_card, G.GAME.current_round.castle_card.suit) and not context.other_card.debuff
		then
			joker_obj.ability.extra.chips = joker_obj.ability.extra.chips + joker_obj.ability.extra.chip_mod
		end
	end
	if context.cardarea == G.jokers and context.global then FN.SIM.add_chips(joker_obj.ability.extra.chips) end
end
FNSJ.simulate_smiley = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_face(context.other_card) and not context.other_card.debuff then
			FN.SIM.add_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_campfire = function(joker_obj, context)
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_ticket = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if context.other_card.ability.effect == "Gold Card" and not context.other_card.debuff then
			FN.SIM.add_dollars(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_mr_bones = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_acrobat = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		if G.GAME.current_round.hands_left == 1 then FN.SIM.x_mult(joker_obj.ability.extra) end
	end
end
FNSJ.simulate_sock_and_buskin = function(joker_obj, context)
	if context.cardarea == G.play and context.repetition then
		if FN.SIM.is_face(context.other_card) and not context.other_card.debuff then
			FN.SIM.add_reps(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_swashbuckler = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then FN.SIM.add_mult(joker_obj.ability.mult) end
end
FNSJ.simulate_troubadour = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_certificate = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_smeared = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_throwback = function(joker_obj, context)
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_hanging_chad = function(joker_obj, context)
	if joker_obj.ability.extra == 1 then
		FN.SIM.JOKERS.add_reps_for_first_scoring_cards(joker_obj, context, 2)
	else
		FN.SIM.JOKERS.add_reps_for_first_scoring_cards(joker_obj, context, 1)
	end
end
FNSJ.simulate_rough_gem = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_suit(context.other_card, "Diamonds") and not context.other_card.debuff then
			FN.SIM.add_dollars(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_bloodstone = function(joker_obj, context)
	FN.SIM.JOKERS.x_mult_if_suit_probability(joker_obj, context, "Hearts", "nopeagain")
end
FNSJ.simulate_arrowhead = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_suit(context.other_card, "Spades") and not context.other_card.debuff then
			FN.SIM.add_chips(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_onyx_agate = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_suit(context.other_card, "Clubs") and not context.other_card.debuff then
			FN.SIM.add_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_glass = function(joker_obj, context)
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_ring_master = function(joker_obj, context)
	-- Effect not relevant (Note: this is actually Showman)
end
