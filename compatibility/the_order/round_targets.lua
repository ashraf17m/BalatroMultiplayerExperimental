local THE_ORDER = MP.COMPAT.THE_ORDER

-- Patches idol RNG when using the order to sort deck based on count of identical cards instead of default deck order
local original_reset_idol_card = reset_idol_card
function reset_idol_card()
	if MP.should_use_the_order() then


		G.GAME.current_round.idol_card.rank = "Ace"
		G.GAME.current_round.idol_card.suit = "Spades"

		-- ----------------------------------------------------------------
		-- Step 1: Build count_map keyed by (value, suit)
		-- ----------------------------------------------------------------
		local count_map = {}
		local valid_idol_cards = {}

		for _, v in ipairs(G.playing_cards) do
			if v.ability.effect ~= "Stone Card" then
				local key = v.base.value .. "_" .. v.base.suit
				if not count_map[key] then
					count_map[key] = {
						count = 0,
						card  = v,
						value = v.base.value,
						suit  = v.base.suit,
					}
					table.insert(valid_idol_cards, count_map[key])
				end
				count_map[key].count = count_map[key].count + 1
			end
		end

		if #valid_idol_cards == 0 then return end

		-- ----------------------------------------------------------------
		-- Step 2: Build rank ordering from SMODS (positional index)
		-- ----------------------------------------------------------------
		local rank_index = {}
		for i, rank_key in ipairs(SMODS.Rank.obj_buffer) do
			rank_index[rank_key] = i
		end

		local suit_index = {}
		for i, suit_key in ipairs(SMODS.Suit.obj_buffer) do
			suit_index[suit_key] = i
		end

		-- ----------------------------------------------------------------
		-- Step 3: Aggregate per-rank totals (only ranks present in deck)
		-- ----------------------------------------------------------------
		local rank_totals = {}        -- rank_key -> total count across all suits
		local distinct_cards = 0      -- number of distinct (rank, suit) entries

		for _, entry in ipairs(valid_idol_cards) do
			local r = entry.value
			rank_totals[r] = (rank_totals[r] or 0) + entry.count
			distinct_cards  = distinct_cards + 1
		end

		-- Count of distinct ranks present
		local distinct_ranks = 0
		for _ in pairs(rank_totals) do
			distinct_ranks = distinct_ranks + 1
		end

		local total_cards = 0
		for _, entry in ipairs(valid_idol_cards) do
			total_cards = total_cards + entry.count
		end

		-- ----------------------------------------------------------------
		-- Step 4: Compute means, rounded to nearest 0.5
		-- (Python: round(x * 2) / 2 — Lua's math.floor with +0.5 trick)
		-- ----------------------------------------------------------------
		local function round_to_half(x)
			return math.floor(x * 2 + 0.5) / 2
		end

		local function round_to_nearest_05(x)
			return math.floor(x * 20 + 0.5) / 20
		end

		local mean_by_card   = round_to_half(total_cards / distinct_cards)
		local mean_by_number = round_to_half(total_cards / distinct_ranks)
		local raw_mean_by_number = total_cards / distinct_ranks

		-- ----------------------------------------------------------------
		-- Step 5: Face / low pools and baselines for Generalized score
		--         Face = ranks with .face == true in SMODS
		--         Low  = ranks with nominal <= 5 and nominal >= 2
		--                (covers 2,3,4,5 in vanilla; adapts to mods)
		-- ----------------------------------------------------------------
		local face_pool = 0
		local low_pool  = 0
		local face_ranks_present = 0
		local low_ranks_present  = 0

		for rank_key, total in pairs(rank_totals) do
			local rank_obj = SMODS.Ranks[rank_key]
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

		local face_baseline = round_to_nearest_05(raw_mean_by_number * face_ranks_present)
		local low_baseline  = round_to_nearest_05(raw_mean_by_number * low_ranks_present)

		local W_GEN    = 0.05
		local GEN_FLOOR = 0.01

		-- ----------------------------------------------------------------
		-- Step 6: Off Hit per rank (scaled by 0.5)
		-- ----------------------------------------------------------------
		local off_hit_by_rank = {}
		for rank_key, total in pairs(rank_totals) do
			off_hit_by_rank[rank_key] = 0.5 * math.max(0.0, total - mean_by_number)
		end

		-- ----------------------------------------------------------------
		-- Step 7: Previous rank (positional wrap: index 1 -> last index)
		--         In vanilla obj_buffer: Ace(1) wraps to 2(last), giving
		--         the Ace -> King adjacency the Python script intends.
		-- ----------------------------------------------------------------
		local function previous_rank_key(rank_key)
			local idx = rank_index[rank_key]
			if not idx then return nil end
			if idx == 1 then
				-- wrap to last rank in buffer
				return SMODS.Rank.obj_buffer[#SMODS.Rank.obj_buffer]
			else
				return SMODS.Rank.obj_buffer[idx - 1]
			end
		end

		-- ----------------------------------------------------------------
		-- Step 8: Generalized score per rank key
		-- ----------------------------------------------------------------
		local function generalized_for_rank(rank_key)
			local rank_obj = SMODS.Ranks[rank_key]
			if not rank_obj then return 0.0 end
			if rank_obj.face then
				return math.max(GEN_FLOOR, W_GEN * 1.1 * math.max(0.0, (face_pool - face_baseline)))
			elseif rank_obj.nominal and rank_obj.nominal >= 2 and rank_obj.nominal <= 5 then
				return math.max(GEN_FLOOR, W_GEN * math.max(0.0, low_pool - low_baseline))
			end
			return 0.0
		end

		-- ----------------------------------------------------------------
		-- Step 9: Compute total score for each distinct (rank, suit) entry
		-- ----------------------------------------------------------------
		for _, entry in ipairs(valid_idol_cards) do
			local rank_key = entry.value
			local suit_key = entry.suit
			local card_count = entry.count

			-- Main Hit: 2 * max(0, card_count - mean_by_card)
			local main_hit = 2.0 * math.max(0.0, card_count - mean_by_card)

			-- Off Hit: 0.5 * max(0, rank_total - mean_by_number)
			local off_hit = off_hit_by_rank[rank_key] or 0.0

			-- Rank Adjacent: 0.25 * off_hit of the previous rank
			local prev_rank = previous_rank_key(rank_key)
			local rank_adj = 0.25 * (off_hit_by_rank[prev_rank] or 0.0)

			-- Suit-Matched Adjacent: 0.33 * max(0, neighbor_count - mean_by_card)
			-- neighbor = the previous rank of the same suit
			local neighbor_count = 0
			if prev_rank then
				local neighbor_key = prev_rank .. "_" .. suit_key
				if count_map[neighbor_key] then
					neighbor_count = count_map[neighbor_key].count
				end
			end
			local suit_matched_adj = 0.33 * math.max(0.0, neighbor_count - mean_by_card)

			-- Generalized
			local generalized = generalized_for_rank(rank_key)

			entry.total_score = main_hit + off_hit + suit_matched_adj + rank_adj + generalized

			--[[sendDebugMessage(
				string.format(
					"(Idol) Score for %s of %s: total=%.4f (main=%.4f off=%.4f suit_adj=%.4f rank_adj=%.4f gen=%.4f)",
					rank_key, suit_key,
					entry.total_score, main_hit, off_hit, suit_matched_adj, rank_adj, generalized
				)
			)]]
		end

		-- ----------------------------------------------------------------
		-- Step 10: Sort by score, then weighted random selection by count
		-- ----------------------------------------------------------------
		table.sort(valid_idol_cards, function(a, b)
			return a.total_score > b.total_score
			--[[if a.total_score ~= b.total_score then return a.total_score > b.total_score end
			if suit_index[a.suit] ~= suit_index[b.suit] then return suit_index[a.suit] < suit_index[b.suit] end
			return (rank_index[a.value] or 0) < (rank_index[b.value] or 0)]]
		end)

		local total_weight = 0
		for _, entry in ipairs(valid_idol_cards) do
			total_weight = total_weight + entry.count
		end

		if total_weight <= 0 then return end

		local raw_random = pseudorandom("idol" .. G.GAME.round_resets.ante)

		local threshold = 0
		for _, entry in ipairs(valid_idol_cards) do
			threshold = threshold + (entry.count / total_weight)
			if raw_random < threshold then
				local idol_card = entry.card
				sendDebugMessage(
					string.format(
						"(Idol) Selected %s of %s, with a count of %d", ----(score=%.4f,]] count=%d, total_weight=%d)
						idol_card.base.value, idol_card.base.suit, entry.count--,
						--entry.total_score, entry.count, total_weight
					)
				)
				G.GAME.current_round.ijdol_card.rank = idol_card.base.value
				G.GAME.current_round.idol_card.suit = idol_card.base.suit
				G.GAME.current_round.idol_card.id   = idol_card.base.id
				-- Fire the reel animation (async, won't block the game)
				if MP.DO_IDOL_REEL == true then animate_idol_reel(valid_idol_cards, entry) end
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
