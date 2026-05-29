-- Utilities for checking runtime enablement and converting score values.

function FN.PRE.to_big(value)
	if type(to_big) == "function" and (type(value) == "number" or type(value) == "table") then
		local ok, converted = pcall(to_big, value)
		if ok then return converted end
	end
	return value or 0
end

local function original_calculator_selected()
	if not (MP and MP.PLATFORM and MP.PLATFORM.SMODS and MP.PLATFORM.SMODS.get_config_value) then
		return true
	end

	return tonumber(MP.PLATFORM.SMODS.get_config_value("calculator.backend", 1, MP)) ~= 2
end

function FN.PRE.enabled()
	if not original_calculator_selected() then return false end
	return G.SETTINGS.FN.preview_score or G.SETTINGS.FN.preview_dollars
end
