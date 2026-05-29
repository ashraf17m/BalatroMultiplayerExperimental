-- Divvy's Simulation for Balatro - _Vanilla_advanced.lua
--
-- Advanced combo, copy, and legendary vanilla joker simulation adapters.

local FNSJ = FN.SIM.JOKERS
local SUIT_KEYS = { "Hearts", "Diamonds", "Spades", "Clubs" }
local SEEING_DOUBLE_WILD_ORDER = { "Clubs", "Hearts", "Diamonds", "Spades" }

local function build_suit_count()
	return {
		["Hearts"] = 0,
		["Diamonds"] = 0,
		["Spades"] = 0,
		["Clubs"] = 0,
	}
end

local function increment_suit_count(suit_count, suit)
	suit_count[suit] = suit_count[suit] + 1
end

local function count_regular_scoring_suits(suit_count, scoring_hand, options)
	for _, card in ipairs(scoring_hand) do
		if card.ability.effect ~= "Wild Card" then
			for _, suit in ipairs(SUIT_KEYS) do
				if
					FN.SIM.is_suit(card, suit, options.bypass_debuff)
					and (not options.unique_suits or suit_count[suit] == 0)
				then
					increment_suit_count(suit_count, suit)
					if options.first_match_per_card then break end
				end
			end
		end
	end
end

local function count_wild_scoring_suits(suit_count, scoring_hand, suit_order)
	for _, card in ipairs(scoring_hand) do
		if card.ability.effect == "Wild Card" then
			for _, suit in ipairs(suit_order) do
				if FN.SIM.is_suit(card, suit) and suit_count[suit] == 0 then
					increment_suit_count(suit_count, suit)
					break
				end
			end
		end
	end
end

local function count_scoring_suits(scoring_hand, options)
	local count_options = options or {}
	local suit_count = build_suit_count()

	count_regular_scoring_suits(suit_count, scoring_hand, count_options)
	count_wild_scoring_suits(suit_count, scoring_hand, count_options.wild_order or SUIT_KEYS)

	return suit_count
end

local function simulate_mimic_joker(joker_to_mimic, context)
	if not joker_to_mimic then
		return
	end

	context.blueprint = (context.blueprint and (context.blueprint + 1)) or 1
	if context.blueprint > #FN.SIM.env.jokers + 1 then return end
	FN.SIM.simulate_joker(joker_to_mimic, context)
end

FNSJ.simulate_flower_pot = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		local suit_count = count_scoring_suits(context.scoring_hand, {
			bypass_debuff = true,
			unique_suits = true,
			first_match_per_card = true,
		})

		if
			suit_count["Hearts"] > 0
			and suit_count["Diamonds"] > 0
			and suit_count["Spades"] > 0
			and suit_count["Clubs"] > 0
		then
			FN.SIM.x_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_blueprint = function(joker_obj, context)
	local joker_to_mimic = nil
	for idx, joker in ipairs(FN.SIM.env.jokers) do
		if joker == joker_obj then joker_to_mimic = FN.SIM.env.jokers[idx + 1] end
	end
	simulate_mimic_joker(joker_to_mimic, context)
end
FNSJ.simulate_wee = function(joker_obj, context)
	if context.cardarea == G.play and context.individual and not context.blueprint then
		if FN.SIM.is_rank(context.other_card, 2) and not context.other_card.debuff then
			joker_obj.ability.extra.chips = joker_obj.ability.extra.chips + joker_obj.ability.extra.chip_mod
		end
	end
	if context.cardarea == G.jokers and context.global then FN.SIM.add_chips(joker_obj.ability.extra.chips) end
end
FNSJ.simulate_merry_andy = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_oops = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_idol = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if
			FN.SIM.is_rank(context.other_card, G.GAME.current_round.idol_card.id)
			and FN.SIM.is_suit(context.other_card, G.GAME.current_round.idol_card.suit)
			and not context.other_card.debuff
		then
			FN.SIM.x_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_seeing_double = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		local suit_count = count_scoring_suits(context.scoring_hand, {
			wild_order = SEEING_DOUBLE_WILD_ORDER,
		})

		if
			suit_count["Clubs"] > 0
			and (suit_count["Hearts"] > 0 or suit_count["Diamonds"] > 0 or suit_count["Spades"] > 0)
		then
			FN.SIM.x_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_matador = function(joker_obj, context)
	if context.cardarea == G.jokers and context.debuffed_hand then
		if G.GAME.blind.triggered then FN.SIM.add_dollars(joker_obj.ability.extra) end
	end
