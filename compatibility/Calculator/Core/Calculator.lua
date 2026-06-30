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
	score = { l = " ", m = "", r = "" },
}
CORE.text.score = CORE.text.score or {}
CORE.text.score.l = CORE.text.score.l ~= "" and CORE.text.score.l or " "
CORE.text.score.m = CORE.text.score.m or ""
CORE.text.score.r = CORE.text.score.r or ""
CORE.text.score_colours = CORE.text.score_colours or {}
CORE.HIDDEN_SCORE_TEXT = " ???? "

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

local function card_is_face_down(card)
	return card and card.facing == "back"
end

function CORE.selected_hand_has_hidden_information()
	if not (G and G.hand and G.hand.highlighted) then return false end

	for _, card in ipairs(G.hand.highlighted) do
		if card_is_face_down(card) then return true end
	end

	if #G.hand.highlighted == 0 or not (G.jokers and G.jokers.cards) then return false end
	for _, joker in ipairs(G.jokers.cards) do
		if card_is_face_down(joker) then return true end
	end

	return false
end

function CORE.hidden_information_result(reason)
	return {
		hidden_information = true,
		reason = reason or "hidden scoring information",
	}
end

function CORE.current_hidden_information_result()
	if CORE.selected_hand_has_hidden_information() then
		return CORE.hidden_information_result("hidden face-down card")
	end
end

function CORE.is_coop_calculation_context()
	if MP and type(MP.is_coop_blind) == "function" and MP.is_coop_blind() then return true end
	if MP and type(MP.is_coop_gamemode) == "function" and MP.is_coop_gamemode() then return true end
	if MP and type(MP.is_coop_lobby_type) == "function" and MP.is_coop_lobby_type() then return true end

	if not (MP and MP.LOBBY) then return false end
	local config = MP.LOBBY.config or {}
	return config.gamemode == "gamemode_mp_coop"
		or config.gamemode == "coop"
		or (MP.LOBBY_TYPES and MP.LOBBY.lobby_type == MP.LOBBY_TYPES.COOP)
end

local function get_calculation_timer_settings(is_current_pvp_blind)
	if not (
		MP
		and MP.LOBBY
		and MP.LOBBY.code
		and MP.LOBBY.config
		and MP.LOBBY.config.timer
		and not is_current_pvp_blind
		and not CORE.is_coop_calculation_context()
	) then
		return 0, 0
	end

	local ruleset = MP.current_ruleset and MP.current_ruleset() or {}
	local fallback_delay = 3 * (G and G.SETTINGS and G.SETTINGS.GAMESPEED or 1)
	local delay = MP.LOBBY.config.preview_calculate_delay or ruleset.preview_calculate_delay or fallback_delay
	local cost = MP.LOBBY.config.preview_calculate_cost or ruleset.preview_calculate_cost or 0
	return tonumber(delay) or 0, tonumber(cost) or 0
end

function CORE.calculation_start_delay(is_current_pvp_blind)
	local delay = get_calculation_timer_settings(is_current_pvp_blind)
	return delay
end

function CORE.consume_calculation_timer_cost(is_current_pvp_blind, result)
	local _, cost = get_calculation_timer_settings(is_current_pvp_blind)
	if cost <= 0 then
		return false
	end
	if result and (result.empty or result.hidden_information or result.unsupported) then
		return false
	end
	if not (
		MP.GAME
		and MP.GAME.timer
		and not MP.GAME.timer_started
		and not MP.GAME.nemesis_timer_started
		and not MP.GAME.timer_consumed
		and MP.UI
		and MP.UI.consume_timer
	) then
		return false
	end
	return MP.UI.consume_timer(cost, nil, math.max(10, cost))
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

local function get_current_score_for_win_check()
	local teams_domain = MP and MP.DOMAIN and MP.DOMAIN.TEAMS or nil
	if teams_domain and type(teams_domain.get_cooperative_blind_score) == "function" then
		local cooperative_score = teams_domain.get_cooperative_blind_score()
		if cooperative_score ~= nil then
			return cooperative_score
		end
	end

	return G.GAME.chips
end

