-- The heart of this library: it replicates the game's score evaluation.
--
-- This file now owns only the top-level simulation orchestration and state
-- snapshot construction. Lower-level helpers and environment-specific
-- integration behavior live in the sibling EngineSimulate helper modules.

if not FN.SIM.run then
	function FN.SIM.run()
		local null_ret = { score = { min = 0, exact = 0, max = 0 }, dollars = { min = 0, exact = 0, max = 0 } }
		if #G.hand.highlighted < 1 then return null_ret end

		FN.SIM.init()

		FN.SIM.manage_state("SAVE")
		FN.SIM.update_state_variables()

		if not FN.SIM.simulate_blind_debuffs() then
			FN.SIM.simulate_scoring_pipeline()
		else
			FN.SIM.simulate_all_jokers(G.jokers, { debuffed_hand = true })
		end

		FN.SIM.manage_state("RESTORE")

		return FN.SIM.get_results()
	end

	function FN.SIM.init()
		FN.SIM.reset_running()

		local hand_name, _, poker_hands, scoring_hand, _ = G.FUNCS.get_poker_hand_info(G.hand.highlighted)
		FN.SIM.env.scoring_name = hand_name
		FN.SIM.env.poker_hands = poker_hands
		FN.SIM.env.hand_state = FN.SIM.build_hand_state()

		FN.SIM.env.played_cards = {}
		FN.SIM.env.scoring_cards = {}
		local is_splash_joker = next(find_joker("Splash"))
		table.sort(G.hand.highlighted, function(a, b)
			return a.T.x < b.T.x
		end)
		for _, card in ipairs(G.hand.highlighted) do
			local is_scoring = false
			for _, scoring_card in ipairs(scoring_hand) do
				if card.sort_id == scoring_card.sort_id or is_splash_joker or card.ability.effect == "Stone Card" then
					is_scoring = true
					break
				end
			end

			local card_data = FN.SIM.get_card_data(card)
			table.insert(FN.SIM.env.played_cards, card_data)
			if is_scoring then table.insert(FN.SIM.env.scoring_cards, card_data) end
		end

		FN.SIM.env.held_cards = {}
		for _, card in ipairs(G.hand.cards) do
			if not card.highlighted then
				local card_data = FN.SIM.get_card_data(card)
				table.insert(FN.SIM.env.held_cards, card_data)
			end
		end

		FN.SIM.env.jokers = {}
		for _, joker in ipairs(G.jokers.cards) do
			local joker_data = {
				id = joker.config.center.key:sub(3, #joker.config.center.key),
				ability = copy_table(joker.ability),
				edition = copy_table(joker.edition),
				rarity = joker.config.center.rarity,
				debuff = joker.debuff,
			}
			table.insert(FN.SIM.env.jokers, joker_data)
		end

		FN.SIM.env.consumables = {}
		for _, consumable in ipairs(G.consumeables.cards) do
			local consumable_data = {
				id = consumable.config.center.key:sub(3, #consumable.config.center.key),
				ability = copy_table(consumable.ability),
			}
			table.insert(FN.SIM.env.consumables, consumable_data)
		end

		FN.SIM.get_context = function(cardarea, args)
			local context = {
				cardarea = cardarea,
				full_hand = FN.SIM.env.played_cards,
				scoring_name = hand_name,
				scoring_hand = FN.SIM.env.scoring_cards,
				poker_hands = poker_hands,
			}

			for k, v in pairs(args) do
				context[k] = v
			end

			return context
		end
	end

	function FN.SIM.get_card_data(card_obj)
		return {
			rank = card_obj.base.id,
			suit = card_obj.base.suit,
			base_chips = card_obj.base.nominal,
			ability = copy_table(card_obj.ability),
			edition = copy_table(card_obj.edition),
			seal = card_obj.seal,
			debuff = card_obj.debuff,
			lucky_trigger = {},
		}
	end

	function FN.SIM.get_results()
		local FNSR = FN.SIM.running

		local min_score = FN.SIM.floor_value(FN.SIM.mul_values(FNSR.min.chips, FNSR.min.mult))
		local exact_score = FN.SIM.floor_value(FN.SIM.mul_values(FNSR.exact.chips, FNSR.exact.mult))
		local max_score = FN.SIM.floor_value(FN.SIM.mul_values(FNSR.max.chips, FNSR.max.mult))

		return {
			score = { min = min_score, exact = exact_score, max = max_score },
			dollars = { min = FNSR.min.dollars, exact = FNSR.exact.dollars, max = FNSR.max.dollars },
		}
	end
end
