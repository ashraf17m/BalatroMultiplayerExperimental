MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}

local end_game_message_runtime = {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local load_required_service = MP.UTILS.load_required_service

local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end

local END_GAME_VIEW_METHODS = {
	"get_end_game_view_runtime",
	"fail_end_game_view_request",
	"resolve_end_game_view_response_target",
	"apply_end_game_view_response",
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

	card_area_save, err = MP.UTILS.str_decode_and_unpack(end_game_view.jokers_payload, "end_game.jokers")
	if not card_area_save then
		report_end_game_jokers_failure(target_id, string.format("Failed to unpack player jokers: %s", err))
		return
	end

	success, err = pcall(end_game_view.jokers_area.load, end_game_view.jokers_area, card_area_save)
	if not success then
		report_end_game_jokers_failure(target_id, string.format("Failed to load player jokers: %s", err))
		end_game_view.jokers_area:remove()
		local joker_slots = BALATRO.get_starting_joker_slots and BALATRO.get_starting_joker_slots() or 0
		end_game_view.jokers_area:init(
			---@diagnostic disable-next-line: param-type-mismatch
			0,
			0,
			5 * (BALATRO.get_card_width and BALATRO.get_card_width() or 0),
			BALATRO.get_card_height and BALATRO.get_card_height() or 0,
			{ card_limit = joker_slots, type = "joker", highlight_limit = 1 }
		)
		return
	end

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

function end_game_message_runtime.cache_local_end_game_state()
	end_game_message_runtime.handle_get_end_game_jokers(nil)
	end_game_message_runtime.handle_get_nemesis_deck(nil)
end

function end_game_message_runtime.handle_get_end_game_jokers(requester_player_id)
	trace_runtime_event("end_game.jokers_request_received", {
		requester_player_id = requester_player_id,
	})
	local joker_cards = BALATRO.get_joker_cards and BALATRO.get_joker_cards() or nil
	if not joker_cards then
		trace_runtime_event("end_game.jokers_response_send", {
			requester_player_id = requester_player_id,
			empty = true,
		})
		Client.send(MP.FEATURE_WIRE.build_receive_end_game_jokers_payload(
			"",
			BALATRO.get_player_id and BALATRO.get_player_id() or nil,
			requester_player_id
		))
		return
	end

	local jokers_save = BALATRO.save_card_area(BALATRO.get_root() and BALATRO.get_root().jokers or nil)
	local jokers_encoded = MP.UTILS.str_pack_and_encode(jokers_save, "end_game.jokers")

	Client.send(MP.FEATURE_WIRE.build_receive_end_game_jokers_payload(
		jokers_encoded,
		BALATRO.get_player_id and BALATRO.get_player_id() or nil,
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
	local deck_str = ""
	for _, card in ipairs((BALATRO.get_playing_cards and BALATRO.get_playing_cards()) or {}) do
		deck_str = deck_str .. ";" .. card_to_string(card)
	end
	Client.send(MP.FEATURE_WIRE.build_receive_nemesis_deck_payload(
		deck_str,
		BALATRO.get_player_id and BALATRO.get_player_id() or nil,
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

MP.NETWORKING_INTERNAL.cache_local_end_game_state = end_game_message_runtime.cache_local_end_game_state
MP.NETWORKING_INTERNAL.handle_get_end_game_jokers = end_game_message_runtime.handle_get_end_game_jokers
MP.NETWORKING_INTERNAL.handle_receive_end_game_jokers = end_game_message_runtime.handle_receive_end_game_jokers
MP.NETWORKING_INTERNAL.handle_get_nemesis_deck = end_game_message_runtime.handle_get_nemesis_deck
MP.NETWORKING_INTERNAL.handle_receive_nemesis_deck = end_game_message_runtime.handle_receive_nemesis_deck
