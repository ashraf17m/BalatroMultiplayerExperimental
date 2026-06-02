-- Calculator V2 diagnostics.
--
-- Writes focused calculator traces to mp_calculator_trace.log when
-- MP.EXPERIMENTAL.calculator_trace_logging is enabled.

MP = MP or {}
MP.CALCULATOR_V2 = MP.CALCULATOR_V2 or {}

local CALC = MP.CALCULATOR_V2

local LOG_FILE = "mp_calculator_trace.log"
local MAX_LOG_BYTES = 2 * 1024 * 1024

local function diagnostics_enabled()
	if MP and MP.EXPERIMENTAL and MP.EXPERIMENTAL.calculator_trace_logging == true then
		return true
	end
	return MP
		and MP.UTILS
		and type(MP.UTILS.is_runtime_trace_enabled) == "function"
		and MP.UTILS.is_runtime_trace_enabled()
end

function CALC.trace_enabled()
	return diagnostics_enabled() == true
end

local function mirror_to_runtime_trace()
	return MP
		and MP.UTILS
		and type(MP.UTILS.is_runtime_trace_enabled) == "function"
		and MP.UTILS.is_runtime_trace_enabled()
end

local function trim_log_if_needed()
	if not (love and love.filesystem and love.filesystem.getInfo and love.filesystem.remove) then
		return
	end

	local ok, info = pcall(love.filesystem.getInfo, LOG_FILE)
	if ok and info and tonumber(info.size) and tonumber(info.size) > MAX_LOG_BYTES then
		pcall(love.filesystem.remove, LOG_FILE)
	end
end

local function append_log(message)
	if not (love and love.filesystem and love.filesystem.append) then
		return false
	end

	trim_log_if_needed()
	local ok = pcall(love.filesystem.append, LOG_FILE, message .. "\n")
	return ok == true
end

local function compact_string(value)
	value = tostring(value)
	value = value:gsub("[\r\n\t]", " ")
	if #value > 180 then
		return value:sub(1, 177) .. "..."
	end
	return value
end

function CALC.score_to_log(value)
	if value == nil then return "nil" end
	if type(number_format) == "function" then
		local ok, formatted = pcall(number_format, value)
		if ok then return compact_string(formatted) end
	end
	return compact_string(value)
end

local function format_value(value)
	local value_type = type(value)
	if value == nil then return "nil" end
	if value_type == "number" or value_type == "boolean" or value_type == "string" then
		return compact_string(value)
	end
	if value_type == "table" then
		return CALC.score_to_log(value)
	end
	return "<" .. value_type .. ">"
end

local function current_state_name()
	if not (G and G.STATE and G.STATES) then return tostring(G and G.STATE or "nil") end
	for name, value in pairs(G.STATES) do
		if value == G.STATE then return name end
	end
	return tostring(G.STATE)
end

