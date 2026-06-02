local THE_ORDER = MP.COMPAT.THE_ORDER

local original_reset_idol_card = reset_idol_card
function reset_idol_card()
	if MP.should_use_the_order() then
		G.GAME.current_round.idol_card.rank = "Ace"
		G.GAME.current_round.idol_card.suit = "Spades"

		local count_map = {}
		local valid_idol_cards = {}

		for _, card in ipairs(G.playing_cards) do
			if card.ability.effect ~= "Stone Card" then
				local key = card.base.value .. "_" .. card.base.suit
				if not count_map[key] then
					count_map[key] = { count = 0, card = card }
					table.insert(valid_idol_cards, count_map[key])
				end
				count_map[key].count = count_map[key].count + 1
			end
		end

		if #valid_idol_cards == 0 then
			return
		end

		local value_order = THE_ORDER.build_rank_order()
		local suit_order = THE_ORDER.build_suit_order()

		table.sort(valid_idol_cards, function(left, right)
			if left.count ~= right.count then
				return left.count > right.count
			end

			local left_suit = left.card.base.suit
			local right_suit = right.card.base.suit
			if suit_order[left_suit] ~= suit_order[right_suit] then
				return suit_order[left_suit] < suit_order[right_suit]
			end

			local left_value = left.card.base.value
			local right_value = right.card.base.value
			return value_order[left_value] < value_order[right_value]
		end)

		local total_weight = 0
		for _, entry in ipairs(valid_idol_cards) do
			total_weight = total_weight + entry.count
		end

		local raw_random = pseudorandom("idol" .. G.GAME.round_resets.ante)
		local threshold = 0
		for _, entry in ipairs(valid_idol_cards) do
			threshold = threshold + (entry.count / total_weight)
			if raw_random < threshold then
				local idol_card = entry.card
				sendDebugMessage(
					"(Idol) Selected card "
						.. idol_card.base.value
						.. " of "
						.. idol_card.base.suit
						.. " with weight "
						.. entry.count
						.. " of total "
						.. total_weight
				)
				G.GAME.current_round.idol_card.rank = idol_card.base.value
				G.GAME.current_round.idol_card.suit = idol_card.base.suit
				G.GAME.current_round.idol_card.id = idol_card.base.id
				break
			end
		end
		return
	end

	return original_reset_idol_card()
end

local original_reset_mail_rank = reset_mail_rank
function reset_mail_rank()
	if MP.should_use_the_order() then
		G.GAME.current_round.mail_card.rank = "Ace"

		local count_map = {}
		local value_order = THE_ORDER.build_rank_order()
		local valid_ranks = {}

		for _, card in ipairs(G.playing_cards) do
			if card.ability.effect ~= "Stone Card" then
				local value = card.base.value
				local entry = count_map[value]
				if not entry then
					entry = { value = value, count = 0, example_card = card }
					count_map[value] = entry
					table.insert(valid_ranks, entry)
				end
				entry.count = entry.count + 1
			end
		end

		if #valid_ranks == 0 then
			return
		end

		table.sort(valid_ranks, function(left, right)
			if left.count ~= right.count then
				return left.count > right.count
			end
			return value_order[left.value] < value_order[right.value]
		end)

		local total_weight = 0
		for _, entry in ipairs(valid_ranks) do
			total_weight = total_weight + entry.count
		end

		local raw_random = pseudorandom("mail" .. G.GAME.round_resets.ante)
		local threshold = 0
		for _, entry in ipairs(valid_ranks) do
			local count = entry.count
			local weight = count / total_weight
			threshold = threshold + weight
			if raw_random < threshold then
				sendDebugMessage(
					"(Mail) Selected card "
						.. entry.example_card.base.value
						.. " with weight "
						.. count
						.. " of total "
						.. total_weight
				)
				G.GAME.current_round.mail_card.rank = entry.example_card.base.value
				G.GAME.current_round.mail_card.id = entry.example_card.base.id
				break
			end
		end

		return
	end

	return original_reset_mail_rank()
end
