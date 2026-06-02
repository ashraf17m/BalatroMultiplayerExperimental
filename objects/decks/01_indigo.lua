SMODS.Back({
	key = "indigo",
	config = {},
	atlas = "mp_decks",
	pos = { x = 1, y = 0 },
	mp_credits = { art = { "aura!" }, code = { "Toneblock" } },
	apply = function(self)
		G.GAME.modifiers.mp_indigo = true
		G.GAME.modifiers.booster_choice_mod = (G.GAME.modifiers.booster_choice_mod or 0) + 1
		G.GAME.banned_keys["j_red_card"] = true
	end,
})

local function check_joker_space(card)
	if card.config.center.set == "Joker" and card.edition and card.edition.negative then return true end
	local c = 0
	local un_c = G.jokers.config.card_limit
	for i, v in ipairs(G.jokers.cards) do
		if v.edition and v.edition.type == "negative" then
			un_c = un_c - 1
		elseif v.ability.eternal then
			c = c + 1
		else
			break
		end
	end
	return c < un_c
end

local spectral_hand_required = {
	c_familiar = true,
	c_grim = true,
	c_incantation = true,
	c_immolate = true,
	c_sigil = true,
	c_ouija = true,
}

local function has_entries(value)
	return value and next(value) ~= nil
end

local function has_required_highlighted_cards(card)
	return #G.hand.cards >= (card.ability.consumeable.min_highlighted or 1)
end

local function has_editionless_hand_card()
	for _, hand_card in ipairs(G.hand.cards) do
		if not hand_card.edition then
			return true
		end
	end

	return false
end

local function is_usable(card)
	local center = card.config.center
	local key = center.key
	if center.set == "Enhanced" or center.set == "Default" or center.set == "Planet" then
		return true
	elseif center.set == "Joker" then
		return check_joker_space(card)
	elseif center.set == "Tarot" then
		if key == "c_fool" then
			return G.GAME.last_tarot_planet and G.GAME.last_tarot_planet ~= "c_fool"
		elseif key == "c_judgement" then
			return check_joker_space(card)
		elseif key == "c_wheel_of_fortune" then
			return has_entries(card.eligible_strength_jokers)
		elseif card.ability.consumeable.max_highlighted then
			return has_required_highlighted_cards(card)
		else
			return true
		end
	elseif center.set == "Spectral" then
		if spectral_hand_required[key] then
			return #G.hand.cards > 1
		elseif key == "c_aura" then
			return has_editionless_hand_card()
		elseif key == "c_ectoplasm" or key == "c_hex" then
			return has_entries(card.eligible_editionless_jokers)
		elseif key == "c_wraith" or key == "c_soul" then
			return check_joker_space(card)
		elseif key == "c_ankh" then
			return G.jokers.cards[1] and check_joker_space(card) or false
		elseif card.ability.consumeable.max_highlighted then
			return has_required_highlighted_cards(card)
		else
			return true
		end
	end
	return true
end

MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "can_skip_booster", "mp.indigo.prevent_non_softlock_skip", {
	before = function(ctx, e)
		if not G.GAME.modifiers.mp_indigo then
			return
		end

		local softlock = true
		for i, v in ipairs(G.pack_cards.cards) do
			if is_usable(v) then
				softlock = false
				break
			end
		end
		if not softlock then
			e.config.colour = G.C.UI.BACKGROUND_INACTIVE
			e.config.button = nil
			ctx.skip_original = true
			ctx.results = { n = 0 }
		end
	end,
})
