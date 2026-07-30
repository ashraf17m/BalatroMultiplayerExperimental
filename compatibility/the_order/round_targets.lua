local THE_ORDER = MP.COMPAT.THE_ORDER

local original_reset_idol_card = reset_idol_card
function reset_idol_card()
	if MP.should_use_the_order() then
		G.GAME.current_round.idol_card.rank = "Ace"
		G.GAME.current_round.idol_card.suit = "Spades"

		local function is_wild(card)
			return card.ability and card.ability.effect == "Wild Card"
		end

		local function edition_weight(card)
			local edition = card.edition
			if not edition then
				return 0.0
			end
			if edition.polychrome then
				return 1.05
			end
			if edition.glass then
				return 0.95
			end
			if edition.holo then
				return 0.50
			end
			if edition.foil then
				return 0.15
			end
			return 0.0
		end

		local function enhancement_weight(card)
			local effect = card.ability and card.ability.effect
			if effect == "Glass Card" then
				return 0.95
			end
			if effect == "Lucky Card" then
				return 0.45
			end
			if effect == "Steel Card" then
				return 0.15
			end
			if effect == "Wild Card" then
				return 0.15
			end
			if effect == "Bonus Card" then
				return 0.10
			end
			if effect == "Mult Card" then
				return 0.10
			end
			if effect == "Gold Card" then
				return 0.05
			end
			return 0.0
		end

		local function seal_weight(card)
			local seal = card.seal
			if seal == "Red" then
				return 1.2
			end
			if seal == "Purple" then
				return 0.15
			end
			if seal == "Gold" then
				return 0.30
			end
			if seal == "Blue" then
				return 0.05
			end
			return 0.0
		end

		local count_map = {}
		local valid_idol_cards = {}

		for _, card in ipairs(G.playing_cards) do
			if card.ability.effect ~= "Stone Card" then
				local key = card.base.value .. "_" .. card.base.suit
				if not count_map[key] then
					count_map[key] = {
						count = 0,
						card = card,
						value = card.base.value,
						suit = card.base.suit,
						cards = {},
						wild_count = 0,
					}
					table.insert(valid_idol_cards, count_map[key])
				end
				local entry = count_map[key]
				entry.count = entry.count + 1
				table.insert(entry.cards, card)
				if is_wild(card) then
					entry.wild_count = entry.wild_count + 1
				end
			end
		end

		if #valid_idol_cards == 0 then
			return
		end

		local rank_buffer = MP.PLATFORM.SMODS.get_rank_buffer()
		local rank_index = THE_ORDER.build_rank_order()
		local suit_index = THE_ORDER.build_suit_order()
		local rank_totals = {}
		local wild_by_rank = {}
		local distinct_ranks_set = {}

		for _, entry in ipairs(valid_idol_cards) do
			local rank = entry.value
			rank_totals[rank] = (rank_totals[rank] or 0) + entry.count
			wild_by_rank[rank] = (wild_by_rank[rank] or 0) + entry.wild_count
			distinct_ranks_set[rank] = true
		end

		local distinct_ranks = 0
		for _ in pairs(distinct_ranks_set) do
			distinct_ranks = distinct_ranks + 1
		end

		local total_cards = 0
		for _, entry in ipairs(valid_idol_cards) do
			total_cards = total_cards + entry.count
		end

		local raw_mean_by_number = total_cards / distinct_ranks
		local face_pool = 0
		local low_pool = 0
		local face_ranks_present = 0
		local low_ranks_present = 0

		for rank, total in pairs(rank_totals) do
			local rank_obj = SMODS and SMODS.Ranks and SMODS.Ranks[rank]
			if rank_obj then
				if rank_obj.face then
					face_pool = face_pool + total
					face_ranks_present = face_ranks_present + 1
				elseif rank_obj.nominal and rank_obj.nominal >= 2 and rank_obj.nominal <= 5 then
					low_pool = low_pool + total
					low_ranks_present = low_ranks_present + 1
				end
			end
		end

		local function round_to_nearest_05(value)
			return math.floor(value * 20 + 0.5) / 20
		end

		local face_baseline = round_to_nearest_05(raw_mean_by_number * face_ranks_present)
		local low_baseline = round_to_nearest_05(raw_mean_by_number * low_ranks_present)
		local weight_general = 0.05

		local function face_score_for_rank(rank)
			local rank_obj = SMODS and SMODS.Ranks and SMODS.Ranks[rank]
			if rank_obj and rank_obj.face then
				return math.max(0.0, weight_general * 1.1 * math.max(0.0, face_pool - face_baseline))
			end
			return 0.0
		end

		local function low_score_for_rank(rank)
			local rank_obj = SMODS and SMODS.Ranks and SMODS.Ranks[rank]
			if rank_obj and rank_obj.nominal and rank_obj.nominal >= 2 and rank_obj.nominal <= 5 then
				return math.max(0.0, weight_general * math.max(0.0, low_pool - low_baseline))
			end
			return 0.0
		end

		local function previous_rank_key(rank)
			local index = rank_index[rank]
			if not index then
				return nil
			end
			if index == 1 then
				return rank_buffer[#rank_buffer]
			end
			return rank_buffer[index - 1]
		end

		local target_copies = 5
		local weight_edition_a = 1.3
		local weight_edition_b = 0.7
		local weight_count_a = 0.5
		local weight_main = 2.0
		local weight_off = 1.0
		local weight_strength = 1.0

		for _, entry in ipairs(valid_idol_cards) do
			local rank = entry.value
			local suit = entry.suit
			local own_count = entry.count
			local wild_elsewhere = (wild_by_rank[rank] or 0) - entry.wild_count
			local effective_count = own_count + wild_elsewhere
			local face_score = face_score_for_rank(rank)
			local low_score = low_score_for_rank(rank)
			local seal_score = 0.0
			local edition_score = 0.0

			for _, card in ipairs(entry.cards) do
				seal_score = seal_score + seal_weight(card)
				edition_score = edition_score + edition_weight(card) + enhancement_weight(card)
			end

			if effective_count >= target_copies then
				entry.tier = 1
				entry.total_score = (weight_count_a * effective_count)
					+ face_score
					+ low_score
					+ ((seal_score + edition_score) * weight_edition_a)
			else
				entry.tier = 0
				local needed = target_copies - effective_count
				local main_hit = weight_main * effective_count
				local convertible_pool = (rank_totals[rank] or 0) - own_count - wild_elsewhere
				local off_hit = weight_off * math.min(3, math.max(0.0, convertible_pool), needed)
				local previous_rank = previous_rank_key(rank)
				local neighbor_count = 0

				if previous_rank then
					local neighbor_key = previous_rank .. "_" .. suit
					local neighbor_entry = count_map[neighbor_key]
					local physical_same_suit = neighbor_entry and neighbor_entry.count or 0
					local neighbor_wild_same_suit = neighbor_entry and neighbor_entry.wild_count or 0
					local previous_wild_total = wild_by_rank[previous_rank] or 0
					local previous_wild_elsewhere = previous_wild_total - neighbor_wild_same_suit
					neighbor_count = physical_same_suit + previous_wild_elsewhere
				end

				local strength_adj = weight_strength * math.min(2, neighbor_count, needed)
				entry.total_score = main_hit
					+ off_hit
					+ strength_adj
					+ face_score
					+ low_score
					+ ((seal_score + edition_score) * weight_edition_b)
			end
		end

		table.sort(valid_idol_cards, function(left, right)
			if left.tier ~= right.tier then
				return left.tier > right.tier
			end
			if left.total_score ~= right.total_score then
				return left.total_score > right.total_score
			end
			if (rank_index[left.value] or 0) ~= (rank_index[right.value] or 0) then
				return (rank_index[left.value] or 0) > (rank_index[right.value] or 0)
			end
			if suit_index[left.suit] ~= suit_index[right.suit] then
				return suit_index[left.suit] > suit_index[right.suit]
			end
			return (rank_index[left.value] or 0) < (rank_index[right.value] or 0)
		end)

		local total_weight = 0
		for _, entry in ipairs(valid_idol_cards) do
			total_weight = total_weight + entry.count
		end

		if total_weight <= 0 then
			return
		end

		local raw_random = pseudorandom("idol" .. G.GAME.round_resets.ante)
		local threshold = 0
		for _, entry in ipairs(valid_idol_cards) do
			threshold = threshold + (entry.count / total_weight)
			if raw_random < threshold then
				local idol_card = entry.card
				sendDebugMessage(
					string.format(
						"Selected %s of %s, with a count of %d",
						idol_card.base.value,
						idol_card.base.suit,
						entry.count
					),
					"IdolAlgo"
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