function CALC.trace_event(event, fields)
	if not CALC.trace_enabled() then
		return false
	end

	CALC.trace_sequence = (CALC.trace_sequence or 0) + 1
	fields = fields or {}
	fields.seq = CALC.trace_sequence
	fields.request = fields.request or CALC.active_request_id or "none"
	fields.state = fields.state or current_state_name()

	local keys = {}
	for key in pairs(fields) do keys[#keys + 1] = key end
	table.sort(keys)

	local message = "[calculator] " .. tostring(event or "event")
	for _, key in ipairs(keys) do
		message = message .. " " .. tostring(key) .. "=" .. format_value(fields[key])
	end

	local emitted = append_log(message)
	if mirror_to_runtime_trace() and type(sendTraceMessage) == "function" then
		local ok = pcall(sendTraceMessage, message, "MULTIPLAYER")
		emitted = emitted or ok == true
	end
	return emitted
end

local function audit_compact(value)
	value = tostring(value)
	value = value:gsub("[\r\n\t]", " ")
	if #value > 220 then
		return value:sub(1, 217) .. "..."
	end
	return value
end

local function audit_card_key(card)
	if not card then return "nil" end
	local center = card.config and card.config.center
	local base = card.base or {}
	return table.concat({
		tostring(card.sort_id or card.unique_val or card.ID or "?"),
		tostring(center and center.key or "?"),
		tostring(base.value or base.id or "?"),
		tostring(base.suit or "?"),
	}, ":")
end

local function audit_area_name(area)
	if not area then return "nil" end
	if G then
		if area == G.hand then return "hand" end
		if area == G.play then return "play" end
		if area == G.jokers then return "jokers" end
		if area == G.consumeables then return "consumeables" end
		if area == G.deck then return "deck" end
		if area == G.discard then return "discard" end
		if area == G.shop_jokers then return "shop_jokers" end
		if area == G.shop_booster then return "shop_booster" end
		if area == G.shop_vouchers then return "shop_vouchers" end
		if area == G.pack_cards then return "pack_cards" end
	end
	return tostring(area)
end

local function audit_card_list(cards)
	local pieces = { tostring(cards and #cards or 0) }
	for index, card in ipairs(cards or {}) do
		if index > 16 then
			pieces[#pieces + 1] = "..."
			break
		end
		pieces[#pieces + 1] = tostring(index) .. ":" .. audit_card_key(card)
	end
	return table.concat(pieces, ",")
end

local function audit_stable_value(value, depth, seen)
	local value_type = type(value)
	if value == nil or value_type == "number" or value_type == "boolean" or value_type == "string" then
		return audit_compact(value)
	end
	if value_type ~= "table" then return "<" .. value_type .. ">" end
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
	for index, key in ipairs(keys) do
		if index > 24 then
			pieces[#pieces + 1] = "..."
			break
		end
		pieces[#pieces + 1] = tostring(key) .. "=" .. audit_stable_value(value[key], depth - 1, seen)
	end

	seen[value] = nil
	return audit_compact("{" .. table.concat(pieces, ",") .. "}")
end

local function audit_values_equal(left, right)
	if left == right then return true end
	if type(left) == "table" or type(right) == "table" then
		return audit_stable_value(left, 2) == audit_stable_value(right, 2)
	end
	if type(CALC.values_equal) == "function" then
		local ok, equal = pcall(CALC.values_equal, left, right)
		if ok then return equal == true end
	end
	return tostring(left) == tostring(right)
end

local function emit_audit(event, fields)
	if not CALC.trace_enabled() then return false end
	return CALC.trace_event("audit." .. tostring(event), fields)
end

local function compare_value(change, section, name, before, after, depth, extra)
	if audit_values_equal(before, after) then return end
	extra = extra or {}
	extra.section = section
	extra.field = name
	extra.before = audit_stable_value(before, depth or 2)
	extra.after = audit_stable_value(after, depth or 2)
	change(extra)
end

local function compare_snapshot_fields(change, section, snapshot)
	if not (snapshot and type(snapshot.target) == "table") then return end
	for _, field in ipairs(snapshot.fields or {}) do
		local before = snapshot.present and snapshot.present[field] and snapshot.values[field] or nil
		local after = snapshot.target[field]
		compare_value(change, section, field, before, after, snapshot.copy_fields and snapshot.copy_fields[field] and 2 or 1)
	end
end

local CARD_SNAPSHOT_FIELDS = {
	{ "config", "config", 2 },
	{ "ability", "ability", 2 },
	{ "edition", "edition", 2 },
	{ "base", "base", 2 },
	{ "T", "t", 1 },
	{ "VT", "vt", 1 },
	{ "pinch", "pinch", 1 },
	{ "facing", "facing", 1 },
	{ "sprite_facing", "sprite_facing", 1 },
	{ "flipping", "flipping", 1 },
	{ "sell_cost_label", "sell_cost_label", 1 },
	{ "debuff", "debuff", 1 },
	{ "seal", "seal", 1 },
	{ "destroyed", "destroyed", 1 },
	{ "shattered", "shattered", 1 },
	{ "vampired", "vampired", 1 },
	{ "getting_sliced", "getting_sliced", 1 },
	{ "lucky_trigger", "lucky_trigger", 2 },
	{ "highlighted", "highlighted", 1 },
	{ "rank", "rank", 1 },
	{ "sort_id", "sort_id", 1 },
	{ "unique_val", "unique_val", 1 },
	{ "ID", "ID", 1 },
}

local function compare_card_snapshots(change, cards, snapshots)
	for _, card in ipairs(cards or {}) do
		local snapshot = snapshots and snapshots[card] or nil
		if snapshot then
			for _, field in ipairs(CARD_SNAPSHOT_FIELDS) do
				compare_value(change, "card", field[1], snapshot[field[2]], card[field[1]], field[3], {
					card = audit_card_key(card),
				})
			end
			compare_value(change, "card", "area", audit_area_name(snapshot.area), audit_area_name(card.area), 1, {
				card = audit_card_key(card),
			})
			compare_value(change, "card", "parent", audit_area_name(snapshot.parent), audit_area_name(card.parent), 1, {
				card = audit_card_key(card),
			})
			compare_value(change, "card", "layered_parallax", snapshot.layered_parallax, card.layered_parallax, 1, {
				card = audit_card_key(card),
			})
		end
	end
end

local function compare_area_snapshots(change, areas)
	for label, entry in pairs(areas or {}) do
		label = type(label) == "string" and label or audit_area_name(entry.area)
		local before = audit_card_list(entry.cards)
		local after = audit_card_list(entry.area and entry.area.cards)
		compare_value(change, "area", label, before, after, 1)
	end
end

local function compare_globals(change, snapshot)
	for field, before in pairs(snapshot or {}) do
		compare_value(change, "global", field, before, _G[field], 1)
	end
end

local function compare_g_fields(change, snapshot)
	if not G then return end
	for field, before in pairs(snapshot or {}) do
		compare_value(change, "G", field, before, G[field], 1)
	end
end

local function compare_smods_state(change, snapshot)
	if not snapshot or not SMODS then return end
	for _, field in ipairs({
		"no_resolve",
		"displayed_hand",
		"displaying_scoring",
		"current_evaluated_object",
		"context_stack",
		"last_hand",
		"last_hand_oneshot",
		"post_prob",
		"calculation_controls",
	}) do
		local current = field == "calculation_controls" and SMODS.Calculation_Controls or SMODS[field]
		compare_value(change, "SMODS", field, snapshot[field], current, 2)
	end
	for key, before in pairs(snapshot.scoring_parameters or {}) do
		local parameter = SMODS.Scoring_Parameters and SMODS.Scoring_Parameters[key]
		compare_value(change, "SMODS.Scoring_Parameters", key, before, parameter and parameter.current, 1)
	end
end

local function compare_talisman_state(change, snapshot)
	if not (snapshot and G) then return end
	for _, field in ipairs({
		"SCORING_COROUTINE",
		"LAST_SCORING_YIELD",
		"CARD_CALC_COUNTS",
		"CURRENT_SCORING_CARD",
		"SCORING_TEXT",
		"scoring_text",
		"CURRENT_CALC_TIME",
	}) do
		local snapshot_key = ({
			SCORING_COROUTINE = "scoring_coroutine",
			LAST_SCORING_YIELD = "last_scoring_yield",
			CARD_CALC_COUNTS = "card_calc_counts",
			CURRENT_SCORING_CARD = "current_scoring_card",
			SCORING_TEXT = "scoring_text",
			scoring_text = "scoring_text_values",
			CURRENT_CALC_TIME = "current_calc_time",
		})[field]
		compare_value(change, "Talisman.G", field, snapshot[snapshot_key], G[field], 2)
	end

	if not (snapshot.talisman and Talisman) then return end
	for field, before in pairs(snapshot.talisman) do
		if field == "coroutine_aborted" then
			compare_value(change, "Talisman.coroutine", "aborted", before, Talisman.coroutine and Talisman.coroutine.aborted, 1)
		elseif field == "current_calc" then
			compare_value(change, "Talisman", field, before, Talisman.current_calc, 2)
		else
			compare_value(change, "Talisman", field, before, Talisman[field], 2)
		end
	end
end

local function compare_controller_state(change, snapshot)
	local controller = G and G.CONTROLLER
	if not (snapshot and controller) then return end
	for _, field in ipairs({
		"interrupt",
		"focused",
		"dragging",
		"hovering",
		"released_on",
		"cursor_down",
		"cursor_up",
		"cursor_hover",
		"cardarea_context",
		"snap_cursor_to",
		"locked",
	}) do
		compare_value(change, "controller", field, snapshot[field], controller[field], 2)
	end
	compare_value(change, "G", "card_area_focus_reset", snapshot.card_area_focus_reset, G and G.card_area_focus_reset, 2)
	compare_value(change, "G", "boss_throw_hand", snapshot.boss_throw_hand, G and G.boss_throw_hand, 1)
end

function CALC.audit_state_guard_mutations(payload)
	if not CALC.trace_enabled() then return false end
	payload = payload or {}
	CALC.audit_sequence = (CALC.audit_sequence or 0) + 1
	local audit_id = CALC.audit_sequence
	local change_count = 0

	local function change(fields)
		change_count = change_count + 1
		fields.audit = audit_id
		fields.phase = CALC.active_probability_policy or "unknown"
		emit_audit("state_changed", fields)
	end

	emit_audit("state_guard_start", {
		audit = audit_id,
		phase = CALC.active_probability_policy or "unknown",
		body_ok = payload.ok == true,
		selected = payload.ctx and payload.ctx.full_hand and #payload.ctx.full_hand or 0,
		scoring = payload.ctx and payload.ctx.scoring_hand and #payload.ctx.scoring_hand or 0,
		held = payload.ctx and payload.ctx.held_cards and #payload.ctx.held_cards or 0,
	})

	compare_area_snapshots(change, payload.areas)
	compare_value(change, "area", "highlighted", audit_card_list(payload.highlighted), audit_card_list(G and G.hand and G.hand.highlighted), 1)
	compare_card_snapshots(change, payload.cards, payload.card_snapshots)
	compare_snapshot_fields(change, "G.GAME", payload.game_fields)
	compare_snapshot_fields(change, "MP.GAME", payload.mp_money_state)
	compare_value(change, "G.GAME", "hands", payload.hand_state, payload.game and payload.game.hands, 2)
	compare_value(change, "G.GAME", "current_round", payload.current_round_state, payload.game and payload.game.current_round, 2)
	compare_value(
		change,
		"G.GAME.current_round",
		"current_hand",
		payload.current_hand_state and payload.current_hand_state.state,
		payload.game and payload.game.current_round and payload.game.current_round.current_hand,
		2
	)
	if payload.game and payload.blind_fields and payload.game.blind then
		for _, field in ipairs({ "triggered", "prepped", "block_play", "disabled" }) do
			compare_value(change, "blind", field, payload.blind_fields[field], payload.game.blind[field], 1)
		end
		compare_value(change, "blind", "chips", payload.blind_fields.chips, payload.game.blind.chips, 2)
	end
	compare_value(change, "G.GAME", "current_scoring_calculation", payload.current_scoring_calculation, payload.game and payload.game.current_scoring_calculation, 1)
	compare_value(change, "G.GAME", "current_scoring_calculation_key", payload.current_scoring_calculation_key, payload.game and payload.game.current_scoring_calculation_key, 1)
	compare_value(change, "G.GAME", "hyper_operator", payload.hyper_operator, payload.game and payload.game.hyper_operator, 1)
	compare_globals(change, payload.global_fields)
	compare_g_fields(change, payload.g_fields)
	compare_value(change, "G", "SCORE_DISPLAY_QUEUE", payload.score_display_queue, G and G.SCORE_DISPLAY_QUEUE, 2)
	compare_controller_state(change, payload.controller_state)
	compare_smods_state(change, payload.smods_state)
	compare_talisman_state(change, payload.talisman_scoring_state)

	emit_audit("state_guard_done", {
		audit = audit_id,
		phase = CALC.active_probability_policy or "unknown",
		body_ok = payload.ok == true,
		changes = change_count,
		reason = payload.reason or (payload.ok == true and "nil" or tostring(payload.result)),
	})
	return true
end
