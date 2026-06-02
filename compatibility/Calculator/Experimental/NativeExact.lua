-- Calculator V2 native exact backend.
--
-- The backend intentionally uses Balatro's real evaluate_play path inside
-- CALC.with_state_guard. That keeps V2 aligned with SMODS, Lovely patches, and
-- modded scoring hooks instead of maintaining a fragile scoring copy.

MP = MP or {}
MP.CALCULATOR_V2 = MP.CALCULATOR_V2 or {}

local CALC = MP.CALCULATOR_V2

local function fail(reason)
	return nil, reason
end

local function is_run_ready()
	return G
		and G.GAME
		and G.GAME.hands
		and G.play
		and G.hand
		and G.FUNCS
		and type(G.FUNCS.evaluate_play) == "function"
		and G.STATE
		and G.STATES
		and (G.STATE == G.STATES.SELECTING_HAND or G.STATE == G.STATES.DRAW_TO_HAND or G.STATE == G.STATES.PLAY_TAROT)
		and not G.SCORING_COROUTINE
end

local function call_or_fail(label, fn, ...)
	if type(fn) ~= "function" then return fail(label .. " is missing") end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return fail(label .. " failed: " .. tostring(a))
end

local function calculate_current_round_score()
	if SMODS and type(SMODS.calculate_round_score) == "function" then
		local score, err = call_or_fail("SMODS.calculate_round_score", SMODS.calculate_round_score)
		if score ~= nil then
			return score
		end
		return fail(err)
	end

	if _G.hand_chips ~= nil and _G.mult ~= nil then
		local score = CALC.mul_values(_G.hand_chips, _G.mult)
		return score
	end

	return fail("no round-score function is available")
end

local function run_real_evaluate_play(ctx)
	if not is_run_ready() then
		return fail("game is not in a playable run state")
	end
	if not ctx.full_hand or #ctx.full_hand == 0 then
		return CALC.exact_result(0, 0)
	end

	local starting_chips = CALC.to_score_number(G.GAME.chips or 0)
	if type(CALC.run_pre_score_effects) == "function" then
		local pre_score_ok, pre_score_err = CALC.run_pre_score_effects(ctx)
		if not pre_score_ok then
			return fail(pre_score_err or "blind pre-play failed")
		end
	end

	local _, evaluate_err = call_or_fail("G.FUNCS.evaluate_play dry run", G.FUNCS.evaluate_play)
	if evaluate_err then
		return fail(evaluate_err)
	end
	if type(CALC.finish_dry_scoring_coroutine) == "function" then
		local scoring_done, scoring_err = CALC.finish_dry_scoring_coroutine()
		if not scoring_done then
			return fail("scoring coroutine failed: " .. tostring(scoring_err))
		end
	end

	local score, score_err = calculate_current_round_score()
	if score == nil then
		return fail(score_err)
	end

	local direct_score_delta = CALC.sub_values(G.GAME.chips or 0, starting_chips)
	if tostring(direct_score_delta) ~= "0" then
		score = CALC.add_values(score, direct_score_delta)
	end

	return CALC.exact_result(score, 0)
end

local function run_inside_guard(ctx, probability_mode)
	if type(CALC.with_state_guard) ~= "function" then
		return fail("state guard is not loaded")
	end
	if type(CALC.with_probability_policy) ~= "function" then
		local result, reason = CALC.with_state_guard(ctx, run_real_evaluate_play)
		return result, reason, { mode = probability_mode or "exact", count = 0 }
	end
	return CALC.with_probability_policy(probability_mode or CALC.PROBABILITY_EXACT, function()
		return CALC.with_state_guard(ctx, run_real_evaluate_play)
	end)
end

local function score_from_result(result)
	return result and result.score and (result.score.exact or result.score.min)
end

local function dollars_from_result(result)
	return result and result.dollars and (result.dollars.exact or result.dollars.min) or 0
end

local function combined_probability_stats(exact_stats, min_stats, max_stats)
	return {
		count = exact_stats and exact_stats.count or 0,
		exact = exact_stats,
		min = min_stats,
		max = max_stats,
	}
