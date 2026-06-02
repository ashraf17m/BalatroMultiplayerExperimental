-- Shared calculator feature shell.
--
-- The player sees one calculator. The selected backend only changes which
-- scoring engine answers the request.

MP = MP or {}
MP.CALCULATOR = MP.CALCULATOR or {}
MP.CALCULATOR_V2 = MP.CALCULATOR_V2 or {}

local CORE = MP.CALCULATOR
local NATIVE = MP.CALCULATOR_V2

CORE.text = CORE.text or {
	score = { l = " " },
}
CORE.text.score = CORE.text.score or {}
CORE.text.score.l = CORE.text.score.l ~= "" and CORE.text.score.l or " "

local function selected_backend_value()
	if not (MP and MP.PLATFORM and MP.PLATFORM.SMODS and MP.PLATFORM.SMODS.get_config_value) then
		return 1
	end

	return tonumber(MP.PLATFORM.SMODS.get_config_value("calculator.backend", 1, MP)) or 1
end

function CORE.selected_engine_key()
	return selected_backend_value() == 2 and "native" or "original"
end

function CORE.get_calculation_wait_text()
	if MP and MP.UTILS and type(MP.UTILS.get_calculator_label) == "function" then
		return MP.UTILS.get_calculator_label("text")
	end
	return "CALCULATING"
end

function CORE.get_calculate_button_text()
	if MP and MP.UTILS and type(MP.UTILS.get_calculator_label) == "function" then
		return MP.UTILS.get_calculator_label("button")
	end
	return "Calculate Score"
end

local function preview_disabled()
	return MP and MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.preview_disabled
end

local function original_engine_enabled()
	return FN
		and FN.PRE
		and type(FN.PRE.integration_enabled) == "function"
		and FN.PRE.integration_enabled()
		and type(FN.PRE.enabled) == "function"
		and FN.PRE.enabled()
end

local function native_engine_enabled()
	return NATIVE and type(NATIVE.enabled) == "function" and NATIVE.enabled()
end

function CORE.enabled()
	if preview_disabled() then return false end
	return CORE.selected_engine_key() == "native" and native_engine_enabled() or original_engine_enabled()
end

function CORE.is_score_calculator_state()
	return G and G.STATE and G.STATES
		and (G.STATE == G.STATES.SELECTING_HAND or G.STATE == G.STATES.DRAW_TO_HAND or G.STATE == G.STATES.PLAY_TAROT)
end

local function safe_call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, result = pcall(fn, ...)
	if ok then return result end
	return nil
end

function CORE.to_score_number(value)
	if NATIVE and type(NATIVE.to_score_number) == "function" then
		return NATIVE.to_score_number(value)
	end
	if FN and FN.PRE and type(FN.PRE.to_big) == "function" then
		return FN.PRE.to_big(value)
	end
	if type(to_big) == "function" and (type(value) == "number" or type(value) == "table") then
		local converted = safe_call(to_big, value)
		if converted ~= nil then return converted end
	end
	return value or 0
end

function CORE.add_values(left, right)
	left = CORE.to_score_number(left)
	right = CORE.to_score_number(right)
	local result = safe_call(function() return left + right end)
	return result ~= nil and result or 0
end

function CORE.values_equal(left, right)
	left = CORE.to_score_number(left)
	right = CORE.to_score_number(right)

	local ok, equal = pcall(function() return left == right end)
	if ok then return equal end
	return tostring(left) == tostring(right)
end

function CORE.is_enough_to_win(chips)
	if G and G.GAME and G.GAME.blind and CORE.is_score_calculator_state() then
		local total = CORE.add_values(G.GAME.chips, chips)
		local target = CORE.to_score_number(G.GAME.blind.chips)
		local ok, enough = pcall(function() return total >= target end)
		return ok and enough or false
	end
	return false
end

