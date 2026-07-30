-- Calculator V2 orchestration.
--
-- V2 owns an independent SMODS-native exact score backend. Unsupported cases
-- return unknown instead of guessing.

MP = MP or {}
MP.CALCULATOR_V2 = MP.CALCULATOR_V2 or {}

local CALC = MP.CALCULATOR_V2

CALC.queued = CALC.queued or false
CALC.cache_revision = CALC.cache_revision or 0
CALC.last_signature = CALC.last_signature or nil
CALC.last_guard_signature = CALC.last_guard_signature or nil
CALC.last_result = CALC.last_result or nil
CALC.status = CALC.status or "idle"
CALC.show_result = CALC.show_result or false
CALC.display_result = CALC.display_result or nil
CALC.display_signature = CALC.display_signature or nil
CALC.display_guard_signature = CALC.display_guard_signature or nil
CALC.request_id = CALC.request_id or 0

local function has_selected_cards()
	return G and G.hand and G.hand.highlighted and #G.hand.highlighted > 0
end

local function is_preview_state()
	return G and G.STATE and G.STATES
		and (G.STATE == G.STATES.SELECTING_HAND or G.STATE == G.STATES.DRAW_TO_HAND or G.STATE == G.STATES.PLAY_TAROT)
end

local function is_current_pvp_blind()
	if MP and type(MP.is_pvp_boss) == "function" and MP.is_pvp_boss() then return true end

	local blind = BALATRO and BALATRO.get_current_blind and BALATRO.get_current_blind() or nil
	if not blind then return false end

	local blind_key = blind.config and blind.config.blind and blind.config.blind.key or blind.name
	return blind_key == "bl_mp_nemesis" or not not blind.pvp
end

local function calculation_start_delay()
	if MP and MP.CALCULATOR and type(MP.CALCULATOR.calculation_start_delay) == "function" then
		return MP.CALCULATOR.calculation_start_delay(is_current_pvp_blind())
	end
	if MP and MP.LOBBY and MP.LOBBY.code and not is_current_pvp_blind() then
		return 3 * (G and G.SETTINGS and G.SETTINGS.GAMESPEED or 1)
	end
	return 0
end

function CALC.enabled()
	if not (MP and MP.PLATFORM and MP.PLATFORM.SMODS and MP.PLATFORM.SMODS.get_config_value) then
		return false
	end

	return tonumber(MP.PLATFORM.SMODS.get_config_value("calculator.backend", 1, MP)) == 2
end

function CALC.set_calculation_wait_text()
	if MP and MP.CALCULATOR and type(MP.CALCULATOR.get_calculation_wait_text) == "function" then
		CALC.calculation_text = MP.CALCULATOR.get_calculation_wait_text()
	else
		CALC.calculation_text = "CALCULATING"
	end
end

local function refresh_display()
	if type(CALC.refresh_display) == "function" then CALC.refresh_display() end
end

local function status_after_clear(status)
	return status or (has_selected_cards() and "dirty" or "idle")
end

local function clear_cached_result()
	CALC.last_signature = nil
	CALC.last_guard_signature = nil
	CALC.last_result = nil
end

local function store_cached_result(signature, guard_signature, result)
	CALC.last_signature = signature
	CALC.last_guard_signature = guard_signature
	CALC.last_result = result
end

local function clear_display_result()
	CALC.display_result = nil
	CALC.display_signature = nil
	CALC.display_guard_signature = nil
	CALC.show_result = false
end

local function clear_active_request()
	CALC.queued = false
	CALC.active_request_id = nil
	CALC.active_request_signature = nil
	CALC.active_request_guard_signature = nil
	CALC.calculation_text = nil
end

local function show_ready_result(result)
	CALC.status = "ready"
	CALC.display_result = result
	CALC.display_signature = CALC.last_signature
	CALC.display_guard_signature = CALC.last_guard_signature
	CALC.show_result = true
	refresh_display()
end

local function show_unsupported_result()
	CALC.status = "unsupported"
	clear_display_result()
	CALC.show_result = true
	refresh_display()
end

local function show_calculating_result(request_id, signature, guard_signature)
	CALC.queued = true
	CALC.active_request_id = request_id
	CALC.active_request_signature = signature
	CALC.active_request_guard_signature = guard_signature
	CALC.set_calculation_wait_text()
	CALC.status = "calculating"
	clear_display_result()
	CALC.show_result = true
	refresh_display()
