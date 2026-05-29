-- These functions are mostly just for handling really big numbers,
-- no matter the source and even if talisman is not installed.

-- This should NOT be used as a substitute for bigints in functional coded due to how barebones it is,
-- Instead, it should be used for graphical purposes and such

MP.INSANE_INT = {}

local function create_insane_int(coefficient, exponent, e_count)
	return setmetatable({
		_coefficient = tonumber(coefficient) or 0,
		exponent = tonumber(exponent) or 0,
		e_count = tonumber(e_count) or 0,
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

MP.INSANE_INT.empty = function()
	return create_insane_int(0, 0, 0)
end

MP.INSANE_INT.create = function(coefficient, exponent, e_count)
	return create_insane_int(coefficient, exponent, e_count)
end

MP.INSANE_INT.from_string = function(str)
	str = tostring(str or "0")
	local e_count = 0
	while #str > 0 and string.lower(string.sub(str, 1, 1)) == "e" do
		e_count = e_count + 1
		str = string.sub(str, 2)
	end

	local parts = MP.UTILS.string_split(str, "e")

	return MP.INSANE_INT.create(parts[1], #parts > 1 and parts[2] or 0, e_count)
end

MP.INSANE_INT.to_string = function(insane_int_display)
	local e = ""
	for i = 1, insane_int_display.e_count do
		e = e .. "e"
	end

	if insane_int_display.exponent == 0 then return e .. number_format(insane_int_display.coefficient) end

	return e
		.. number_format(insane_int_display.coefficient, 10000)
		.. "e"
		.. number_format(insane_int_display.exponent)
end

-- This doesn't really fit with the comment at the top,
-- but I needed a way to compare highscores without storing this value seperately for no reason
MP.INSANE_INT.greater_than = function(insane_int_display1, insane_int_display2)
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
---@diagnostic enable: deprecated
