-- These functions are mostly just for handling really big numbers,
-- no matter the source and even if talisman is not installed.

-- This should NOT be used as a substitute for bigints in functional coded due to how barebones it is,
-- Instead, it should be used for graphical purposes and such

MP.INSANE_INT = {}

local function is_finite_number(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function get_coefficient(value)
	return value and (value.coefficient or value.coeffiocient) or 0
end

local function normalize_parts(coefficient, exponent, e_count)
	coefficient = tonumber(coefficient) or 0
	exponent = tonumber(exponent) or 0
	e_count = tonumber(e_count) or 0

	if coefficient == 0 then
		return 0, 0, 0
	end

	if e_count ~= 0 then
		return coefficient, exponent, e_count
	end

	local sign = coefficient < 0 and -1 or 1
	local abs_coefficient = math.abs(coefficient)

	if abs_coefficient >= 10 then
		local change = math.floor(math.log(abs_coefficient) / math.log(10))
		abs_coefficient = abs_coefficient / math.pow(10, change)
		exponent = exponent + change
	end

	if abs_coefficient < 1 and exponent > 0 then
		local change = math.ceil(math.log(1 / abs_coefficient) / math.log(10))
		change = math.min(change, exponent)
		abs_coefficient = abs_coefficient * math.pow(10, change)
		exponent = exponent - change
	end

	return sign * abs_coefficient, exponent, e_count
end

local function create_insane_int(coefficient, exponent, e_count)
	coefficient, exponent, e_count = normalize_parts(coefficient, exponent, e_count)
	return setmetatable({
		_coefficient = coefficient,
		exponent = exponent,
		e_count = e_count,
	}, {
		__index = function(t, k)
			if k == "coefficient" or k == "coeffiocient" then
				return rawget(t, "_coefficient")
			end
			return rawget(t, k)
		end,
		__newindex = function(t, k, v)
			if k == "coefficient" or k == "coeffiocient" then
				rawset(t, "_coefficient", tonumber(v) or 0)
				return
			end
			rawset(t, k, v)
		end,
	})
end

local function normalize_insane_int(value)
	if not value then
		return MP.INSANE_INT.empty()
	end

	return MP.INSANE_INT.create(get_coefficient(value), value.exponent, value.e_count)
end

MP.INSANE_INT.empty = function()
	return create_insane_int(0, 0, 0)
end

MP.INSANE_INT.create = function(coefficient, exponent, e_count)
	return create_insane_int(coefficient, exponent, e_count)
end

MP.INSANE_INT.normalize = normalize_insane_int

MP.INSANE_INT.copy = function(value)
	if not value then
		return MP.INSANE_INT.empty()
	end
	return MP.INSANE_INT.create(get_coefficient(value), value.exponent, value.e_count)
end

MP.INSANE_INT.copy_into = function(target, source)
	if not (target and source) then
		return false
	end

	local normalized = normalize_insane_int(source)
	target.e_count = tonumber(normalized.e_count) or 0
	target.coefficient = tonumber(normalized.coefficient) or 0
	target.exponent = tonumber(normalized.exponent) or 0
	return true
end

MP.INSANE_INT.from_string = function(str)
	str = tostring(str or "0"):gsub(",", "")
	local e_count = 0
	while #str > 0 and string.lower(string.sub(str, 1, 1)) == "e" do
		e_count = e_count + 1
		str = string.sub(str, 2)
	end

	local parts = MP.UTILS.string_split(str, "e")

	return MP.INSANE_INT.create(parts[1], #parts > 1 and parts[2] or 0, e_count)
end

local function get_e_switch_value()
	local switch_value = tonumber(G and G.E_SWITCH_POINT) or 100000000000
	if switch_value <= 0 then
		return 100000000000
	end
	return switch_value
end

local function get_e_switch_exponent()
	local switch_value = get_e_switch_value()
	if switch_value < 1000 then
		return math.max(0, math.floor(switch_value))
	end
	return math.max(0, math.floor((math.log(switch_value) / math.log(10)) + 0.000001))
end

MP.INSANE_INT.get_e_switch_exponent = get_e_switch_exponent

MP.INSANE_INT.to_safe_number = function(insane_int_display)
	if not insane_int_display then
		return nil
	end

	insane_int_display = normalize_insane_int(insane_int_display)
	local e_count = tonumber(insane_int_display.e_count) or 0
	local exponent = tonumber(insane_int_display.exponent) or 0
	local coefficient = tonumber(insane_int_display.coefficient) or 0
	if e_count ~= 0 or exponent < 0 or exponent > 300 then
		return nil
	end

	local safe_number = coefficient * math.pow(10, exponent)
	if safe_number ~= safe_number or safe_number == math.huge or safe_number == -math.huge then
		return nil
	end

	return safe_number
end

MP.INSANE_INT.set_from_safe_number = function(insane_int_display, value)
	if not (insane_int_display and is_finite_number(value)) then
		return false
	end

	local rounded_value = math.max(0, math.floor(value + 0.5))
	return MP.INSANE_INT.copy_into(insane_int_display, MP.INSANE_INT.create(rounded_value, 0, 0))
end

local function queue_ease_event(event_config)
	local balatro = MP.PLATFORM and MP.PLATFORM.BALATRO or nil
	if balatro and balatro.queue_event then
		balatro.queue_event(event_config)
		return true
	end

	if G and G.E_MANAGER and Event then
		G.E_MANAGER:add_event(Event(event_config))
		return true
	end

	return false
end

local function clamp_eased_score(value, start_value, target_value)
	if not is_finite_number(value) then
		return start_value
	end

	if target_value >= start_value then
		return math.min(target_value, math.max(start_value, value))
	end
	return math.max(target_value, math.min(start_value, value))
end

local function ease_display_score_as_safe_value(score_display, target_score, delay)
	local start_value = MP.INSANE_INT.to_safe_number(score_display)
	local target_value = MP.INSANE_INT.to_safe_number(target_score)
	if start_value == nil or target_value == nil then
		return false
	end

	score_display._mp_score_ease_generation = (tonumber(score_display._mp_score_ease_generation) or 0) + 1
	local generation = score_display._mp_score_ease_generation
	if target_value <= start_value then
		return MP.INSANE_INT.copy_into(score_display, target_score)
	end

	local proxy = score_display._mp_score_ease_proxy or {}
	proxy.value = start_value
	score_display._mp_score_ease_proxy = proxy

	return queue_ease_event({
		blockable = false,
		blocking = false,
		trigger = "ease",
		delay = delay,
		ref_table = proxy,
		ref_value = "value",
		ease_to = target_value,
		func = function(value)
			if score_display._mp_score_ease_generation ~= generation then
				return proxy.value
			end

			local eased_value = clamp_eased_score(value, start_value, target_value)
			MP.INSANE_INT.set_from_safe_number(score_display, eased_value)
			return eased_value
		end,
	})
end

MP.INSANE_INT.ease_display_score = function(score_display, target_score, options)
	if not (score_display and target_score) then
		return false
	end

	local delay = options and options.delay or 1
	if ease_display_score_as_safe_value(score_display, target_score, delay) then
		return true
	end

	score_display._mp_score_ease_generation = (tonumber(score_display._mp_score_ease_generation) or 0) + 1
	local generation = score_display._mp_score_ease_generation
	local display_score = normalize_insane_int(score_display)
	local target_display_score = normalize_insane_int(target_score)

	if display_score.e_count ~= target_display_score.e_count or display_score.exponent ~= target_display_score.exponent then
		MP.INSANE_INT.copy_into(score_display, target_display_score)
		return true
	end

	return queue_ease_event({
		blockable = false,
		blocking = false,
		trigger = "ease",
		delay = delay,
		ref_table = score_display,
		ref_value = "coefficient",
		ease_to = tonumber(target_display_score.coefficient) or 0,
		func = function(value)
			if score_display._mp_score_ease_generation ~= generation then
				return score_display.coefficient
			end
			return value
		end,
	})
end

MP.INSANE_INT.reaches_e_switch_point = function(insane_int_display)
	if not insane_int_display then
		return false
	end

	insane_int_display = normalize_insane_int(insane_int_display)
	local safe_number = MP.INSANE_INT.to_safe_number(insane_int_display)
	if safe_number ~= nil then
		return math.abs(safe_number) >= get_e_switch_value()
	end

	if (tonumber(insane_int_display.e_count) or 0) > 0 then
		return true
	end
	return (tonumber(insane_int_display.exponent) or 0) > get_e_switch_exponent()
end

MP.INSANE_INT.to_string = function(insane_int_display)
	insane_int_display = normalize_insane_int(insane_int_display)
	local e_count = tonumber(insane_int_display.e_count) or 0
	local exponent = tonumber(insane_int_display.exponent) or 0
	local coefficient = tonumber(insane_int_display.coefficient) or 0
	local e = ""
	for i = 1, e_count do
		e = e .. "e"
	end

	if exponent == 0 then return e .. number_format(coefficient) end

	if e_count == 0 and exponent > 0 then
		local safe_number = MP.INSANE_INT.to_safe_number(insane_int_display)
		if safe_number ~= nil then
			return number_format(safe_number)
		end
	end

	return e
		.. number_format(coefficient, 10000)
		.. "e"
		.. number_format(exponent)
end

-- This doesn't really fit with the comment at the top,
-- but I needed a way to compare highscores without storing this value seperately for no reason
MP.INSANE_INT.greater_than = function(insane_int_display1, insane_int_display2)
	insane_int_display1 = normalize_insane_int(insane_int_display1)
	insane_int_display2 = normalize_insane_int(insane_int_display2)

	if insane_int_display1.e_count ~= insane_int_display2.e_count then
		return tonumber(insane_int_display1.e_count) > tonumber(insane_int_display2.e_count)
	end

	if insane_int_display1.exponent ~= insane_int_display2.exponent then
		return tonumber(insane_int_display1.exponent) > tonumber(insane_int_display2.exponent)
	end

	return tonumber(insane_int_display1.coefficient) > tonumber(insane_int_display2.coefficient)
end

-- ignore deprected warning for math.pow
-- math.pow is used instead of ^ to avoid conflicts with talisman's __pow override
-- theoretically the talisman override only applies to their special big number types and using '^' would be fine,
-- but we use math.pow just in case
---@diagnostic disable: deprecated
MP.INSANE_INT.add = function(insane_int_display1, insane_int_display2)
	local starting_e_count
	local coefficient
	local exponent

	insane_int_display1 = normalize_insane_int(insane_int_display1)
	insane_int_display2 = normalize_insane_int(insane_int_display2)

	local myStartingECount = insane_int_display1.e_count
	local myCoefficient = insane_int_display1.coefficient
	local myExponent = insane_int_display1.exponent

	local otherStartingECount = insane_int_display2.e_count
	local otherCoefficient = insane_int_display2.coefficient
	local otherExponent = insane_int_display2.exponent

	if myStartingECount > otherStartingECount then
		otherExponent = (otherExponent / math.pow(10, (myStartingECount - otherStartingECount)))
		starting_e_count = myStartingECount
	elseif myStartingECount < otherStartingECount then
		myExponent = (myExponent / math.pow(10, (otherStartingECount - myStartingECount)))
		starting_e_count = otherStartingECount
	else
		starting_e_count = myStartingECount
	end

	if myExponent > otherExponent then
		coefficient = (otherCoefficient / math.pow(10, (myExponent - otherExponent))) + myCoefficient
		exponent = myExponent
	elseif myExponent < otherExponent then
		coefficient = (myCoefficient / math.pow(10, (otherExponent - myExponent))) + otherCoefficient
		exponent = otherExponent
	else
		coefficient = myCoefficient + otherCoefficient
		exponent = myExponent
	end

	return MP.INSANE_INT.create(coefficient, exponent, starting_e_count)
end

local function divide(insane_int, divisor)
	if divisor == 0 then return MP.INSANE_INT.empty() end
	insane_int = normalize_insane_int(insane_int)
	local coeff = insane_int.coefficient / divisor
	local exp = insane_int.exponent
	local e_count = insane_int.e_count

	-- Normalize if needed (though for display it's mostly fine)
	if coeff < 1 and coeff > 0 and exp > 0 then
		coeff = coeff * 10
		exp = exp - 1
	end

	return MP.INSANE_INT.create(coeff, exp, e_count)
end

local function floor(insane_int)
	if not insane_int then
		return MP.INSANE_INT.empty()
	end

	local coeff = tonumber(insane_int.coefficient) or 0
	local exp = tonumber(insane_int.exponent) or 0
	local e_count = tonumber(insane_int.e_count) or 0

	if coeff <= 0 then
		return MP.INSANE_INT.empty()
	end

	while exp > 0 and coeff ~= math.floor(coeff) do
		coeff = coeff * 10
		exp = exp - 1
	end

	return MP.INSANE_INT.create(math.floor(coeff), exp, e_count)
end

MP.INSANE_INT.divide_floor = function(insane_int, divisor)
	return floor(divide(insane_int, divisor))
end

MP.INSANE_INT.log10 = function(insane_int)
	insane_int = normalize_insane_int(insane_int)
	if not MP.INSANE_INT.greater_than(insane_int, MP.INSANE_INT.empty()) then
		return nil
	end

	if (tonumber(insane_int.e_count) or 0) > 0 then
		return MP.INSANE_INT.create(insane_int.coefficient, insane_int.exponent, insane_int.e_count - 1)
	end

	local coefficient = tonumber(insane_int.coefficient) or 0
	if coefficient <= 0 then
		return nil
	end

	return MP.INSANE_INT.create((math.log(coefficient) / math.log(10)) + insane_int.exponent, 0, 0)
end

MP.INSANE_INT.from_log10 = function(log_value)
	log_value = normalize_insane_int(log_value)
	if (tonumber(log_value.e_count) or 0) > 0 then
		return MP.INSANE_INT.create(log_value.coefficient, log_value.exponent, log_value.e_count + 1)
	end

	local raw_log = (tonumber(log_value.coefficient) or 0) * math.pow(10, tonumber(log_value.exponent) or 0)
	if raw_log ~= raw_log or raw_log == math.huge or raw_log == -math.huge then
		return MP.INSANE_INT.create(log_value.coefficient, log_value.exponent, 1)
	end

	local exponent = math.floor(raw_log)
	local coefficient = math.pow(10, raw_log - exponent)
	return MP.INSANE_INT.create(coefficient, exponent, 0)
end

MP.INSANE_INT.geometric_mean = function(values)
	local log_total = MP.INSANE_INT.empty()
	local count = 0

	for _, value in ipairs(values or {}) do
		local log_value = MP.INSANE_INT.log10(value)
		if not log_value then
			return MP.INSANE_INT.empty()
		end
		log_total = MP.INSANE_INT.add(log_total, log_value)
		count = count + 1
	end

	if count <= 0 then
		return MP.INSANE_INT.empty()
	end

	return floor(MP.INSANE_INT.from_log10(divide(log_total, count)))
end
---@diagnostic enable: deprecated
