-- The functions responsible for running the simulation at appropriate times;
-- ie. whenever the player modifies card selection or card order.

function FN.PRE.simulate()
	-- Guard against simulating in redundant places:
	if not FN.PRE.is_preview_state() then
		return { score = { min = 0, exact = 0, max = 0 }, dollars = { min = 0, exact = 0, max = 0 } }
	end

	if G.SETTINGS.FN.hide_face_down then
		for _, card in ipairs(G.hand.highlighted) do
			if card.facing == "back" then return nil end
		end
		if #G.hand.highlighted ~= 0 then
			for _, joker in ipairs(G.jokers.cards) do
				if joker.facing == "back" then return nil end
			end
		end
	end

	return FN.SIM.run()
end

-- Simulation update hooks:

function FN.PRE.add_update_event(trigger)
	local function sim_func()
		FN.PRE.data = FN.PRE.simulate()
		return true
	end
	if FN.PRE.enabled() then
		G.E_MANAGER:add_event(Event({ trigger = trigger, blockable = false, blocking = false, func = sim_func }))
	end
end

-- Update simulation after a consumable (eg. Tarot, Planet) is used:
local orig_use = Card.use_consumeable
function Card:use_consumeable(area, copier)
	orig_use(self, area, copier)
	if not FN.PRE.integration_enabled() then return end
	if not FN.PRE.enabled() then return end
	FN.PRE.add_update_event("immediate")
end

-- Update simulation after card selection changed:
local orig_hl = CardArea.parse_highlighted
function CardArea:parse_highlighted()
	orig_hl(self)
	if not FN.PRE.integration_enabled() then return end
	if not FN.PRE.enabled() then return end

	if not FN.PRE.lock_updates and FN.PRE.show_preview then FN.PRE.show_preview = false end
	FN.PRE.add_update_event("immediate")
end

-- Update simulation after joker sold:
local orig_card_remove = Card.remove_from_area
function Card:remove_from_area()
	orig_card_remove(self)
	if not FN.PRE.integration_enabled() then return end
	if not FN.PRE.enabled() then return end

	if self.config.type == "joker" then FN.PRE.add_update_event("immediate") end
end

-- Update simulation after joker reordering:
local orig_update = CardArea.update
function CardArea:update(dt)
	orig_update(self, dt)
	if not FN.PRE.integration_enabled() then return end
	if not FN.PRE.enabled() then return end

	FN.PRE.update_on_card_order_change(self)
end

function FN.PRE.update_on_card_order_change(cardarea)
	if #cardarea.cards == 0 or not FN.PRE.is_preview_state() then return end

	local prev_order
	if cardarea.config.type == "joker" and cardarea.cards[1].ability.set == "Joker" then
		if cardarea.cards[1].edition and cardarea.cards[1].edition.mp_phantom then return end
		-- Note that the consumables cardarea also has type 'joker' so must verify by checking first card.
		prev_order = FN.PRE.joker_order
	elseif cardarea.config.type == "hand" then
		prev_order = FN.PRE.hand_order
	else
		return
	end

	-- Go through stored card IDs and check against current card IDs, in-order.
	-- If any mismatch occurs, toggle flag and update name for next time.
	local should_update = false
	if #cardarea.cards ~= #prev_order then prev_order = {} end
	for i, c in ipairs(cardarea.cards) do
		if c.sort_id ~= prev_order[i] then
			prev_order[i] = c.sort_id
			should_update = true
		end
	end

	if should_update then
		if cardarea.config.type == "joker" or cardarea.cards[1].ability.set == "Joker" then
			FN.PRE.joker_order = prev_order
		elseif cardarea.config.type == "hand" then
			FN.PRE.hand_order = prev_order
		end
		if FN.PRE.show_preview and not FN.PRE.lock_updates then FN.PRE.show_preview = false end
		FN.PRE.add_update_event("immediate")
	end
end

-- Simulation reset hooks:

function FN.PRE.add_reset_event(trigger)
	local function reset_func()
		FN.PRE.data = { score = { min = 0, exact = 0, max = 0 }, dollars = { min = 0, exact = 0, max = 0 } }
		return true
	end
	if FN.PRE.enabled() then
		G.E_MANAGER:add_event(Event({ trigger = trigger, func = reset_func }))
	end
end

local orig_eval = G.FUNCS.evaluate_play
function G.FUNCS.evaluate_play(e)
	orig_eval(e)

	if not FN.PRE.integration_enabled() then return end
	if not FN.PRE.enabled() then return end
	FN.PRE.add_reset_event("after")
end

local orig_discard = G.FUNCS.discard_cards_from_highlighted
function G.FUNCS.discard_cards_from_highlighted(e, is_hook_blind)
	orig_discard(e, is_hook_blind)

	if not FN.PRE.integration_enabled() then return end
	if not FN.PRE.enabled() then return end
	if not is_hook_blind then FN.PRE.add_reset_event("immediate") end
end
