SMODS.Challenge({
	key = "shared_pockets",
	rules = {
		custom = {
			{ id = "mp_shared_pockets" },
		},
	},
	restrictions = {
		banned_cards = {
			{ id = "j_stencil" },
		},
	},
	apply = function(self)
		G.GAME.starting_params.joker_slots = (G.GAME.starting_params.joker_slots or 0) + 1e5
		G.GAME.starting_params.consumable_slots = (G.GAME.starting_params.consumable_slots or 0) + 1e5
		G.GAME.starting_params.hand_size = (G.GAME.starting_params.hand_size or 0) + 7

		G.GAME.mp_shared_pockets = { count = 0, slots = 15 }
	end,
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})

local cardarea_update_ref = CardArea.update
function CardArea:update(dt)
	if self == G.hand and G.GAME.modifiers.mp_shared_pockets then
		self.config.mp_last_size = self.config.mp_last_size or 0
		local slots = (G.jokers.config.card_count - (G.jokers.config.card_limit - 100005))
			+ (G.consumeables.config.card_count - (G.consumeables.config.card_limit - 100002))
		if slots ~= self.config.last_poll_size then
			self:change_size(self.config.mp_last_size - slots)
			self.config.mp_last_size = slots
		end
	end
	local ret = cardarea_update_ref(self, dt)
	if G.GAME.modifiers.mp_shared_pockets then
		G.GAME.mp_shared_pockets.count = G.hand.config.card_count + G.jokers.config.card_count + G.consumeables.config.card_count
		G.GAME.mp_shared_pockets.limit = G.hand.config.card_limit + G.jokers.config.card_count + G.consumeables.config.card_count
	end
	return ret
end

local uie_update_text_ref = UIElement.update_text
function UIElement:update_text()
	if G.GAME.modifiers.mp_shared_pockets then
		if self.config.ref_value == "card_count" then
			if self.config.ref_table == G.hand.config
				or self.config.ref_table == G.jokers.config
				or self.config.ref_table == G.consumeables.config
			then
				self.config.ref_table = G.GAME.mp_shared_pockets
				self.config.ref_value = "count"
			end
		end
		if self.config.ref_value == "total_slots" then
			if self.config.ref_table == G.hand.config.card_limits
				or self.config.ref_table == G.jokers.config.card_limits
				or self.config.ref_table == G.consumeables.config.card_limits
			then
				self.config.ref_table = G.GAME.mp_shared_pockets
				self.config.ref_value = "limit"
			end
		end
	end
	local ret = uie_update_text_ref(self)
	return ret
end
