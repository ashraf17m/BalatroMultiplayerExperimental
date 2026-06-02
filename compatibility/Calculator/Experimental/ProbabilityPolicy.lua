-- Calculator V2 probability policy.
--
-- Exact scoring follows Balatro's real random path. Range scoring uses two
-- controlled passes: one pessimistic and one optimistic. That keeps the
-- calculator responsive while still letting the real scoring pipeline decide
-- what each forced outcome means.

MP = MP or {}
MP.CALCULATOR_V2 = MP.CALCULATOR_V2 or {}

local CALC = MP.CALCULATOR_V2

CALC.PROBABILITY_EXACT = "exact"
CALC.PROBABILITY_MIN = "min"
CALC.PROBABILITY_MAX = "max"

local function new_stats(mode)
	return {
		mode = mode,
		count = 0,
		direct_random = 0,
		random_elements = 0,
		guaranteed = 0,
		impossible = 0,
		forced_success = 0,
		forced_failure = 0,
	}
end

local function safe_compare(fn)
	local ok, result = pcall(fn)
	return ok and result or false
end

local function is_zero_or_less(value)
	return safe_compare(function() return value <= 0 end)
end

local function is_denominator_invalid(value)
	return value == nil or safe_compare(function() return value <= 0 end)
end

local function is_guaranteed(numerator, denominator)
	if is_denominator_invalid(denominator) or is_zero_or_less(numerator) then return false end
	return safe_compare(function() return numerator >= denominator end)
end

local function is_impossible(numerator, denominator)
	return is_denominator_invalid(denominator) or is_zero_or_less(numerator)
end

local function probability_vars(get_probability_vars, trigger_obj, seed, base_numerator, base_denominator, identifier, no_mod)
	if type(get_probability_vars) == "function" then
		local ok, numerator, denominator = pcall(
			get_probability_vars,
			trigger_obj,
			base_numerator,
			base_denominator,
			identifier or seed,
			true,
			no_mod
		)
		if ok then return numerator, denominator end
	end
	return base_numerator, base_denominator
end

local function append_post_probability(result, trigger_obj, seed, numerator, denominator, identifier)
	if not SMODS then return end
	SMODS.post_prob = SMODS.post_prob or {}
	SMODS.post_prob[#SMODS.post_prob + 1] = {
		pseudorandom_result = true,
		result = result,
		trigger_obj = trigger_obj,
		numerator = numerator,
		denominator = denominator,
		identifier = identifier or seed,
	}
end

