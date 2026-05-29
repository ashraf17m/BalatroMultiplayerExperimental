MP = MP or {}
MP.CALCULATOR_V2 = MP.CALCULATOR_V2 or {}

local CALC = MP.CALCULATOR_V2

local function safe_call(fn, ...)
	if type(fn) ~= "function" then return nil, "missing function" end
	local ok, result = pcall(fn, ...)
	if ok then return result end
	return nil, result
end

function CALC.to_score_number(value)
	if value == nil then return 0 end
	if type(to_big) == "function" and (type(value) == "number" or type(value) == "table") then
		local converted = safe_call(to_big, value)
		if converted ~= nil then return converted end
	end
	if type(value) == "number" or type(value) == "table" then return value end
	local parsed = tonumber(value)
	if parsed ~= nil then return parsed end
	if MP.INSANE_INT and MP.INSANE_INT.from_string then
		local parsed_big = safe_call(MP.INSANE_INT.from_string, tostring(value))
		if parsed_big ~= nil then return parsed_big end
	end
	return value
end

function CALC.zero_score()
	if MP.INSANE_INT and MP.INSANE_INT.from_string then
		local parsed = safe_call(MP.INSANE_INT.from_string, "0")
		if parsed ~= nil then return parsed end
	end
	return 0
end

function CALC.add_values(left, right)
	left = CALC.to_score_number(left)
	right = CALC.to_score_number(right)
	local result = safe_call(function() return left + right end)
	return result ~= nil and result or CALC.zero_score()
end

function CALC.sub_values(left, right)
	left = CALC.to_score_number(left)
	right = CALC.to_score_number(right)
	local result = safe_call(function() return left - right end)
	return result ~= nil and result or CALC.zero_score()
end

function CALC.mul_values(left, right)
	left = CALC.to_score_number(left)
	right = CALC.to_score_number(right)
	local result = safe_call(function() return left * right end)
	return result ~= nil and result or CALC.zero_score()
end

function CALC.floor_value(value)
	value = CALC.to_score_number(value)
	local floored = safe_call(math.floor, value)
	return floored ~= nil and floored or value
end

function CALC.values_equal(left, right)
	left = CALC.to_score_number(left)
	right = CALC.to_score_number(right)

	local ok, equal = pcall(function() return left == right end)
	if ok then return equal end
	return tostring(left) == tostring(right)
end

function CALC.mod_chips_value(value)
	if type(mod_chips) == "function" then
		local modified = safe_call(mod_chips, value)
		if modified ~= nil then return modified end
	end
	return CALC.to_score_number(value)
end

function CALC.mod_mult_value(value)
	if type(mod_mult) == "function" then
		local modified = safe_call(mod_mult, value)
		if modified ~= nil then return modified end
	end
	return CALC.to_score_number(value)
end

function CALC.exact_result(score, dollars)
	local exact = CALC.floor_value(score)
	local exact_dollars = dollars ~= nil and dollars or 0
	return CALC.range_result(exact, exact, exact, exact_dollars, exact_dollars, exact_dollars, nil)
end

function CALC.range_result(min_score, exact_score, max_score, min_dollars, exact_dollars, max_dollars, probability_events)
	local min = CALC.floor_value(min_score)
	local exact = CALC.floor_value(exact_score)
	local max = CALC.floor_value(max_score)
	local dollars_min = min_dollars ~= nil and min_dollars or 0
	local dollars_exact = exact_dollars ~= nil and exact_dollars or dollars_min
	local dollars_max = max_dollars ~= nil and max_dollars or dollars_exact

	return {
		score = {
			min = min,
			exact = exact,
			max = max,
		},
		dollars = {
			min = dollars_min,
			exact = dollars_exact,
			max = dollars_max,
		},
		probabilities = probability_events and probability_events.count and probability_events.count > 0
			and "controlled_random_range"
			or "exact_only",
		probability_events = probability_events,
	}
end

function CALC.unknown_result(reason)
	return {
		score = {
			min = nil,
			exact = nil,
			max = nil,
		},
		dollars = {
			min = 0,
			exact = 0,
			max = 0,
		},
		unsupported = true,
		reason = reason or "unsupported scoring state",
	}
end
