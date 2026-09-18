-- Consolidated objects/stickers.lua
-- Combines all 7 micro-files from objects/stickers/ into a single file

-- === _stickers.lua ===
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

-- === 1_persistent.lua ===
SMODS.Sticker({
	key = "sticker_persistent",
	atlas = "alt_stickers",
	pos = { x = 0, y = 0 },
	badge_colour = HEX("5541CC"),
	default_compat = false,
	needs_enable_flag = true,
	apply = function(self, card, val)
		if card and card.edition and card.edition.type == "mp_phantom" then return end
		local old_val = card.ability.mp_sticker_persistent or false
		card.ability.mp_sticker_persistent = val
		if old_val ~= val then card:set_cost() end
	end,
	calculate = function(self, card, context)
		if context.end_of_round and not context.repetition and not context.individual then
			card.ability.mp_extra_sell_price = (card.ability.mp_extra_sell_price or 0) + 3
			card_eval_status_text(
				card,
				"extra",
				nil,
				nil,
				nil,
				{ message = localize("k_cost_up"), colour = G.C.RED, delay = 0.45 }
			)
			card:set_cost()
		end
	end,
})

local function calculate_persistent_sell_price(card)
	local ability = card and card.ability
	if not ability then return 0 end

	return (tonumber(card.sell_cost) or 0) + (tonumber(ability.mp_extra_sell_price) or 0)
end

local function ensure_persistent_sell_price(card)
	local ability = card and card.ability
	if not ability then return 0 end

	if type(ability.mp_sell_price) ~= "number" then
		ability.mp_sell_price = calculate_persistent_sell_price(card)
	end

	return ability.mp_sell_price
end

local function refresh_persistent_sell_price(card)
	local ability = card and card.ability
	if not (ability and ability.mp_sticker_persistent) then return end

	ability.mp_sell_price = calculate_persistent_sell_price(card)
	card.sell_cost_label = card.facing == "back" and "?" or ability.mp_sell_price
end

MP.PLATFORM.SMODS.override_known("is_eternal", function(is_eternal_ref)
	return function(card, trigger)
		local ret = is_eternal_ref(card, trigger)
		if card and card.ability and card.ability.mp_sticker_persistent and not (trigger and trigger.from_sell) then
			ret = true
		end
		return ret
	end
end)

-- make sell button red
MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "can_sell_card", "mp.persistent_sticker.sell_button", {
	before = function(ctx, e)
		local card = e and e.config and e.config.ref_table or nil
		local ability = card and card.ability or nil
		if ability and ability.mp_sticker_persistent then
			local sell_price = ensure_persistent_sell_price(card)
			local dollars = G and G.GAME and G.GAME.dollars or 0
			if card:can_sell_card() and sell_price <= dollars then
				e.config.colour = G.C.RED
				e.config.button = "sell_card"
			else
				e.config.colour = G.C.UI.BACKGROUND_INACTIVE
				e.config.button = nil
			end
			ctx.skip_original = true
			ctx.results = { n = 0 }
		end
	end,
})

-- Mirror the sell flow so the persistent sticker can invert the sell action into a cost.
MP.HOOKS.register_method_hook(Card, "Card", "sell_card", "mp.persistent_sticker.invert_sell", {
	before = function(ctx, self)
		if not (self and self.ability and self.ability.mp_sticker_persistent) then return end

		G.CONTROLLER.locks.selling_card = true
		stop_use()
		local area = self.area
		G.CONTROLLER:save_cardarea_focus(area == G.jokers and "jokers" or "consumeables")

		if self.children.use_button then
			self.children.use_button:remove()
			self.children.use_button = nil
		end
		if self.children.sell_button then
			self.children.sell_button:remove()
			self.children.sell_button = nil
		end

		self:calculate_joker({ selling_self = true })

		G.E_MANAGER:add_event(Event({
			trigger = "after",
			delay = 0.2,
			func = function()
				self:juice_up(0.3, 0.4)
				return true
			end,
		}))
		delay(0.2)
		G.E_MANAGER:add_event(Event({
			trigger = "immediate",
			func = function()
				ease_dollars(-ensure_persistent_sell_price(self))
				self:start_dissolve({ G.C.RED })
				delay(0.3)

				inc_career_stat("c_cards_sold", 1)
				if self.ability.set == "Joker" then inc_career_stat("c_jokers_sold", 1) end
				if self.ability.set == "Joker" and G.GAME.blind and G.GAME.blind.name == "Verdant Leaf" then
					G.E_MANAGER:add_event(Event({
						trigger = "immediate",
						func = function()
							G.GAME.blind:disable()
							return true
						end,
					}))
				end
				G.E_MANAGER:add_event(Event({
					trigger = "after",
					delay = 0.3,
					blocking = false,
					func = function()
						G.E_MANAGER:add_event(Event({
							trigger = "immediate",
							func = function()
								G.E_MANAGER:add_event(Event({
									trigger = "immediate",
									func = function()
										G.CONTROLLER.locks.selling_card = nil
										G.CONTROLLER:recall_cardarea_focus(area == G.jokers and "jokers" or "consumeables")
										return true
									end,
								}))
								return true
							end,
						}))
						return true
					end,
				}))
				return true
			end,
		}))
		ctx.skip_original = true
		ctx.results = { n = 0 }
	end,
})