end

function CALC.invalidate_cache(status)
	CALC.cache_revision = (CALC.cache_revision or 0) + 1
	clear_cached_result()
	CALC.calculation_text = nil
	clear_display_result()
	CALC.status = status_after_clear(status)
	refresh_display()
end

function CALC.cancel_request(status)
	clear_active_request()
	clear_display_result()
	CALC.status = status_after_clear(status)
	refresh_display()
end

function CALC.current_result(signature, guard_signature)
	signature = signature or CALC.current_signature()
	guard_signature = guard_signature or CALC.current_request_guard_signature()
	if CALC.exact_result and G and G.hand and G.hand.highlighted and #G.hand.highlighted == 0 then
		local result = CALC.exact_result(0, 0)
		CALC.status = "idle"
		store_cached_result(signature, guard_signature, result)
		return result
	end
	if CALC.last_result ~= nil
		and CALC.last_signature == signature
		and CALC.last_guard_signature == guard_signature
	then
		CALC.status = "ready"
		return CALC.last_result
	end
	return nil
end

function CALC.finish(ok, result, reason)
	clear_active_request()

	if ok and result ~= nil and not result.unsupported then
		show_ready_result(result)
		return
	end

	show_unsupported_result()
end

function CALC.request()
	if CALC.queued then
		return
	end
	if not CALC.enabled() then
		return
	end
	if type(CALC.integration_enabled) == "function" and not CALC.integration_enabled() then
		return
	end

	CALC.request_id = (CALC.request_id or 0) + 1
	local request_id = CALC.request_id
	show_calculating_result(request_id, CALC.current_signature(), CALC.current_request_guard_signature())

	local request_is_pvp_blind = is_current_pvp_blind()
	local calculation_signature = nil
	local calculation_guard_signature = nil
	local function finish_for_request(result, reason)
		if CALC.active_request_id ~= request_id then
			return
		end
		local current_guard_signature = CALC.current_request_guard_signature()
		if calculation_guard_signature ~= current_guard_signature then
			CALC.cancel_request()
			return
		end

		if result ~= nil and not result.unsupported then
			store_cached_result(calculation_signature or CALC.current_signature(), calculation_guard_signature, result)
			if MP and MP.CALCULATOR and type(MP.CALCULATOR.consume_calculation_timer_cost) == "function" then
				MP.CALCULATOR.consume_calculation_timer_cost(request_is_pvp_blind, result)
			end
			CALC.finish(true, result)
			return
		end

		if result ~= nil and result.unsupported then
			CALC.finish(true, result, result.reason)
			return
		end

		CALC.finish(false, nil, reason)
	end

	if type(CALC.run_native_exact_async) ~= "function" then
		CALC.finish(false, nil, "experimental exact backend is not loaded")
		return
	end

	local function start_backend()
		if CALC.active_request_id ~= request_id then
			return true
		end
		if not is_preview_state() then
			CALC.cancel_request()
			return true
		end

		calculation_guard_signature = CALC.current_request_guard_signature()
		calculation_signature = CALC.current_signature()

		local hidden_result = MP and MP.CALCULATOR and type(MP.CALCULATOR.current_hidden_information_result) == "function"
			and MP.CALCULATOR.current_hidden_information_result()
		if hidden_result then
			store_cached_result(calculation_signature, calculation_guard_signature, hidden_result)
			CALC.finish(true, hidden_result)
			return true
		end

		local cached_result = nil
		if type(CALC.current_result) == "function" then
			if has_selected_cards() then
				cached_result = CALC.current_result(calculation_signature, calculation_guard_signature)
			else
				cached_result = CALC.current_result(nil, calculation_guard_signature)
				calculation_signature = CALC.last_signature or calculation_signature
			end
		end
		if cached_result ~= nil then
			clear_active_request()
			show_ready_result(cached_result)
			return true
		end

		local ok, started_or_reason = pcall(CALC.run_native_exact_async, finish_for_request)
		if ok and started_or_reason then return true end
		CALC.finish(false, nil, ok and (started_or_reason or "experimental exact backend did not start") or started_or_reason)
		return true
	end

	local delay = calculation_start_delay()
	if delay <= 0 or not (G and G.E_MANAGER and Event) then
		start_backend()
		return
	end

	G.E_MANAGER:add_event(Event({ trigger = "after", blockable = false, blocking = false, delay = delay, func = start_backend }))
end
