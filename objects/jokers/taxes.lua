local content_runtime = MP.CONTENT.RUNTIME

local function next_taxes_total_mult_gain(card)
	local current_ante = G.GAME.round_resets.ante
	local sells = content_runtime.get_enemy_sells_for_ante(current_ante)

	-- If PvP hasn't been reached for the first time, accumulate sells from previous Antes
	if current_ante <= (tonumber(content_runtime.get_lobby_config_value("pvp_start_round", 0)) or 0) then
		for i = 1, current_ante - 1 do
			sells = sells + content_runtime.get_enemy_sells_for_ante(i)
		end
	end

	return sells * card.ability.extra.mult_gain
end

SMODS.Atlas({
	key = "taxes",
	path = "j_taxes.png",
	px = 71,
	py = 95,
})

SMODS.Joker({
	key = "taxes",
	atlas = "taxes",
	rarity = 1,
	cost = 5,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = true,
	perishable_compat = false,
	config = { extra = { mult_gain = 4, mult = 0 } },
	loc_vars = function(self, info_queue, card)
		MP.UTILS.add_nemesis_info(info_queue)
		return { vars = { card.ability.extra.mult_gain, card.ability.extra.mult } }
	end,
	mp_include = content_runtime.include_multiplayer_jokers,
	calculate = function(self, card, context)
		if context.cardarea == G.jokers and context.joker_main then
			return {
				mult = card.ability.extra.mult,
			}
		elseif
			context.cardarea == G.jokers
			and context.setting_blind
			and not context.blueprint
			and context.blind.key == "bl_mp_nemesis"
		then
			card.ability.extra.mult = card.ability.extra.mult + next_taxes_total_mult_gain(card)
			return {
				message = localize("k_filed_ex"),
			}
		end
	end,
	mp_credits = {
		idea = { "Zwei" },
		art = { "Kittyknight" },
		code = { "Virtualized" },
	},
})
