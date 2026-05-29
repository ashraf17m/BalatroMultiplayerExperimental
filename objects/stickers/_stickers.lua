SMODS.Atlas({
	key = "alt_stickers",
	path = "alt_stickers.png",
	px = 71,
	py = 95,
})

local forced_sticker_types = { "persistent", "unreliable", "draining" }

MP.HOOKS.register_method_hook(Card, "Card", "set_ability", "mp.stickers.apply_forced_stickers", {
	after = function(ctx, self)
		local center = ctx.args and ctx.args[1]
		local modifiers = G.GAME.modifiers
		if modifiers then
			for _, sticker_type in ipairs(forced_sticker_types) do
				if modifiers["mp_enable_" .. sticker_type .. "_jokers"] then
					SMODS.Stickers["mp_sticker_" .. sticker_type]:apply(self, center["mp_forced_" .. sticker_type] == true)
				end
			end
		end

		ctx.results = { n = 0 }
	end,
})

local forced_sticker_centers = {
	persistent = {
		"j_greedy_joker",
		"j_lusty_joker",
		"j_wrathful_joker",
		"j_gluttenous_joker",
		"j_8_ball",
		"j_chaos",
		"j_fibonacci",
		"j_hack",
		"j_supernova",
		"j_runner",
		"j_constellation",
		"j_faceless",
		"j_cavendish",
		"j_card_sharp",
		"j_madness",
		"j_riff_raff",
		"j_baron",
		"j_rocket",
		"j_midas_mask",
		"j_photograph",
		"j_mail",
		"j_hallucination",
		"j_fortune_teller",
		"j_diet_cola",
		"j_trousers",
		"j_ancient",
		"j_walkie_talkie",
		"j_smiley",
		"j_ticket",
		"j_certificate",
		"j_hanging_chad",
		"j_onyx_agate",
		"j_blueprint",
		"j_wee",
		"j_seeing_double",
		"j_duo",
		"j_tribe",
		"j_invisible",
		"j_brainstorm",
		"j_cartomancer",
		"j_yorick",
	},
	unreliable = {
		"j_half",
		"j_raised_fist",
		"j_fibonacci",
		"j_abstract",
		"j_gros_michel",
		"j_odd_todd",
		"j_business",
		"j_ride_the_bus",
		"j_ice_cream",
		"j_green_joker",
		"j_cavendish",
		"j_hologram",
		"j_baron",
		"j_obelisk",
		"j_midas_mask",
		"j_gift",
		"j_lucky_cat",
		"j_baseball",
		"j_popcorn",
		"j_smiley",
		"j_campfire",
		"j_sock_and_buskin",
		"j_hanging_chad",
		"j_bloodstone",
		"j_blueprint",
		"j_idol",
		"j_trio",
		"j_stuntman",
		"j_drivers_license",
		"j_triboulet",
		"j_mp_conjoined_joker",
	},
	draining = {
		"j_mime",
		"j_mystic_summit",
		"j_scary_face",
		"j_even_steven",
		"j_business",
		"j_blackboard",
		"j_dna",
		"j_sixth_sense",
		"j_riff_raff",
		"j_vagabond",
		"j_midas_mask",
		"j_reserved_parking",
		"j_mail",
		"j_drunkard",
		"j_golden",
		"j_trading",
		"j_popcorn",
		"j_ancient",
		"j_selzer",
		"j_ticket",
		"j_sock_and_buskin",
		"j_certificate",
		"j_hanging_chad",
		"j_arrowhead",
		"j_oops",
		"j_idol",
		"j_family",
		"j_brainstorm",
		"j_shoot_the_moon",
		"j_burnt",
		"j_triboulet",
		"j_perkeo",
		"j_mp_lets_go_gambling",
		"j_mp_speedrun",
	},
}

local function apply_forced_sticker_center_flags()
	for sticker_type, center_keys in pairs(forced_sticker_centers) do
		local flag = "mp_forced_" .. sticker_type
		for _, center_key in ipairs(center_keys) do
			G.P_CENTERS[center_key][flag] = true
		end
	end
	return true
end

G.E_MANAGER:add_event(Event({
	trigger = "immediate",
	func = apply_forced_sticker_center_flags,
}))
