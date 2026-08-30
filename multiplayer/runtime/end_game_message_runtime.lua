MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}

local end_game_message_runtime = {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local load_required_service = MP.UTILS.load_required_service

local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end
local last_sent_summary_signature = nil

local END_GAME_VIEW_METHODS = {
	"get_end_game_view_runtime",
	"fail_end_game_view_request",
	"resolve_end_game_view_response_target",
	"apply_end_game_view_response",
	"apply_end_game_summary",
	"get_target_jokers_label",
}

local function get_true_flag_key(tbl)
	for key, value in pairs(tbl or {}) do
		if value == true or tostring(value) == "true" then
			return key
		end
	end
	return nil
end

local function card_to_string(card)
	if not card or not card.base or not card.base.suit or not card.base.value then return "" end

	local suit = string.sub(card.base.suit, 1, 1)

	local rank_value_map = {
		["10"] = "T",
		Jack = "J",
		Queen = "Q",
		King = "K",
		Ace = "A",
	}
	local rank = rank_value_map[card.base.value] or card.base.value

	local enhancement = BALATRO.get_center_key and BALATRO.get_center_key(card.config.center) or "none"
	local edition = get_true_flag_key(card.edition) or "none"
	local seal = card.seal or "none"

	return suit .. "-" .. rank .. "-" .. enhancement .. "-" .. edition .. "-" .. seal
end

local function copy_array(source)
	local result = {}
	for _, value in ipairs(source or {}) do
		result[#result + 1] = value
	end
	return result
end

local function get_round_score_amount(score_key, fallback)
	local round_scores = G and G.GAME and G.GAME.round_scores or nil
	local score = round_scores and round_scores[score_key] or nil
	return tonumber(score and score.amt) or fallback or 0
end

local function get_current_ante()
	return tonumber(G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante)
		or get_round_score_amount("furthest_ante", 0)
end

local function get_current_round()
	return tonumber(G and G.GAME and G.GAME.round) or get_round_score_amount("furthest_round", 0)
end

local function get_current_hand_key()
	local game = G and G.GAME or nil
	local current_hand = game and game.current_round and game.current_round.current_hand or nil
	local hand_key = current_hand and current_hand.handname or nil
	if type(hand_key) == "string" and hand_key ~= "" and game and game.hands and game.hands[hand_key] then
		return hand_key
	end
	return nil
end

local function get_ordered_hand_keys(game)
	local keys = {}
	for _, key in ipairs((G and G.handlist) or {}) do
		if game and game.hands and game.hands[key] then
			keys[#keys + 1] = key
		end
	end
	for key in pairs((game and game.hands) or {}) do
		local seen = false
		for _, existing in ipairs(keys) do
			if existing == key then
				seen = true
				break
			end
		end
		if not seen then keys[#keys + 1] = key end
	end
	return keys
end

local function get_most_played_hand()
	local game = G and G.GAME or nil
	local round = game and game.current_round or nil
	local round_hand = round and round.most_played_poker_hand or nil
	local current_hand = get_current_hand_key()

	local best_hand_key = nil
	local best_hand_count = 0
	for _, key in ipairs(get_ordered_hand_keys(game)) do
		local hand = game.hands[key]
		local count = tonumber(hand and (hand.played or hand.count)) or 0
		if count > best_hand_count
			or (
				count == best_hand_count
				and count > 0
				and (key == current_hand or (not current_hand and key == round_hand))
			)
		then
			best_hand_count = count
			best_hand_key = key
		end
	end
	for key, hand in pairs((game and game.hand_usage) or {}) do
		local count = tonumber(hand and (hand.count or hand.played)) or 0
		if count > best_hand_count then
			best_hand_count = count
			best_hand_key = key
		end
	end
	return best_hand_key, best_hand_count
end

local function build_local_end_game_summary()
	local stats = MP.GAME and MP.GAME.stats or {}
	local poker_hand, poker_hand_count = get_most_played_hand()
	local reroll_count = get_round_score_amount("times_rerolled", tonumber(stats.reroll_count) or 0)
	local reroll_cost_total = tonumber(stats.reroll_cost_total) or 0
	local total_money_spent = tonumber(stats.total_money_spent) or reroll_cost_total

	return {
		version = 1,
		hand = get_round_score_amount("hand", 0),
		poker_hand = poker_hand,
		poker_hand_count = poker_hand_count,
		cards_purchased = get_round_score_amount("cards_purchased", 0),
		times_rerolled = reroll_count,
		furthest_ante = get_current_ante(),
		furthest_round = get_current_round(),
		reroll_cost_total = reroll_cost_total,
		total_money_spent = total_money_spent,
		vouchers_bought = copy_array(stats.vouchers_bought),
		seed = tostring(G and G.GAME and G.GAME.pseudorandom and G.GAME.pseudorandom.seed or ""),
		seeded = not not (G and G.GAME and G.GAME.seeded),
	}
end

local function encode_local_end_game_summary(summary)
	return MP.UTILS.str_pack_and_encode(summary or build_local_end_game_summary(), "end_game.summary")
end

local function join_summary_vouchers(vouchers)
	local parts = {}
	for _, voucher in ipairs(vouchers or {}) do
		parts[#parts + 1] = tostring(voucher)
	end
	return table.concat(parts, "|")
end

local function build_summary_signature(summary)
	summary = summary or {}
	return table.concat({
		tostring(summary.version or ""),
		tostring(summary.hand or ""),
		tostring(summary.poker_hand or ""),
		tostring(summary.poker_hand_count or ""),
		tostring(summary.cards_purchased or ""),
		tostring(summary.times_rerolled or ""),
		tostring(summary.furthest_ante or ""),
		tostring(summary.furthest_round or ""),
		tostring(summary.reroll_cost_total or ""),
		tostring(summary.total_money_spent or ""),
		join_summary_vouchers(summary.vouchers_bought),
		tostring(summary.seed or ""),
		tostring(summary.seeded == true),
	}, "\31")
end

local function has_summary_channel()
	return not not (MP.LOBBY and MP.LOBBY.code and MP.GAME)
end

local function ensure_end_game_view_runtime()
	return load_required_service(
		"multiplayer/runtime/end_game_view_runtime.lua",
		END_GAME_VIEW_METHODS,
		"Multiplayer end-game view runtime service is missing.",
		function()
			return MP.UI
		end
	)
end

local function get_target_jokers_label(ui)
	if ui and ui.get_target_jokers_label then
		return ui.get_target_jokers_label()
	end
	return localize("k_enemy_jokers")
end

local function with_phantom_sync_suppressed(callback)
	local content_runtime = MP.CONTENT and MP.CONTENT.RUNTIME or nil
	if content_runtime and content_runtime.with_phantom_sync_suppressed then
		return content_runtime.with_phantom_sync_suppressed(callback)
	end
	return callback()
end

local function mark_end_game_preview_cards(card_area)
	if not card_area then return end
	card_area.mp_end_game_preview = true
	for _, card in ipairs(card_area.cards or {}) do
		card.mp_end_game_preview = true
	end
end

local function report_end_game_view_failure(state_kind, issue_kind, target_id, message, details, on_failed_runtime_target)
	trace_runtime_event("end_game.load_failed", {
		target_id = target_id,
		state_kind = state_kind,
		issue_kind = issue_kind,
		details = details,
	})

	local ui = ensure_end_game_view_runtime()
	if ui and ui.fail_end_game_view_request then
		ui.fail_end_game_view_request(target_id, state_kind, message)
	end

	local end_game_view = ui and ui.get_end_game_view_runtime and ui.get_end_game_view_runtime() or nil
	if
		end_game_view
		and end_game_view.target_id == target_id
		and on_failed_runtime_target
	then
		on_failed_runtime_target(end_game_view)
	end

	if MP.NETWORKING_INTERNAL.report_feature_runtime_issue then
		MP.NETWORKING_INTERNAL.report_feature_runtime_issue(
			issue_kind,
			message,
			details,
			{ show_overlay = false }
		)
	end
end

local function report_end_game_jokers_failure(target_id, details)
	report_end_game_view_failure(
		"jokers",
		"end_game_jokers",
		target_id,
		"Could not load this player's end-game jokers.",
		details,
		function(end_game_view)
			end_game_view.showing_own_jokers = false
			end_game_view.jokers_text = get_target_jokers_label(ensure_end_game_view_runtime()) .. " (Unavailable)"
		end
	)
end

BALATRO.set_ui_function("load_end_game_jokers", function()
	local ui = ensure_end_game_view_runtime()
	local card_area_save, success, err
	local end_game_view = ui and ui.get_end_game_view_runtime and ui.get_end_game_view_runtime() or nil
	local target_id = end_game_view and end_game_view.target_id or nil

	if not end_game_view or not end_game_view.jokers_area or not end_game_view.jokers_payload then
		return
	end
	if end_game_view.jokers_payload == "" then
		return
	end

	end_game_view.jokers_area.mp_end_game_preview = true
	card_area_save, err = MP.UTILS.str_decode_and_unpack(end_game_view.jokers_payload, "end_game.jokers")
	if not card_area_save then
		report_end_game_jokers_failure(target_id, string.format("Failed to unpack player jokers: %s", err))
		return
	end

	success, err = pcall(function()
		return with_phantom_sync_suppressed(function()
			return end_game_view.jokers_area:load(card_area_save)
		end)
	end)
	if not success then
		report_end_game_jokers_failure(target_id, string.format("Failed to load player jokers: %s", err))
		with_phantom_sync_suppressed(function()
			end_game_view.jokers_area:remove()
		end)
		local joker_slots = BALATRO.get_starting_joker_slots and BALATRO.get_starting_joker_slots() or 0
		end_game_view.jokers_area:init(
			---@diagnostic disable-next-line: param-type-mismatch
			0,
			0,
			5 * (BALATRO.get_card_width and BALATRO.get_card_width() or 0),
			BALATRO.get_card_height and BALATRO.get_card_height() or 0,
			{ card_limit = joker_slots, type = "joker", highlight_limit = 1 }
		)
		end_game_view.jokers_area.mp_end_game_preview = true
		return
	end

	mark_end_game_preview_cards(end_game_view.jokers_area)
	end_game_view.showing_own_jokers = false
	end_game_view.jokers_text = get_target_jokers_label(ui)

	trace_runtime_event("end_game.jokers_load_complete", {
		target_id = target_id,
	})
end)

local function report_nemesis_deck_failure(target_id, details)
	report_end_game_view_failure(
		"deck",
		"nemesis_deck",
		target_id,
		"Could not load this player's deck.",
		details
	)
end

BALATRO.set_ui_function("load_nemesis_deck", function()
	local ui = ensure_end_game_view_runtime()
	local end_game_view = ui and ui.get_end_game_view_runtime and ui.get_end_game_view_runtime() or nil
	local target_id = end_game_view and end_game_view.target_id or nil
	if
		not end_game_view
		or not end_game_view.nemesis_deck_string
		or not (MP.LOBBY and MP.LOBBY.code)
	then
		return
	end

	local card_strings = MP.UTILS.string_split(end_game_view.nemesis_deck_string, ";")
	local non_empty_entries = 0
	local invalid_front_keys = 0

	for _, card_str in pairs(card_strings) do
		if card_str == "" then
			goto continue
		end
		non_empty_entries = non_empty_entries + 1

		local card_params = MP.UTILS.string_split(card_str, "-")
		local suit = card_params[1]
		local rank = card_params[2]

		local front_key = tostring(suit) .. "_" .. tostring(rank)
		if not BALATRO.get_card_front(front_key) then
			sendDebugMessage(string.format("Invalid playing card key: %s", front_key), "MULTIPLAYER")
			invalid_front_keys = invalid_front_keys + 1
		end

		::continue::
	end

	local valid_cards = non_empty_entries - invalid_front_keys
	end_game_view.nemesis_deck_card_count = valid_cards

	if non_empty_entries > 0 and valid_cards == 0 then
		report_nemesis_deck_failure(
			target_id,
			string.format("Nemesis deck payload contained %s entries but none could be loaded.", tostring(non_empty_entries))
		)
		return
	end

	if invalid_front_keys > 0 then
		sendWarnMessage(
			string.format("Nemesis deck skipped %s invalid playing cards.", tostring(invalid_front_keys)),
			"MULTIPLAYER"
		)
	end
	trace_runtime_event("end_game.deck_load_complete", {
		target_id = target_id,
		loaded_cards = valid_cards,
		payload_cards = non_empty_entries,
		invalid_front_keys = invalid_front_keys,
		materialized = false,
	})
end)

BALATRO.set_ui_function("load_end_game_summary", function()
	local ui = ensure_end_game_view_runtime()
	local end_game_view = ui and ui.get_end_game_view_runtime and ui.get_end_game_view_runtime() or nil
	local target_id = end_game_view and end_game_view.target_id or nil
	if
		not end_game_view
		or not end_game_view.summary_payload
		or end_game_view.summary_payload == ""
	then
		return
	end

	local summary, err = MP.UTILS.str_decode_and_unpack(end_game_view.summary_payload, "end_game.summary")
	if not summary then
		report_end_game_view_failure(
			"summary",
			"end_game_summary",
			target_id,
			"Could not load this player's end-game summary.",
			string.format("Failed to unpack player summary: %s", err)
		)
		return
	end

	if ui and ui.apply_end_game_summary then
		ui.apply_end_game_summary(summary, target_id)
	end

	trace_runtime_event("end_game.summary_load_complete", {
		target_id = target_id,
	})
end)

function end_game_message_runtime.cache_local_end_game_state()
	end_game_message_runtime.handle_get_end_game_jokers(nil)
	end_game_message_runtime.handle_get_nemesis_deck(nil)
	end_game_message_runtime.cache_local_end_game_summary()
end

local function cache_local_final_payload(request_kind, payload, source_player_id, requester_player_id)
	if requester_player_id ~= nil then
		return
	end
	if not source_player_id then
		return
	end
	end_game_message_runtime.apply_received_end_game_payload(request_kind, payload, source_player_id)
end

function end_game_message_runtime.cache_local_end_game_summary()
	return end_game_message_runtime.send_end_game_summary_update(true)
end

function end_game_message_runtime.reset_end_game_summary_updates()
	last_sent_summary_signature = nil
end

function end_game_message_runtime.send_end_game_summary_update(force, options)
	options = options or {}
	if MP.SPECTATOR and MP.SPECTATOR.is_spectating then
		return false
	end
	local source_player_id = BALATRO.get_player_id and BALATRO.get_player_id() or nil
	local summary = build_local_end_game_summary()
	local summary_encoded = encode_local_end_game_summary(summary)
	cache_local_final_payload("summary", summary_encoded, source_player_id, nil)

	local signature = build_summary_signature(summary)
	local changed = force == true or signature ~= last_sent_summary_signature
	if changed then
		last_sent_summary_signature = signature
	end

	local queued = false
	if
		changed
		and options.cache_only ~= true
		and not (MP.SPECTATOR and MP.SPECTATOR.is_spectating)
		and has_summary_channel()
		and MP.ACTIONS
		and MP.ACTIONS.send_end_game_summary
	then
		queued = MP.ACTIONS.send_end_game_summary(summary_encoded) ~= false
	end

	trace_runtime_event("end_game.summary_local_cache", {
		source_player_id = source_player_id,
		has_payload = summary_encoded ~= "",
		changed = changed,
		queued = queued,
	})
	return summary_encoded ~= ""
end

function end_game_message_runtime.handle_get_end_game_jokers(requester_player_id)
	trace_runtime_event("end_game.jokers_request_received", {
		requester_player_id = requester_player_id,
	})
	local source_player_id = BALATRO.get_player_id and BALATRO.get_player_id() or nil
	local joker_cards = BALATRO.get_joker_cards and BALATRO.get_joker_cards() or nil
	if not joker_cards then
		trace_runtime_event("end_game.jokers_response_send", {
			requester_player_id = requester_player_id,
			empty = true,
		})
		cache_local_final_payload("jokers", "", source_player_id, requester_player_id)
		Client.send(MP.FEATURE_WIRE.build_receive_end_game_jokers_payload(
			"",
			source_player_id,
			requester_player_id
		))
		return
	end

	local jokers_save = BALATRO.save_card_area(BALATRO.get_root() and BALATRO.get_root().jokers or nil)
	local jokers_encoded = MP.UTILS.str_pack_and_encode(jokers_save, "end_game.jokers")

	cache_local_final_payload("jokers", jokers_encoded, source_player_id, requester_player_id)
	Client.send(MP.FEATURE_WIRE.build_receive_end_game_jokers_payload(
		jokers_encoded,
		source_player_id,
		requester_player_id
	))
	trace_runtime_event("end_game.jokers_response_send", {
		requester_player_id = requester_player_id,
		empty = false,
	})
end

local function apply_received_payload_to_active_view(
	request_kind,
	payload,
	source_player_id,
	received_trace_event,
	not_applied_trace_event
)
	trace_runtime_event(received_trace_event, {
		source_player_id = source_player_id,
		has_payload = payload ~= nil and payload ~= "",
	})
	local applied_to_runtime, active_view, response_outcome = end_game_message_runtime.apply_received_end_game_payload(
		request_kind,
		payload,
		source_player_id
	)
	if not applied_to_runtime then
		if response_outcome ~= "cached" then
			trace_runtime_event(not_applied_trace_event, {
				source_player_id = source_player_id,
				outcome = response_outcome,
			})
		end
		return nil
	end

	return active_view
end

function end_game_message_runtime.handle_receive_end_game_jokers(keys, source_player_id)
	local active_view = apply_received_payload_to_active_view(
		"jokers",
		keys,
		source_player_id,
		"end_game.jokers_response_received",
		"end_game.jokers_response_not_applied"
	)
	if not active_view then
		return
	end

	active_view.showing_own_jokers = false
	active_view.jokers_text = get_target_jokers_label(ensure_end_game_view_runtime())
	BALATRO.call_ui_function("load_end_game_jokers")
end

function end_game_message_runtime.apply_received_end_game_payload(request_kind, payload, source_player_id)
	local ui = ensure_end_game_view_runtime()
	if not (ui and ui.resolve_end_game_view_response_target and ui.apply_end_game_view_response) then
		trace_runtime_event("end_game.response_blocked", {
			request_kind = request_kind,
			source_player_id = source_player_id,
			reason = "missing_view_runtime",
		})
		return false, nil, "blocked"
	end

	local target_id = ui.resolve_end_game_view_response_target(request_kind, source_player_id)
	if not target_id then
		trace_runtime_event("end_game.response_blocked", {
			request_kind = request_kind,
			source_player_id = source_player_id,
			reason = "missing_target",
		})
		return false, nil, "blocked"
	end

	local applied, applied_to_runtime, active_view = ui.apply_end_game_view_response(
		target_id,
		request_kind,
		payload,
		source_player_id
	)
	if not applied then
		trace_runtime_event("end_game.response_not_runtime_applied", {
			request_kind = request_kind,
			source_player_id = source_player_id,
			target_id = target_id,
			applied = applied,
			applied_to_runtime = applied_to_runtime,
		})
		return false, active_view, "not_applied"
	end

	if not applied_to_runtime then
		return false, active_view, "cached"
	end

	return true, active_view, "applied"
end

function end_game_message_runtime.handle_get_nemesis_deck(requester_player_id)
	trace_runtime_event("end_game.deck_request_received", {
		requester_player_id = requester_player_id,
	})
	local source_player_id = BALATRO.get_player_id and BALATRO.get_player_id() or nil
	local deck_str = ""
	for _, card in ipairs((BALATRO.get_playing_cards and BALATRO.get_playing_cards()) or {}) do
		deck_str = deck_str .. ";" .. card_to_string(card)
	end
	cache_local_final_payload("deck", deck_str, source_player_id, requester_player_id)
	Client.send(MP.FEATURE_WIRE.build_receive_nemesis_deck_payload(
		deck_str,
		source_player_id,
		requester_player_id
	))
	trace_runtime_event("end_game.deck_response_send", {
		requester_player_id = requester_player_id,
		has_payload = deck_str ~= "",
	})
end

function end_game_message_runtime.handle_receive_nemesis_deck(deck_str, source_player_id)
	local active_view = apply_received_payload_to_active_view(
		"deck",
		deck_str,
		source_player_id,
		"end_game.deck_response_received",
		"end_game.deck_response_not_applied"
	)
	if not active_view then
		return
	end

	BALATRO.call_ui_function("load_nemesis_deck")
end

function end_game_message_runtime.handle_get_end_game_summary(requester_player_id)
	trace_runtime_event("end_game.summary_request_received", {
		requester_player_id = requester_player_id,
	})
	local source_player_id = BALATRO.get_player_id and BALATRO.get_player_id() or nil
	local summary_encoded = encode_local_end_game_summary(build_local_end_game_summary())
	cache_local_final_payload("summary", summary_encoded, source_player_id, requester_player_id)
	Client.send(MP.FEATURE_WIRE.build_receive_end_game_summary_payload(
		summary_encoded,
		source_player_id,
		requester_player_id
	))
	trace_runtime_event("end_game.summary_response_send", {
		requester_player_id = requester_player_id,
		has_payload = summary_encoded ~= "",
	})
end

function end_game_message_runtime.handle_receive_end_game_summary(summary, source_player_id)
	local active_view = apply_received_payload_to_active_view(
		"summary",
		summary,
		source_player_id,
		"end_game.summary_response_received",
		"end_game.summary_response_not_applied"
	)
	if not active_view then
		return
	end

	BALATRO.call_ui_function("load_end_game_summary")
end

MP.NETWORKING_INTERNAL.cache_local_end_game_state = end_game_message_runtime.cache_local_end_game_state
MP.NETWORKING_INTERNAL.reset_end_game_summary_updates = end_game_message_runtime.reset_end_game_summary_updates
MP.NETWORKING_INTERNAL.send_end_game_summary_update = end_game_message_runtime.send_end_game_summary_update
MP.NETWORKING_INTERNAL.handle_get_end_game_jokers = end_game_message_runtime.handle_get_end_game_jokers
MP.NETWORKING_INTERNAL.handle_receive_end_game_jokers = end_game_message_runtime.handle_receive_end_game_jokers
MP.NETWORKING_INTERNAL.handle_get_nemesis_deck = end_game_message_runtime.handle_get_nemesis_deck
MP.NETWORKING_INTERNAL.handle_receive_nemesis_deck = end_game_message_runtime.handle_receive_nemesis_deck
MP.NETWORKING_INTERNAL.handle_get_end_game_summary = end_game_message_runtime.handle_get_end_game_summary
MP.NETWORKING_INTERNAL.handle_receive_end_game_summary = end_game_message_runtime.handle_receive_end_game_summary