local function get_current_target_for_win_check()
	local teams_domain = MP and MP.DOMAIN and MP.DOMAIN.TEAMS or nil
	if teams_domain and type(teams_domain.get_cooperative_blind_target) == "function" then
		local cooperative_target = teams_domain.get_cooperative_blind_target()
		if cooperative_target ~= nil then
			return cooperative_target
		end
	end

	return G.GAME.blind.chips
end

function CORE.is_enough_to_win(chips)
	if G and G.GAME and G.GAME.blind and CORE.is_score_calculator_state() then
		local total = CORE.add_values(get_current_score_for_win_check(), chips)
		local target = CORE.to_score_number(get_current_target_for_win_check())
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
	return number_format(num)
end

local function blank_part(text)
	return {
		text = text or "",
		should_pulse = false,
		colour = G.C.UI.TEXT_LIGHT,
	}
end

local function scored_part(text, score)
	local should_pulse = score ~= nil and CORE.is_enough_to_win(score) or false
	return {
		text = text or "",
		should_pulse = should_pulse,
		colour = should_pulse and G.C.MONEY or G.C.UI.TEXT_LIGHT,
	}
end

local function single_part(text, should_pulse, colour)
	return {
		l = {
			text = text or " ",
			should_pulse = should_pulse or false,
			colour = colour or G.C.UI.TEXT_LIGHT,
		},
		m = blank_part(),
		r = blank_part(),
	}
end

local function display_parts_from_result(result, unknown_text)
	if not result then return nil end
	if result.hidden_information then return single_part(CORE.HIDDEN_SCORE_TEXT, false, G.C.UI.TEXT_LIGHT) end
	if not result.score then return nil end

	local min = result.score.min
	local exact = result.score.exact
	local max = result.score.max

	if min ~= nil and max ~= nil and not CORE.values_equal(min, max) then
		return {
			l = scored_part(CORE.format_number(min), min),
			m = scored_part(" - ", min),
			r = scored_part(CORE.format_number(max), max),
		}
	end

	local score = exact or min or max
	if score == nil then return single_part(unknown_text or " Unknown ", false, G.C.UI.TEXT_LIGHT) end
	local should_pulse = CORE.is_enough_to_win(score)
	return single_part(" " .. CORE.format_number(score) .. " ", should_pulse, should_pulse and G.C.MONEY or G.C.UI.TEXT_LIGHT)
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
		return single_part(" " .. tostring(NATIVE.calculation_text or CORE.get_calculation_wait_text()) .. " ", true, G.C.MONEY)
	end

	if native_result_is_fresh() then
		return display_parts_from_result(NATIVE.display_result, " Unknown ") or single_part(" Unknown ", false, G.C.UI.TEXT_LIGHT)
	end

	if NATIVE.show_result and NATIVE.status == "unsupported" then
		return single_part(" Unknown ", false, G.C.UI.TEXT_LIGHT)
	end

	return single_part(" ", false, G.C.UI.TEXT_LIGHT)
end

local function original_display()
	if not (FN and FN.PRE) then return single_part(" ", false, G.C.UI.TEXT_LIGHT) end

	if FN.PRE.lock_updates then
		return single_part(" " .. CORE.get_calculation_wait_text() .. " ", true, G.C.MONEY)
	end

	local data = FN.PRE.data
	if not (FN.PRE.show_preview and data and (data.score or data.hidden_information)) then
		return single_part(" ", false, G.C.UI.TEXT_LIGHT)
	end

	return display_parts_from_result(data, " ?????? ") or single_part(" ?????? ", false, G.C.UI.TEXT_LIGHT)
end

function CORE.current_display_part(key)
	local parts = CORE.selected_engine_key() == "native" and native_display() or original_display()
	local part = parts and parts[key] or nil
	part = part or blank_part(key == "l" and " " or "")
	return part.text, part.should_pulse, part.colour
end

function CORE.current_display()
	return CORE.current_display_part("l")
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
	CORE.text.score.m = CORE.text.score.m or ""
	CORE.text.score.r = CORE.text.score.r or ""
end

function NATIVE.integration_enabled()
	return CORE.selected_engine_key() == "native" and CORE.enabled()
end

function NATIVE.refresh_display()
	CORE.refresh_display()
end
