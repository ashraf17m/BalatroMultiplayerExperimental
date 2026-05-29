MP.COMPAT = MP.COMPAT or {}
MP.COMPAT.THE_ORDER = MP.COMPAT.THE_ORDER or {}

local THE_ORDER = MP.COMPAT.THE_ORDER

function THE_ORDER.with_zero_ante(callback)
	local original_ante = G.GAME.round_resets.ante
	G.GAME.round_resets.ante = 0

	local ok, result = pcall(callback)
	G.GAME.round_resets.ante = original_ante

	if not ok then
		error(result)
	end

	return result
end

function THE_ORDER.build_rank_order()
	local value_order = {}
	for index, rank in ipairs(MP.PLATFORM.SMODS.get_rank_buffer()) do
		value_order[rank] = index
	end
	return value_order
end

function THE_ORDER.build_suit_order()
	local suit_order = {}
	for index, suit in ipairs(MP.PLATFORM.SMODS.get_suit_buffer()) do
		suit_order[suit] = index
	end
	return suit_order
end

function THE_ORDER.uses_competitive_voucher_queue()
	return MP.should_use_the_order() or MP.is_major_league_ruleset()
end

function MP.ante_based()
	if MP.should_use_the_order() then
		return 0
	end
	return G.GAME.round_resets.ante
end

function MP.order_round_based(ante_based)
	if MP.should_use_the_order() then
		return G.GAME.round_resets.ante .. (G.GAME.blind.config.blind.key or "")
	end
	if ante_based then
		return MP.ante_based()
	end
	return ""
end

function MP.sorted_hand_list(current_hand)
	if not current_hand then
		current_hand = "NULL"
	end
	local _poker_hands = {}
	local done = false
	local order = 1
	while not done do
		done = true
		for key, hand in pairs(G.GAME.hands) do
			if hand.order == order then
				order = order + 1
				done = false
				if hand.visible and key ~= current_hand then
					_poker_hands[#_poker_hands + 1] = key
				end
			end
		end
	end
	return _poker_hands
end
