local centers = {
	c_base = 0,
	m_stone = 106,
	m_bonus = 107,
	m_mult = 108,
	m_wild = 109,
	m_gold = 110,
	m_lucky = 111,
	m_steel = 112,
	m_glass = 113,
}

local seals = {
	Gold = 122,
	Blue = 131,
	Purple = 140,
	Red = 149,
}

local editions = {
	foil = 157,
	holo = 192,
	polychrome = 227,
}

MP.HOOKS.register_method_hook(CardArea, "CardArea", "shuffle", "mp.the_order.deterministic_deck_shuffle", {
	before = function(ctx, self)
		local _seed = ctx.args[1]
		if not (MP.should_use_the_order() and self == G.deck) then
			return
		end

		local grouped_cards = {}

		for _, card in ipairs(self.cards) do
			card.mp_stdval = 0 + (centers[card.config.center_key] or 0)
			card.mp_stdval = card.mp_stdval + (seals[card.seal or "nil"] or 0)
			card.mp_stdval = card.mp_stdval + (editions[card.edition and card.edition.type or "nil"] or 0)
			local key = card.config.center_key == "m_stone" and "Stone" or card.base.suit .. card.base.id
			grouped_cards[key] = grouped_cards[key] or {}
			grouped_cards[key][#grouped_cards[key] + 1] = card
		end

		local true_seed = pseudorandom(_seed or "shuffle")
		for key, cards in pairs(grouped_cards) do
			table.sort(cards, function(left, right)
				return left.mp_stdval > right.mp_stdval
			end)
			local mega_seed = key .. true_seed
			for _, card in ipairs(cards) do
				card.mp_shuffleval = pseudorandom(mega_seed)
			end
		end

		table.sort(self.cards, function(left, right)
			return left.mp_shuffleval > right.mp_shuffleval
		end)
		self:set_ranks()
		ctx.skip_original = true
		ctx.results = { n = 0 }
	end,
})

local original_pseudorandom_element = pseudorandom_element
function pseudorandom_element(_t, seed, args)
	if MP.should_use_the_order() then
		local is_joker = true
		for _, value in pairs(_t) do
			if not (type(value) == "table" and value.ability and value.ability.set == "Joker") then
				is_joker = false
				break
			end
		end

		if is_joker then
			local grouped_jokers = {}
			local keys = {}

			for key, value in pairs(_t) do
				keys[#keys + 1] = { k = key, v = value }
				local joker_key = value.config.center.key
				grouped_jokers[joker_key] = grouped_jokers[joker_key] or {}
				grouped_jokers[joker_key][#grouped_jokers[joker_key] + 1] = value
			end

			local true_seed = pseudorandom(seed or math.random())
			for key, cards in pairs(grouped_jokers) do
				table.sort(cards, function(left, right)
					return left.sort_id < right.sort_id
				end)
				local mega_seed = key .. true_seed
				for _, card in ipairs(cards) do
					card.mp_shuffleval = pseudorandom(mega_seed)
				end
			end

			table.sort(keys, function(left, right)
				return left.v.mp_shuffleval > right.v.mp_shuffleval
			end)

			local key = keys[1].k
			return _t[key], key
		end
	end

	return original_pseudorandom_element(_t, seed, args)
end