local function sorted_random_keys(source)
	local keys = {}
	for key, value in pairs(source or {}) do keys[#keys + 1] = { k = key, v = value } end

	if keys[1] and type(keys[1].v) == "table" and keys[1].v.sort_id then
		table.sort(keys, function(a, b) return a.v.sort_id < b.v.sort_id end)
	else
		table.sort(keys, function(a, b)
			local ok, result = pcall(function() return a.k < b.k end)
			if ok then return result end
			return tostring(a.k) < tostring(b.k)
		end)
	end

	return keys
end

local function probability_result(
	mode,
	stats,
	original_pseudorandom,
	get_probability_vars,
	trigger_obj,
	seed,
	base_numerator,
	base_denominator,
	identifier,
	no_mod
)
	local numerator, denominator = probability_vars(get_probability_vars, trigger_obj, seed, base_numerator, base_denominator, identifier, no_mod)

	local result
	if mode == CALC.PROBABILITY_EXACT then
		stats.count = stats.count + 1
		local random_roll = type(original_pseudorandom) == "function" and original_pseudorandom(seed) or pseudorandom(seed)
		result = random_roll < numerator / denominator
	elseif mode == CALC.PROBABILITY_MIN then
		stats.count = stats.count + 1
		result = is_guaranteed(numerator, denominator)
		if result then
			stats.guaranteed = stats.guaranteed + 1
		else
			stats.forced_failure = stats.forced_failure + 1
		end
	elseif mode == CALC.PROBABILITY_MAX then
		stats.count = stats.count + 1
		result = not is_impossible(numerator, denominator)
		if result then
			stats.forced_success = stats.forced_success + 1
		else
			stats.impossible = stats.impossible + 1
		end
	else
		return nil
	end

	append_post_probability(result, trigger_obj, seed, numerator, denominator, identifier)
	return result
end

local function forced_probability_vars(mode, stats, numerator, denominator)
	stats.count = stats.count + 1
	if mode == CALC.PROBABILITY_MIN then
		return is_guaranteed(numerator, denominator) and numerator or 0, denominator
	end
	if mode == CALC.PROBABILITY_MAX then
		if is_impossible(numerator, denominator) then return numerator, denominator end
		return denominator, denominator
	end
	return numerator, denominator
end

local function install_smods_policy(mode, stats, original_pseudorandom)
	if not SMODS then return nil, nil end

	local original_probability = SMODS.pseudorandom_probability
	local original_get_probability_vars = SMODS.get_probability_vars

	if type(original_get_probability_vars) == "function" then
		SMODS.get_probability_vars = function(trigger_obj, base_numerator, base_denominator, identifier, from_roll, no_mod)
			local numerator, denominator = original_get_probability_vars(
				trigger_obj,
				base_numerator,
				base_denominator,
				identifier,
				from_roll,
				no_mod
			)
			if from_roll then
				return forced_probability_vars(mode, stats, numerator, denominator)
			end
			return numerator, denominator
		end
	end

	if type(original_probability) == "function" then
		SMODS.pseudorandom_probability = function(trigger_obj, seed, base_numerator, base_denominator, identifier, no_mod)
			return probability_result(
				mode,
				stats,
				original_pseudorandom,
				original_get_probability_vars,
				trigger_obj,
				seed,
				base_numerator,
				base_denominator,
				identifier,
				no_mod
			)
		end
	end

	return original_probability, original_get_probability_vars
end

local function install_random_policy(mode, stats)
	local original_pseudorandom = pseudorandom
	local original_pseudorandom_element = pseudorandom_element

	if type(original_pseudorandom) == "function" then
		pseudorandom = function(seed, min, max)
			if seed == nil then return original_pseudorandom(seed, min, max) end

			stats.direct_random = stats.direct_random + 1

			if mode == CALC.PROBABILITY_EXACT then
				stats.count = stats.count + 1
				return original_pseudorandom(seed, min, max)
			end

			stats.count = stats.count + 1
			if mode == CALC.PROBABILITY_MIN then
				if min ~= nil and max ~= nil then return max end
				return 0.999999999999
			end
			if mode == CALC.PROBABILITY_MAX then
				if min ~= nil and max ~= nil then return min end
				return 0
			end

			return original_pseudorandom(seed, min, max)
		end
	end

	if type(original_pseudorandom_element) == "function" then
		pseudorandom_element = function(source, seed)
			if seed == nil then return original_pseudorandom_element(source, seed) end

			stats.random_elements = stats.random_elements + 1

			if mode == CALC.PROBABILITY_EXACT then
				stats.count = stats.count + 1
				return original_pseudorandom_element(source, seed)
			end

			local options = sorted_random_keys(source)
			stats.count = stats.count + 1
			local index = mode == CALC.PROBABILITY_MIN and #options or 1
			local option = options[index]
			return option and option.v, option and option.k
		end
	end

	return original_pseudorandom, original_pseudorandom_element
end

function CALC.with_probability_policy(mode, fn)
	mode = mode or CALC.PROBABILITY_EXACT
	local stats = new_stats(mode)
	local previous_policy = CALC.active_probability_policy
	CALC.active_probability_policy = mode

	local original_pseudorandom, original_pseudorandom_element = install_random_policy(mode, stats)
	local original_probability, original_get_probability_vars =
		install_smods_policy(mode, stats, original_pseudorandom)

	local ok, result, reason = pcall(fn)

	if SMODS then
		SMODS.pseudorandom_probability = original_probability
		SMODS.get_probability_vars = original_get_probability_vars
	end
	pseudorandom = original_pseudorandom
	pseudorandom_element = original_pseudorandom_element
	CALC.active_probability_policy = previous_policy

	if not ok then return nil, result, stats end
	return result, reason, stats
end
