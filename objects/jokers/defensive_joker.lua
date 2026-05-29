local content_runtime = MP.CONTENT.RUNTIME

SMODS.Atlas({
	key = "defensive_joker",
	path = "j_defensive_joker.png",
	px = 71,
	py = 95,
})

SMODS.Joker({
	key = "defensive_joker",
	atlas = "defensive_joker",
	rarity = 1,
	cost = 4,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = true,
	perishable_compat = true,
	config = { t_chips = 0, extra = { extra = 125, highstake = 75 } },
	loc_vars = function(self, info_queue, card)
		local stake = (G.GAME and G.GAME.stake) or 1
		local chips = stake >= 6 and card.ability.extra.highstake or card.ability.extra.extra
		return { vars = { chips, card.ability.t_chips or 0 } }
	end,
	mp_include = content_runtime.include_multiplayer_jokers,
	update = function(self, card, dt)
		if not content_runtime.has_active_lobby() then
			card.ability.t_chips = 0
			return
		end

		if G.STAGE ~= G.STAGES.RUN or not G.GAME then return end

		local enemy = content_runtime.get_nemesis_enemy_state()
		local lives = content_runtime.get_match_value("lives")
		if not enemy or enemy.lives == nil or lives == nil then
			card.ability.t_chips = 0
			return
		end

		local chips = G.GAME.stake >= 6 and card.ability.extra.highstake or card.ability.extra.extra
		card.ability.t_chips = math.max((enemy.lives - lives) * chips, 0)
	end,
	calculate = function(self, card, context)
		if context.cardarea == G.jokers and context.joker_main then
			return {
				message = localize({
					type = "variable",
					key = "a_chips",
					vars = { card.ability.t_chips },
				}),
				chip_mod = card.ability.t_chips,
			}
		end
	end,
	mp_credits = {
		idea = { "didon't" },
		art = { "TheTrueRaven" },
		code = { "Virtualized" },
	},
})
