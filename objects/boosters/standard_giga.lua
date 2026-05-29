SMODS.Atlas({
	key = "standard_giga",
	path = "standard_giga.png",
	px = 71,
	py = 95,
})

SMODS.Booster({
	key = "standard_giga",
	kind = "Standard",
	group_key = "k_standard_pack",
	atlas = "standard_giga",
	pos = { x = 0, y = 0 },
	config = { extra = 10, choose = 4 },
	cost = 16,
	weight = 0,
	unskippable = true,
	create_card = function(self, card, i)
		local b_append = MP.ante_based()

		local _edition = poll_edition("standard_edition" .. b_append, 2, true)
		local _seal = SMODS.poll_seal({ mod = 10, key = "stdseal" .. b_append })

		return {
			set = (pseudorandom(pseudoseed("stdset" .. b_append)) > 0.6) and "Enhanced" or "Base",
			edition = _edition,
			seal = _seal,
			area = G.pack_cards,
			skip_materialize = true,
			soulable = true,
			key_append = "sta",
		}
	end,
})

MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "can_skip_booster", "mp.standard_giga.unskippable", {
	before = function(ctx, e)
		if SMODS.OPENED_BOOSTER and SMODS.OPENED_BOOSTER.config.center.unskippable then
			e.config.colour = G.C.UI.BACKGROUND_INACTIVE
			e.config.button = nil
			ctx.skip_original = true
			ctx.results = { n = 0 }
		end
	end,
})
