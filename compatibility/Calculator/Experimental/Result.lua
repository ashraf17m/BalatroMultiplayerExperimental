MP = MP or {}
MP.CALCULATOR_V2 = MP.CALCULATOR_V2 or {}

local CALC = MP.CALCULATOR_V2

local function safe_call(fn, ...)
	if type(fn) ~= "function" then return nil, "missing function" end
	local ok, result = pcall(fn, ...)
	if ok then return result end
	return nil, result
end

local function is_big_score(value)
	if type(is_big) == "function" then
		local ok, result = pcall(is_big, value)
		if ok and result then return true end
	end
	if Big and type(Big.is) == "function" then
		local ok, result = pcall(Big.is, value)
		if ok and result then return true end
	end
	return false
end

local function parse_score_string(value)
	local text = tostring(value or "")
	local compact = text:gsub(",", ""):gsub("%s+", "")
	local parsed = tonumber(compact)
	if parsed ~= nil then return parsed end

	if type(to_big) == "function" then
		local converted = safe_call(to_big, compact)
		if converted ~= nil then return converted end
	end

	return nil
end

function CALC.to_score_number(value)
	if value == nil then return 0 end

	local value_type = type(value)
	if value_type == "number" then return value end
	if value_type == "string" then
		return parse_score_string(value) or value
	end
	if value_type == "table" then
		if is_big_score(value) then return value end
		if type(to_big) == "function" then
			local converted = safe_call(to_big, value)
			if converted ~= nil then return converted end
		end
		return value
	end

	return value
end

function CALC.zero_score()
	if type(to_big) == "function" then
		local zero = safe_call(to_big, 0)
		if zero ~= nil then return zero end
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
	if value == nil then return CALC.zero_score() end

	local floored = safe_call(math.floor, value)
	if floored ~= nil then return floored end

	local normalized = CALC.to_score_number(value)
	if normalized ~= value then
		floored = safe_call(math.floor, normalized)
		if floored ~= nil then return floored end
		return normalized
	end

	return value
end

function CALC.values_equal(left, right)
	left = CALC.to_score_number(left)
	right = CALC.to_score_number(right)

	local ok, equal = pcall(function() return left == right end)
	if ok then return equal end
	return tostring(left) == tostring(right)
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

	local result = {
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
	return result
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