end
FNSJ.simulate_hit_the_road = function(joker_obj, context)
	if context.cardarea == G.hand and context.discard and not context.blueprint then
		if FN.SIM.is_rank(context.other_card, 11) and not context.other_card.debuff then
			joker_obj.ability.x_mult = joker_obj.ability.x_mult + joker_obj.ability.extra
		end
	end
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_duo = function(joker_obj, context)
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_trio = function(joker_obj, context)
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_family = function(joker_obj, context)
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_order = function(joker_obj, context)
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_tribe = function(joker_obj, context)
	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_stuntman = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then FN.SIM.add_chips(joker_obj.ability.extra.chip_mod) end
end
FNSJ.simulate_invisible = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_brainstorm = function(joker_obj, context)
	local joker_to_mimic = FN.SIM.env.jokers[1]
	if joker_to_mimic ~= joker_obj then simulate_mimic_joker(joker_to_mimic, context) end
end
FNSJ.simulate_satellite = function(joker_obj, context)
	-- Effect not relevant (End of Round)
end
FNSJ.simulate_shoot_the_moon = function(joker_obj, context)
	if context.cardarea == G.hand and context.individual then
		if FN.SIM.is_rank(context.other_card, 12) and not context.other_card.debuff then FN.SIM.add_mult(13) end
	end
end
FNSJ.simulate_drivers_license = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		if (joker_obj.ability.driver_tally or 0) >= 16 then FN.SIM.x_mult(joker_obj.ability.extra) end
	end
end
FNSJ.simulate_cartomancer = function(joker_obj, context)
	-- Effect not relevant (Blind)
end
FNSJ.simulate_astronomer = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_burnt = function(joker_obj, context)
	-- Effect not relevant (Discard)
end
FNSJ.simulate_bootstraps = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		local function bootstraps(data)
			return joker_obj.ability.extra.mult
				* math.floor((G.GAME.dollars + data.dollars) / joker_obj.ability.extra.dollars)
		end
		local min_mult = bootstraps(FN.SIM.running.min)
		local exact_mult = bootstraps(FN.SIM.running.exact)
		local max_mult = bootstraps(FN.SIM.running.max)
		FN.SIM.add_mult(exact_mult, min_mult, max_mult)
	end
end
FNSJ.simulate_caino = function(joker_obj, context)
	if context.cardarea == G.jokers and context.global then
		if joker_obj.ability.caino_xmult > 1 then FN.SIM.x_mult(joker_obj.ability.caino_xmult) end
	end
end
FNSJ.simulate_triboulet = function(joker_obj, context)
	if context.cardarea == G.play and context.individual then
		if FN.SIM.is_rank(context.other_card, { 12, 13 }) and not context.other_card.debuff then
			FN.SIM.x_mult(joker_obj.ability.extra)
		end
	end
end
FNSJ.simulate_yorick = function(joker_obj, context)
	if context.cardarea == G.hand and context.discard and not context.blueprint then
		if joker_obj.ability.yorick_discards > 1 then
			joker_obj.ability.yorick_discards = joker_obj.ability.yorick_discards - 1
		else
			joker_obj.ability.yorick_discards = joker_obj.ability.extra.discards
			joker_obj.ability.x_mult = joker_obj.ability.x_mult + joker_obj.ability.extra.xmult
		end
	end

	FN.SIM.JOKERS.x_mult_if_global(joker_obj, context)
end
FNSJ.simulate_chicot = function(joker_obj, context)
	-- Effect not relevant (Meta)
end
FNSJ.simulate_perkeo = function(joker_obj, context)
	-- Effect not relevant (Blind)
end