end

local function score_less(left, right)
	if left == nil then return right ~= nil end
	if right == nil then return false end

	local left_score = CALC.to_score_number(left)
	local right_score = CALC.to_score_number(right)
	local ok, result = pcall(function() return left_score < right_score end)
	if ok then return result end
	return tostring(left_score) < tostring(right_score)
end

local function better_result(current, candidate, want_max)
	if not candidate then return current end
	if not current then return candidate end

	local current_score = score_from_result(current)
	local candidate_score = score_from_result(candidate)
	if want_max then
		return score_less(current_score, candidate_score) and candidate or current
	end
	return score_less(candidate_score, current_score) and candidate or current
end

local function range_from_passes(exact_result, min_result, max_result, exact_stats, min_stats, max_stats)
	local low_result = better_result(better_result(min_result, exact_result, false), max_result, false)
	local high_result = better_result(better_result(min_result, exact_result, true), max_result, true)
	local events = combined_probability_stats(exact_stats, min_stats, max_stats)

	return CALC.range_result(
		score_from_result(low_result),
		score_from_result(exact_result),
		score_from_result(high_result),
		dollars_from_result(low_result),
		dollars_from_result(exact_result),
		dollars_from_result(high_result),
		events
	)
end

local function finish_async(callback, result, reason)
	CALC.calculation_text = nil
	callback(result, reason)
end

function CALC.run_native_exact_async(callback)
	if type(callback) ~= "function" then
		return false
	end
	if not (G and G.E_MANAGER and type(G.E_MANAGER.add_event) == "function" and Event) then
		finish_async(callback, CALC.unknown_result("event manager is not available"))
		return true
	end

	if type(CALC.build_context) ~= "function" then
		finish_async(callback, CALC.unknown_result("context builder is not loaded"))
		return true
	end

	local ctx, context_err = CALC.build_context()
	if not ctx then
		finish_async(callback, CALC.unknown_result(context_err))
		return true
	end
	if ctx.empty then
		finish_async(callback, CALC.exact_result(0, 0))
		return true
	end

	local state = {
		ctx = ctx,
		phase = "exact",
		exact_result = nil,
		exact_stats = nil,
		min_result = nil,
		min_stats = nil,
	}

	if not CALC.calculation_text then
		if type(CALC.set_calculation_wait_text) == "function" then
			CALC.set_calculation_wait_text()
		else
			CALC.calculation_text = "CALCULATING"
		end
	end
	if type(CALC.refresh_display) == "function" then CALC.refresh_display() end

	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = (G.E_MANAGER and G.E_MANAGER.queue_dt) or 1 / 60,
		blockable = false,
		blocking = false,
		func = function()
			if state.phase == "exact" then
				local exact_result, reason, exact_stats = run_inside_guard(state.ctx, CALC.PROBABILITY_EXACT)
				if not exact_result then
					finish_async(callback, CALC.unknown_result(reason))
					return true
				end
				if not exact_stats or (exact_stats.count or 0) == 0 then
					finish_async(callback, exact_result)
					return true
				end

				state.exact_result = exact_result
				state.exact_stats = exact_stats
				state.phase = "min"
				return false
			end

			if state.phase == "min" then
				local min_result, reason, min_stats = run_inside_guard(state.ctx, CALC.PROBABILITY_MIN)
				if not min_result then
					finish_async(callback, CALC.unknown_result(reason))
					return true
				end

				state.min_result = min_result
				state.min_stats = min_stats
				state.phase = "max"
				return false
			end

			local max_result, reason, max_stats = run_inside_guard(state.ctx, CALC.PROBABILITY_MAX)
			if not max_result then
				finish_async(callback, CALC.unknown_result(reason))
				return true
			end

			finish_async(
				callback,
				range_from_passes(state.exact_result, state.min_result, max_result, state.exact_stats, state.min_stats, max_stats)
			)
			return true
		end,
	}))
	return true
end
