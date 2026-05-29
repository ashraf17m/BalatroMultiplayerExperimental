local content_runtime = MP.CONTENT.RUNTIME

SMODS.Atlas({
	key = "conjoined_joker",
	path = "j_conjoined_joker.png",
	px = 71,
	py = 95,
})

SMODS.Joker(content_runtime.with_phantom_sync_hooks({
	key = "conjoined_joker",
	atlas = "conjoined_joker",
	rarity = 2,
	cost = 6,
	unlocked = true,
	discovered = true,
	blueprint_compat = true,
	eternal_compat = true,
	perishable_compat = true,
	config = { extra = { x_mult_gain = 0.5, max_x_mult = 3, x_mult = 1 } },
	loc_vars = function(self, info_queue, card)
		MP.UTILS.add_nemesis_info(info_queue)
		return { vars = { card.ability.extra.x_mult_gain, card.ability.extra.max_x_mult, card.ability.extra.x_mult } }
	end,
	mp_include = function(self)
		return content_runtime.include_multiplayer_jokers() and not content_runtime.is_ruleset_active("sandbox")
	end,
	update = function(self, card, dt)
		if not content_runtime.has_active_lobby() then
			card.ability.extra.x_mult = 1
			return
		end

		if G.STAGE ~= G.STAGES.RUN then return end

		local nemesis = content_runtime.get_nemesis_enemy_state()
		if not nemesis or nemesis.hands == nil then
			card.ability.extra.x_mult = 1
			return
		end

		card.ability.extra.x_mult = math.max(
			math.min(1 + (nemesis.hands * card.ability.extra.x_mult_gain), card.ability.extra.max_x_mult),
			1
		)
	end,
	calculate = function(self, card, context)
		if
			context.cardarea == G.jokers
			and context.joker_main
			and content_runtime.is_pvp_boss()
			and not content_runtime.is_phantom_card(card)
		then
			return {
				x_mult = card.ability.extra.x_mult,
			}
		end
	end,
	mp_credits = {
		idea = { "Zilver" },
		art = { "Nas4xou" },
		code = { "Virtualized" },
	},
}, "j_mp_conjoined_joker"))
