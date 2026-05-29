local content_runtime = MP.CONTENT.RUNTIME

-- The PvP boss path stores per-card rolls so retries preserve Bloodstone outcomes.

local function get_bloodstone_probability(card)
	if SMODS and type(SMODS.get_probability_vars) == "function" then
		return SMODS.get_probability_vars(card, 1, card.ability.extra.odds, "bloodstone", true)
	end
	return G and G.GAME and G.GAME.probabilities and G.GAME.probabilities.normal or 1, card.ability.extra.odds
end

local function append_bloodstone_probability_result(card, result, numerator, denominator)
	if not SMODS then return end
	SMODS.post_prob = SMODS.post_prob or {}
	SMODS.post_prob[#SMODS.post_prob + 1] = {
		pseudorandom_result = true,
		result = result,
		trigger_obj = card,
		numerator = numerator,
		denominator = denominator,
		identifier = "bloodstone",
	}
end

local function bloodstone_roll_succeeds(card, roll)
	local numerator, denominator = get_bloodstone_probability(card)
	local result = roll < numerator / denominator
	append_bloodstone_probability_result(card, result, numerator, denominator)
	return result
end

SMODS.Joker({
	key = "bloodstone",
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	perishable_compat = true,
	eternal_compat = true,
	rarity = 2,
	cost = 7,
	pos = { x = 0, y = 8 },
	mp_include = content_runtime.include_standard_ruleset,
	config = { extra = { odds = 2, Xmult = 1.5 } },
	loc_vars = function(self, info_queue, card)
		local numerator, denominator = get_bloodstone_probability(card)
		return {
			key = "j_bloodstone",
			vars = {
				numerator,
				denominator,
				card.ability.extra.Xmult,
			},
		}
	end,
	calculate = function(self, card, context)
		if content_runtime.is_pvp_boss() then
			if not context.blueprint then
				if context.before then
					local round_index = content_runtime.get_round_order_index()
					G.GAME.round_resets.mp_bloodstone = G.GAME.round_resets.mp_bloodstone or {}
					G.GAME.round_resets.mp_bloodstone[round_index] = G.GAME.round_resets.mp_bloodstone[round_index] or {}
					G.GAME.round_resets.mp_bsindex = 0
				end
			end
			if context.individual and context.cardarea == G.play then
				if context.other_card:is_suit("Hearts") then
					local round_index = content_runtime.get_round_order_index()
					local stored_queue = G.GAME.round_resets.mp_bloodstone[round_index]
					G.GAME.round_resets.mp_bsindex = G.GAME.round_resets.mp_bsindex + 1
					stored_queue[G.GAME.round_resets.mp_bsindex] = stored_queue[G.GAME.round_resets.mp_bsindex]
						or pseudorandom("bloodstone" .. round_index)
					if bloodstone_roll_succeeds(card, stored_queue[G.GAME.round_resets.mp_bsindex]) then
						return {
							x_mult = card.ability.extra.Xmult,
							card = card,
						}
					end
				end
			end
		elseif context.individual and context.cardarea == G.play then
			if context.other_card:is_suit("Hearts") and bloodstone_roll_succeeds(card, pseudorandom("bloodstone")) then
				return {
					x_mult = card.ability.extra.Xmult,
					card = card,
				}
			end
		end
	end,
})
