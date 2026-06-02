-- Preview simulation behavior that mirrors blind, deck, and game-state hooks.

if FN.SIM.run and not FN.SIM.manage_state then
	function FN.SIM.manage_state(save_or_restore)
		local FNSO = FN.SIM.orig

		if save_or_restore == "SAVE" then
			FNSO.random_data = copy_table(G.GAME.pseudorandom)
			return
		end

		if save_or_restore == "RESTORE" then
			G.GAME.pseudorandom = FNSO.random_data
			return
		end
	end

	function FN.SIM.update_state_variables()
		local hand_info = FN.SIM.get_hand_state(FN.SIM.env.scoring_name)
		if not hand_info then return end
		hand_info.played = hand_info.played + 1
		hand_info.played_this_round = hand_info.played_this_round + 1
	end

	function FN.SIM.simulate_blind_effects()
		if G.GAME.blind.disabled then return end

		if G.GAME.blind.name == "The Flint" then
			local function flint(data)
				local half_chips = FN.SIM.floor_value(FN.SIM.add_values(FN.SIM.div_values(data.chips, 2), 0.5))
				local half_mult = FN.SIM.floor_value(FN.SIM.add_values(FN.SIM.div_values(data.mult, 2), 0.5))
				data.chips = FN.SIM.mod_chips(FN.SIM.max_value(half_chips, 0))
				data.mult = FN.SIM.mod_mult(FN.SIM.max_value(half_mult, 1))
			end

			flint(FN.SIM.running.min)
			flint(FN.SIM.running.exact)
			flint(FN.SIM.running.max)
		end
	end

	function FN.SIM.simulate_deck_effects()
		if FN.SIM.is_deck("b_plasma") then
			local function plasma(data)
				local sum = FN.SIM.add_values(data.chips, data.mult)
				local half_sum = FN.SIM.floor_value(FN.SIM.div_values(sum, 2))
				data.chips = FN.SIM.mod_chips(half_sum)
				data.mult = FN.SIM.mod_mult(half_sum)
			end

			plasma(FN.SIM.running.min)
			plasma(FN.SIM.running.exact)
			plasma(FN.SIM.running.max)
		elseif G.GAME.modifiers.mp_score_instability then
			local function unplasma(data)
				local diff = FN.SIM.sub_values(data.chips, data.mult)
				if FN.SIM.is_gt(diff, 0) then
					diff = FN.SIM.min_value(diff, FN.SIM.sub_values(data.mult, 1))
				elseif FN.SIM.is_lt(diff, 0) then
					diff = FN.SIM.max_value(diff, FN.SIM.mul_values(data.chips, -1))
				end
				data.chips = FN.SIM.mod_chips(FN.SIM.add_values(data.chips, diff))
				data.mult = FN.SIM.mod_mult(FN.SIM.sub_values(data.mult, diff))
			end

			unplasma(FN.SIM.running.min)
			unplasma(FN.SIM.running.exact)
			unplasma(FN.SIM.running.max)
		end
	end

	function FN.SIM.simulate_blind_debuffs()
		local blind_obj = G.GAME.blind
		if blind_obj.disabled then return false end

		if blind_obj.name == "The Hook" then
			blind_obj.triggered = true

			local held = FN.SIM.env.held_cards
			local n = #held
			local combinations = {}

			if n == 0 then
				table.insert(combinations, {})
			elseif n == 1 then
				for a = 1, n do
					table.insert(combinations, { a })
				end
			elseif n >= 2 then
				for a = 1, n - 1 do
					for b = a + 1, n do
						table.insert(combinations, { a, b })
					end
				end
			end

			local min_score, max_score = math.huge, -math.huge
			local min_dollars, max_dollars = math.huge, -math.huge

			for _, discard_idxs in ipairs(combinations) do
				local held_copy = {}
				local discarded = {}
				for i, card in ipairs(held) do
					held_copy[i] = copy_table(card)
				end

				table.sort(discard_idxs, function(a, b)
					return a > b
				end)
				for _, idx in ipairs(discard_idxs) do
					discarded[#discarded + 1] = table.remove(held_copy, idx)
				end

				local backup_held = FN.SIM.env.held_cards
				FN.SIM.env.held_cards = held_copy
				local backup_jokers = copy_table(FN.SIM.env.jokers)

				FN.SIM.reset_running()

				for i = 1, #discarded do
					FN.SIM.simulate_joker_discard_effects(discarded, discarded[i])
				end

				FN.SIM.simulate_scoring_pipeline()

				local res = FN.SIM.get_results()
				min_score = FN.SIM.min_value(min_score, res.score.min)
				max_score = FN.SIM.max_value(max_score, res.score.max)
				min_dollars = math.min(min_dollars, res.dollars.min)
				max_dollars = math.max(max_dollars, res.dollars.max)

				FN.SIM.env.held_cards = backup_held
				FN.SIM.env.jokers = backup_jokers
			end

			FN.SIM.running.min = { chips = FN.SIM.to_score_number(min_score), mult = FN.SIM.one(), dollars = min_dollars }
			FN.SIM.running.max = { chips = FN.SIM.to_score_number(max_score), mult = FN.SIM.one(), dollars = max_dollars }
			return true
		end

		if blind_obj.name == "The Tooth" then
			blind_obj.triggered = true
			FN.SIM.add_dollars(-1 * #FN.SIM.env.played_cards)
		end

		if blind_obj.name == "The Arm" then
			blind_obj.triggered = false

			local played_hand_name = FN.SIM.env.scoring_name
			local played_hand_data = FN.SIM.get_hand_state(played_hand_name)
			if played_hand_data and FN.SIM.is_gt(played_hand_data.level, 1) then
				blind_obj.triggered = true
				played_hand_data.level = FN.SIM.max_value(1, FN.SIM.sub_values(played_hand_data.level, 1))
				FN.SIM.recalculate_hand_base(played_hand_data)
			end
			return false
		end

		if blind_obj.name == "The Ox" then
			blind_obj.triggered = false

			if FN.SIM.env.scoring_name == G.GAME.current_round.most_played_poker_hand then
				blind_obj.triggered = true
				FN.SIM.add_dollars(-G.GAME.dollars)
			end
			return false
		end

		return blind_obj:debuff_hand(G.hand.highlighted, FN.SIM.env.poker_hands, FN.SIM.env.scoring_name, true)
	end
end
