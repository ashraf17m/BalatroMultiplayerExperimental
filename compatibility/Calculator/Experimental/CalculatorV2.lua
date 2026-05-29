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
CALC.last_result = CALC.last_result or nil
CALC.status = CALC.status or "idle"
CALC.show_result = CALC.show_result or false
CALC.display_result = CALC.display_result or nil
CALC.display_signature = CALC.display_signature or nil

local function has_selected_cards()
	return G and G.hand and G.hand.highlighted and #G.hand.highlighted > 0
end

local function is_current_pvp_blind()
	if MP and type(MP.is_pvp_boss) == "function" and MP.is_pvp_boss() then return true end

	local blind = BALATRO and BALATRO.get_current_blind and BALATRO.get_current_blind() or nil
	if not blind then return false end

	local blind_key = blind.config and blind.config.blind and blind.config.blind.key or blind.name
	return blind_key == "bl_mp_nemesis" or not not blind.pvp
end

local function calculation_start_delay()
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

local function stable_value(value, depth, seen)
	local value_type = type(value)
	if value_type == "number" or value_type == "boolean" or value_type == "string" or value == nil then
		return tostring(value)
	end
	if value_type ~= "table" then return value_type end
	if depth <= 0 then return "{...}" end

	seen = seen or {}
	if seen[value] then return "{cycle}" end
	seen[value] = true

	local keys = {}
	for key in pairs(value) do
		local key_type = type(key)
		if key_type == "string" or key_type == "number" or key_type == "boolean" then
			keys[#keys + 1] = key
		end
	end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

	local pieces = {}
	local max_items = 32
	for i, key in ipairs(keys) do
		if i > max_items then
			pieces[#pieces + 1] = "..."
			break
		end
		pieces[#pieces + 1] = tostring(key) .. "=" .. stable_value(value[key], depth - 1, seen)
	end

	seen[value] = nil
	return "{" .. table.concat(pieces, ",") .. "}"
end

local function card_signature(card)
	if not card then return "nil" end

	local center = card.config and card.config.center
	local base = card.base or {}
	return table.concat({
		tostring(card.sort_id or ""),
		tostring(center and center.key or ""),
		tostring(base.id or ""),
		tostring(base.suit or ""),
		tostring(card.facing or ""),
		tostring(card.debuff or false),
		tostring(card.seal or ""),
		stable_value(card.edition, 1),
		stable_value(card.ability, 2),
	}, "|")
end

local function card_list_signature(label, cards)
	local pieces = { label, tostring(cards and #cards or 0) }
	if cards then
		for i, card in ipairs(cards) do
			pieces[#pieces + 1] = tostring(i) .. ":" .. card_signature(card)
		end
	end
	return table.concat(pieces, ";")
end

local function area_cards(area)
	return area and area.cards or nil
end

local function card_identity(card)
	if not card then return "nil" end
	return tostring(card.sort_id or card.unique_val or card.ID or card)
end

local function card_identity_list_signature(label, cards)
	local pieces = { label, tostring(cards and #cards or 0) }
	if cards then
		for i, card in ipairs(cards) do
			pieces[#pieces + 1] = tostring(i) .. ":" .. card_identity(card)
		end
	end
	return table.concat(pieces, ";")
end

function CALC.current_request_guard_signature()
	return table.concat({
		"rev=" .. tostring(CALC.cache_revision or 0),
		"state=" .. tostring(G and G.STATE or ""),
		card_identity_list_signature("highlighted", G and G.hand and G.hand.highlighted),
		card_identity_list_signature("hand", area_cards(G and G.hand)),
		card_identity_list_signature("jokers", area_cards(G and G.jokers)),
		card_identity_list_signature("consumeables", area_cards(G and G.consumeables)),
	}, "\n")
end

function CALC.invalidate_cache(status)
	CALC.cache_revision = (CALC.cache_revision or 0) + 1
	CALC.last_signature = nil
	CALC.last_result = nil
	CALC.calculation_text = nil
	CALC.display_result = nil
	CALC.display_signature = nil
	CALC.show_result = false
	CALC.status = status or (has_selected_cards() and "dirty" or "idle")
	if type(CALC.refresh_display) == "function" then CALC.refresh_display() end
end

function CALC.current_result(signature)
	if CALC.exact_result and G and G.hand and G.hand.highlighted and #G.hand.highlighted == 0 then
		CALC.status = "idle"
		return CALC.exact_result(0, 0)
	end
	signature = signature or CALC.current_signature()
	if CALC.last_result ~= nil and CALC.last_signature == signature then
		CALC.status = "ready"
		return CALC.last_result
	end
	return nil
end

function CALC.current_signature()
	local game = G and G.GAME or {}
	local blind = game.blind or {}
	local parts = {
		"rev=" .. tostring(CALC.cache_revision or 0),
		"state=" .. tostring(G and G.STATE or ""),
		"dollars=" .. stable_value(game.dollars, 1),
		"probability=" .. stable_value(game.probabilities and game.probabilities.normal, 1),
		"blind=" .. stable_value({ key = blind.config and blind.config.blind and blind.config.blind.key, chips = blind.chips, disabled = blind.disabled }, 2),
		"hands=" .. stable_value(game.hands, 2),
		card_list_signature("highlighted", G.hand and G.hand.highlighted),
		card_list_signature("hand", area_cards(G.hand)),
		card_list_signature("jokers", area_cards(G.jokers)),
		card_list_signature("consumeables", area_cards(G.consumeables)),
	}
	return table.concat(parts, "\n")
end

function CALC.finish(ok, result, reason)
	CALC.queued = false
	CALC.active_request_signature = nil
	CALC.calculation_text = nil

	if ok and result ~= nil and not result.unsupported then
		CALC.status = "ready"
		CALC.display_result = result
		CALC.display_signature = CALC.last_signature
		CALC.show_result = true
		if type(CALC.refresh_display) == "function" then CALC.refresh_display() end
		return
	end

	CALC.status = "unsupported"
	CALC.display_result = nil
	CALC.display_signature = nil
	CALC.show_result = true
	if type(CALC.refresh_display) == "function" then CALC.refresh_display() end
end

function CALC.request()
	if CALC.queued then return end
	if not CALC.enabled() then return end
	if type(CALC.integration_enabled) == "function" and not CALC.integration_enabled() then return end

	local signature = nil
	local cached_result = nil
	if type(CALC.current_result) == "function" then
		if has_selected_cards() then
			signature = CALC.current_signature()
			cached_result = CALC.current_result(signature)
		else
			cached_result = CALC.current_result()
		end
	end
	if cached_result ~= nil then
		CALC.status = "ready"
		CALC.display_result = cached_result
		CALC.display_signature = CALC.last_signature
		CALC.show_result = true
		if type(CALC.refresh_display) == "function" then CALC.refresh_display() end
		return
	end

	signature = signature or CALC.current_signature()
	local request_guard_signature = CALC.current_request_guard_signature()
	CALC.queued = true
	CALC.active_request_signature = signature
	CALC.set_calculation_wait_text()
	CALC.status = "calculating"
	CALC.display_result = nil
	CALC.display_signature = nil
	CALC.show_result = true
	if type(CALC.refresh_display) == "function" then CALC.refresh_display() end

	local function finish_for_signature(result, reason)
		if CALC.active_request_signature ~= signature then return end
		if request_guard_signature ~= CALC.current_request_guard_signature() then
			CALC.queued = false
			CALC.active_request_signature = nil
			CALC.calculation_text = nil
			CALC.status = has_selected_cards() and "dirty" or "idle"
			CALC.display_result = nil
			CALC.display_signature = nil
			CALC.show_result = false
			if type(CALC.refresh_display) == "function" then CALC.refresh_display() end
			return
		end

		if result ~= nil and not result.unsupported then
			CALC.last_signature = signature
			CALC.last_result = result
			CALC.finish(true, result)
			return
		end

		if result ~= nil and result.unsupported then
			CALC.finish(true, nil, result.reason)
			return
		end

		CALC.finish(false, reason)
	end

	if type(CALC.run_native_exact_async) ~= "function" then
		CALC.finish(false, "experimental exact backend is not loaded")
		return
	end

	local function start_backend()
		if CALC.active_request_signature ~= signature then return true end

		local ok, started_or_reason = pcall(CALC.run_native_exact_async, finish_for_signature)
		if ok and started_or_reason then return true end
		CALC.finish(false, ok and (started_or_reason or "experimental exact backend did not start") or started_or_reason)
		return true
	end

	local delay = calculation_start_delay()
	if delay <= 0 or not (G and G.E_MANAGER and Event) then
		start_backend()
		return
	end

	G.E_MANAGER:add_event(Event({ trigger = "after", blockable = false, blocking = false, delay = delay, func = start_backend }))
end
