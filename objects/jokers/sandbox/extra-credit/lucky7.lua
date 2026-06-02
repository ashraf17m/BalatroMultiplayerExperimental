MP.EC.register_sandbox_joker({
	key = "lucky7_sandbox",
	blueprint_compat = false,
	eternal_compat = true,

	rarity = 1,
	cost = 6,
	pos = { x = 7, y = 3 },

	config = {
		extra = {
			lucky = false,
			checked = false,
		},
	},

	loc_vars = function(self, info_queue, card)
		info_queue[#info_queue + 1] = G.P_CENTERS.m_lucky
		return
	end,

	calculate = function(self, card, context)
		if context.before and not context.blueprint then
			local has_seven = false
			for i = 1, #context.scoring_hand do
				if MP.GRADIENT.matches_rank(context.scoring_hand[i], 7) and not context.scoring_hand[i].debuff then
					has_seven = true
					break
				end
			end

			if has_seven then
				for i = 1, #context.scoring_hand do
					context.scoring_hand[i].gambling = true
					-- Refresh SMODS enhancement cache after marking the temporary Lucky state.
					if SMODS.enh_cache and SMODS.enh_cache.write then
						SMODS.enh_cache:write(context.scoring_hand[i], nil)
					end
				end
			end
		end

		if context.check_enhancement then
			if context.other_card.gambling then return {
				m_lucky = true,
			} end
		end

		if context.after then
			for i = 1, #context.scoring_hand do
				context.scoring_hand[i].gambling = nil
			end
		end
	end,

	mp_credits = {
		code = { "CampfireCollective", "steph" },
		art = { "bishopcorrigan" },
	},
})
