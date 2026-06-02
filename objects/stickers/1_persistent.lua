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
