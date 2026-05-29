local content_runtime = MP.CONTENT.RUNTIME

SMODS.Atlas({
	key = "skip_off",
	path = "j_skip_off.png",
	px = 71,
	py = 95,
})

local function get_skip_off_nemesis()
	return content_runtime.get_nemesis_enemy_state()
end

local function get_skip_off_status(game, nemesis)
	if not game or game.skips == nil or not nemesis or nemesis.skips == nil then
		return ""
	end

	return localize({
		type = "variable",
		key = nemesis.skips > game.skips and "a_mp_skips_behind"
			or nemesis.skips == game.skips and "a_mp_skips_tied"
			or "a_mp_skips_ahead",
		vars = { math.abs(nemesis.skips - game.skips) },
	})[1] or ""
end

local function get_skip_off_difference(game, nemesis)
	if not game or game.skips == nil or not nemesis or nemesis.skips == nil then
		return 0
	end

	return math.max(game.skips - nemesis.skips, 0)
end

SMODS.Joker({
	key = "skip_off",
	atlas = "skip_off",
	rarity = 2,
	cost = 5,
	unlocked = true,
	discovered = true,
	blueprint_compat = false,
	eternal_compat = true,
	perishable_compat = true,
	config = { extra = { hands = 0, discards = 0, extra_hands = 1, extra_discards = 1 } },
	loc_vars = function(self, info_queue, card)
		local game = G.GAME
		local nemesis = get_skip_off_nemesis()

		MP.UTILS.add_nemesis_info(info_queue)
		return {
			vars = {
				card.ability.extra.extra_hands,
				card.ability.extra.extra_discards,
				card.ability.extra.hands,
				card.ability.extra.discards,
				get_skip_off_status(game, nemesis),
			},
		}
	end,
	mp_include = content_runtime.include_multiplayer_jokers,
	update = function(self, card, dt)
		local game = G.GAME
		local nemesis = get_skip_off_nemesis()
		if G.STAGE == G.STAGES.RUN then
			local skip_diff = get_skip_off_difference(game, nemesis)
			card.ability.extra.hands = skip_diff * card.ability.extra.extra_hands
			card.ability.extra.discards = skip_diff * card.ability.extra.extra_discards
		else
			card.ability.extra.hands = 0
			card.ability.extra.discards = 0
		end
	end,
	calculate = function(self, card, context)
		if context.cardarea == G.jokers and context.setting_blind and not context.blueprint then
			G.E_MANAGER:add_event(Event({
				func = function()
					ease_hands_played(card.ability.extra.hands)
					ease_discard(card.ability.extra.discards, nil, true)
					return true
				end,
			}))
		end
	end,
	mp_credits = {
		idea = { "Dr. Monty", "Carter" },
		art = { "Aura!" },
		code = { "Virtualized" },
	},
})
