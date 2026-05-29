local function rework_glass(rulesets, extra)
	MP.ReworkCenter("m_glass", {
		rulesets = rulesets,
		config = { Xmult = 1.5, extra = extra },
	})
end

rework_glass(MP.UTILS.get_standard_rulesets(), 4)
rework_glass("sandbox", 3)
rework_glass("legacy_ranked", 4)

local function register_display_glass(key, extra)
	SMODS.Enhancement({
		key = key,
		config = { extra = { Xmult = 1.5, extra = extra }, mp_sticker_balanced = true },
		pos = { x = 5, y = 1 },
		no_collection = true,
		shatters = true,
		loc_vars = function(self, info_queue, card)
			local num, denom = SMODS.get_probability_vars(card, 1, card.ability.extra.extra, "glass")
			return {
				vars = {
					card.ability.extra.Xmult,
					num,
					denom,
				},
			}
		end,
		in_pool = function(self, args)
			return false
		end,
	})
end

-- These are fixed-value glass cards for ruleset descriptions, so they should
-- not inherit the vanilla X2 display.
register_display_glass("display_glass", 4)
register_display_glass("sandbox_display_glass", 3)