MP.HOOKS.register_method_hook(Card, "Card", "set_cost", "mp.persistent_sticker.sell_price", {
	after = function(ctx, self)
		refresh_persistent_sell_price(self)
	end,
})

MP.HOOKS.register_method_hook(Card, "Card", "update", "mp.persistent_sticker.sell_price_label", {
	after = function(ctx, self)
		if self and self.ability and self.ability.mp_sticker_persistent then
			self.sell_cost_label = self.facing == "back" and "?" or ensure_persistent_sell_price(self)
		end
	end,
})

local generate_card_ui_ref = generate_card_ui
function generate_card_ui(_c, full_UI_table, specific_vars, card_type, badges, hide_desc, main_start, main_end, card)
	local ret =
		generate_card_ui_ref(_c, full_UI_table, specific_vars, card_type, badges, hide_desc, main_start, main_end, card)
	if card and card.ability and card.ability.mp_sticker_persistent and not G.OVERLAY_MENU then -- check for card and for tag
		generate_card_ui_ref({ key = "mp_internal_sell_value", set = "Other", vars = { ensure_persistent_sell_price(card) } }, ret)
	end
	return ret
end

-- === 2_unreliable.lua ===
SMODS.Sticker({
	key = "sticker_unreliable",
	atlas = "alt_stickers",
	pos = { x = 1, y = 0 },
	badge_colour = HEX("7CA39A"),
	default_compat = false,
	needs_enable_flag = true,
})

MP.HOOKS.register_method_hook(Card, "Card", "calculate_joker", "mp.unreliable_sticker.phantom_only_on_last_hand", {
	before = function(ctx, self)
		if self.ability.mp_sticker_unreliable and G.GAME.current_round.hands_left == 0 then
			if not self.edition or self.edition.type ~= "mp_phantom" then
				ctx.skip_original = true
				ctx.results = { n = 0 }
			end
		end
	end,
})

-- === 3_draining.lua ===
SMODS.Sticker({
	key = "sticker_draining",
	atlas = "alt_stickers",
	pos = { x = 2, y = 0 },
	badge_colour = HEX("A13333"),
	default_compat = false,
	needs_enable_flag = true,
	calculate = function(self, card, context)
		if card and card.edition and card.edition.type == "mp_phantom" then return end
		if context.joker_main then return {
			x_mult = 0.75,
		} end
	end,
})

-- === balanced.lua ===
SMODS.Atlas({
	key = "sticker_balanced",
	path = "sticker_balanced.png",
	px = 71,
	py = 95,
})

SMODS.Sticker({
	key = "sticker_balanced",
	atlas = "sticker_balanced",
	badge_colour = G.C.MULTIPLAYER,
	default_compat = false,
	needs_enable_flag = true,
	hide_badge = false,
	loc_vars = function(self, info_queue, card)
		local key = "mp_sticker_balanced_" .. card.config.center_key
		if G.localization.descriptions.Other[key] then
			return { key = key }
		end
		return {}
	end,
})

-- === extra_credit.lua ===
SMODS.Sticker({
	key = "sticker_extra_credit",
	atlas = "ec_other_sandbox",
	pos = {
		x = 1,
		y = 1,
	},
	badge_colour = HEX("FBA105"),
	default_compat = false,
	needs_enable_flag = true,
	hide_badge = false,
})

-- === nemesis.lua ===
SMODS.Atlas({
	key = "sticker_nemesis",
	path = "sticker_nemesis.png",
	px = 71,
	py = 95,
})

SMODS.Sticker({
	key = "sticker_nemesis",
	atlas = "sticker_nemesis",
	badge_colour = G.C.MULTIPLAYER,
	default_compat = false,
	needs_enable_flag = true,
	hide_badge = true,
})