function CORE.format_number(num)
	if num == nil then return "" end
	if type(num) ~= "number" then
		local ok, formatted = pcall(number_format, num)
		if ok then return tostring(formatted) end
		return tostring(num)
	end
	if num >= 1e7 then
		local x = string.format("%.4g", num)
		local fac = math.floor(math.log(tonumber(x), 10))
		return string.format("%.2f", x / (10 ^ fac)) .. "e" .. fac
	end
	return number_format(num)
end

local function display_from_result(result)
	if not (result and result.score) then return nil, nil end

	local min = result.score.min
	local exact = result.score.exact
	local max = result.score.max
	local score_for_win = exact or max or min
	local has_uncertainty = result.probability_events
		and result.probability_events.count
		and result.probability_events.count > 0
		or (result.probabilities ~= nil and result.probabilities ~= "exact_only")

	if min ~= nil and max ~= nil and (has_uncertainty or not CORE.values_equal(min, max)) then
		return CORE.format_number(min) .. " - " .. CORE.format_number(max), score_for_win
	end

	local score = exact or min or max
	if score == nil then return nil, nil end
	return CORE.format_number(score), score_for_win
end

local function native_result_is_fresh()
	if not (NATIVE.show_result and NATIVE.display_result ~= nil) then
		return false
	end
	if type(NATIVE.current_request_guard_signature) == "function" and NATIVE.display_guard_signature ~= nil then
		return NATIVE.display_guard_signature == NATIVE.current_request_guard_signature()
	end
	if NATIVE.display_signature == nil then return false end
	if type(NATIVE.current_signature) ~= "function" then
		return NATIVE.display_signature == NATIVE.last_signature
	end
	return NATIVE.display_signature == NATIVE.current_signature()
end

local function native_display()
	if NATIVE.status == "calculating" then
		return " " .. tostring(NATIVE.calculation_text or CORE.get_calculation_wait_text()) .. " ", true, G.C.MONEY
	end

	if native_result_is_fresh() then
		local score_text, score_for_win = display_from_result(NATIVE.display_result)
		local should_pulse = score_for_win ~= nil and CORE.is_enough_to_win(score_for_win) or false
		return score_text ~= nil and (" " .. score_text .. " ") or " Unknown ",
			should_pulse,
			should_pulse and G.C.MONEY or G.C.UI.TEXT_LIGHT
	end

	if NATIVE.show_result and NATIVE.status == "unsupported" then
		return " Unknown ", false, G.C.UI.TEXT_LIGHT
	end

	return " ", false, G.C.UI.TEXT_LIGHT
end

local function original_display()
	if not (FN and FN.PRE) then return " ", false, G.C.UI.TEXT_LIGHT end

	if FN.PRE.lock_updates then
		return " " .. CORE.get_calculation_wait_text() .. " ", true, G.C.MONEY
	end

	local data = FN.PRE.data
	if not (FN.PRE.show_preview and data and data.score) then return " ", false, G.C.UI.TEXT_LIGHT end

	local score_text, score_for_win = display_from_result(data)
	local should_pulse = score_for_win ~= nil and CORE.is_enough_to_win(score_for_win) or false
	return score_text ~= nil and (" " .. score_text .. " ") or " ?????? ",
		should_pulse,
		should_pulse and G.C.MONEY or G.C.UI.TEXT_LIGHT
end

function CORE.current_display()
	return CORE.selected_engine_key() == "native" and native_display() or original_display()
end

function CORE.request()
	if not CORE.enabled() then return end

	if CORE.selected_engine_key() == "native" then
		if type(NATIVE.request) == "function" then NATIVE.request() end
		return
	end

	if FN and FN.PRE and type(FN.PRE.start_calculation_event) == "function" then
		FN.PRE.start_calculation_event()
	end
end

function CORE.refresh_display()
	CORE.text.score.l = CORE.text.score.l ~= "" and CORE.text.score.l or " "
end

function NATIVE.integration_enabled()
	return CORE.selected_engine_key() == "native" and CORE.enabled()
end

function NATIVE.refresh_display()
	CORE.refresh_display()
end
