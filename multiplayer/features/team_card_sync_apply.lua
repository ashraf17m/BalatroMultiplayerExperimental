MP.SYNC = MP.SYNC or {}

local team_card_sync = MP.SYNC.TEAM_CARD or {}
MP.SYNC.TEAM_CARD = team_card_sync

if team_card_sync._apply_loaded then
	return
end
team_card_sync._apply_loaded = true

MP.TEAM_CARD_SUSPENDED = MP.TEAM_CARD_SUSPENDED or false
local BALATRO = MP.PLATFORM.BALATRO
local diagnostics = team_card_sync.diagnostics or {}

local is_applying_remote_change = false
local removed_card_ids = {}

local require_snapshot_api = assert(team_card_sync.require_snapshot_api, "Team card sync snapshot API missing: require_snapshot_api")
local get_card_by_id = require_snapshot_api("get_card_by_id")
local encode_snapshot = require_snapshot_api("encode_snapshot")
local encode_snapshot_for_compare = require_snapshot_api("encode_snapshot_for_compare")
local decode_snapshot_data = require_snapshot_api("decode_snapshot_data")
local apply_snapshot_to_card = require_snapshot_api("apply_snapshot_to_card")
local get_card_snapshot = require_snapshot_api("get_card_snapshot")
local snapshot_to_center_key = require_snapshot_api("snapshot_to_center_key")
local assign_card_id = require_snapshot_api("assign_card_id")
local mark_card_ready_for_team_sync = require_snapshot_api("mark_card_ready_for_team_sync")
local ensure_card_base_runtime = require_snapshot_api("ensure_card_base_runtime")

local SHARED_INITIAL_CARD_ID_PATTERN = "^TEAM_%d+$"

local function is_team_card_sync_active()
	return BALATRO.is_run_stage()
		and MP.is_shared_card_sync_enabled()
		and MP.LOBBY
		and MP.LOBBY.code
		and not MP.TEAM_CARD_INITIALIZING
		and not MP.TEAM_CARD_SUSPENDED
		and not BALATRO.is_game_over_or_win()
		and not (MP.GAME and MP.GAME.won)
end

local function trace_team_card_sync(event, fields)
	return diagnostics.trace_event and diagnostics.trace_event(event, fields)
end

local function trace_team_card(card, event, fields)
	return diagnostics.trace_card and diagnostics.trace_card(event, card, nil, fields)
end

local function apply_remote_change(fn)
	is_applying_remote_change = true
	local ok, err = pcall(fn)
	is_applying_remote_change = false
	if not ok and sendWarnMessage then
		sendWarnMessage("Team card sync error: " .. tostring(err), "MULTIPLAYER")
	end
	return ok
end

function team_card_sync.is_sync_active()
	return is_team_card_sync_active()
end

function team_card_sync.can_relay_changes()
	return not is_applying_remote_change and is_team_card_sync_active()
end

function team_card_sync.is_applying_remote_change()
	return is_applying_remote_change
end

local function is_card_in_play_area(card)
	local play_area = BALATRO.get_play_area and BALATRO.get_play_area() or nil
	if not (card and play_area) then
		return false
	end
	if card.area == play_area then
		return true
	end
	if type(play_area.cards) ~= "table" then
		return false
	end

	for _, play_card in ipairs(play_area.cards) do
		if play_card == card then
			return true
		end
	end

	return false
end

team_card_sync.is_card_in_play_area = is_card_in_play_area

local function is_playing_card_in_deck_list(card)
	local playing_cards = BALATRO.get_playing_cards and BALATRO.get_playing_cards() or nil
	if not playing_cards then
		return false
	end

	for _, playing_card in ipairs(playing_cards) do
		if playing_card == card then
			return true
		end
	end

	return false
end

local function is_card_removed_or_destroyed(card)
	return card and (card.removed or card.REMOVED or card.destroyed or card.shattered)
end

local function is_live_playing_card_in_deck(card)
	if not card or is_card_removed_or_destroyed(card) then
		return false
	end
	return is_playing_card_in_deck_list(card)
end

local function has_synced_team_card_id(card)
	return card and card.mp_card_id and card.mp_synced_as_added
end

local function is_relayable_synced_team_card(card)
	return has_synced_team_card_id(card) and is_live_playing_card_in_deck(card)
end

local function is_new_unsynced_team_card(card)
	return card and not card.mp_synced_as_added and is_live_playing_card_in_deck(card)
end

local function is_relayable_new_team_card(card)
	return card and card.mp_card_id and is_new_unsynced_team_card(card)
end

local function clear_shared_initial_id_from_new_card(card)
	if card
		and not card.mp_synced_as_added
		and type(card.mp_card_id) == "string"
		and string.match(card.mp_card_id, SHARED_INITIAL_CARD_ID_PATTERN)
	then
		card.mp_card_id = nil
	end
end

local function is_relayable_removed_team_card(card)
	return has_synced_team_card_id(card)
		and not card.removed
		and is_playing_card_in_deck_list(card)
end

local function mark_removed_card_id(card_id)
	if card_id ~= nil then
		removed_card_ids[tostring(card_id)] = true
	end
end

local function is_removed_card_id(card_id)
	return card_id ~= nil and removed_card_ids[tostring(card_id)] == true
end

function team_card_sync.clear_removed_card_ids()
	removed_card_ids = {}
	if team_card_sync.clear_pending_remote_changes then
		team_card_sync.clear_pending_remote_changes()
	end
end

local function build_team_card_payload(card, action_type, card_data)
	local is_relayable = action_type == "removed" and is_relayable_removed_team_card(card)
		or action_type == "sync" and is_relayable_synced_team_card(card)
	if not team_card_sync.can_relay_changes() or not is_relayable then
		return nil
	end

	return {
		card_id = tostring(card.mp_card_id),
		action_type = action_type,
		card_data = card_data,
	}
end

function team_card_sync.relay_payload(payload)
	if not (payload and payload.card_id and MP.ACTIONS and MP.ACTIONS.team_card_sync) then
		return false
	end

	return not not MP.ACTIONS.team_card_sync(payload.card_id, payload.action_type, payload.card_data)
end

local function build_snapshot_data(card, force_send)
	local snapshot = get_card_snapshot(card)
	if not snapshot then
		return nil, nil, "snapshot_missing"
	end

	local encoded = encode_snapshot(snapshot)
	if not encoded then
		return nil, nil, "encode_failed"
	end

	local compare_encoded = encode_snapshot_for_compare(snapshot)
	if not compare_encoded then
		return nil, nil, "compare_encode_failed"
	end

	if not force_send and card.mp_last_sync_raw == compare_encoded then
		return nil, nil, "unchanged"
	end

	return encoded, compare_encoded
end

function team_card_sync.build_snapshot_payload(card)
	if not is_relayable_synced_team_card(card) then
		return nil
	end

	local encoded, compare_encoded = build_snapshot_data(card, false)
	if not encoded then
		return nil
	end

	local payload = build_team_card_payload(card, "sync", encoded)
	if payload then
		payload.compare_data = compare_encoded
	end
	return payload
end

function team_card_sync.sync(card)
	local payload = team_card_sync.build_snapshot_payload(card)
	if not payload then
		return false
	end

	if not team_card_sync.relay_payload(payload) then
		return false
	end

	card.mp_last_sync_raw = payload.compare_data
	return true
end

function team_card_sync.sync_new_card(card)
	trace_team_card(card, "sync_new_start")
	if not team_card_sync.can_relay_changes() then
		trace_team_card_sync("sync_new_blocked", {
			reason = "cannot_relay",
			active = is_team_card_sync_active(),
			applying_remote = is_applying_remote_change,
			suspended = not not MP.TEAM_CARD_SUSPENDED,
			initializing = not not MP.TEAM_CARD_INITIALIZING,
		})
		return false
	end
	if not is_new_unsynced_team_card(card) then
		trace_team_card(card, "sync_new_blocked", { reason = "not_unsynced_real_card" })
		return false
	end

	ensure_card_base_runtime(card)
	clear_shared_initial_id_from_new_card(card)
	assign_card_id(card)
	if not is_relayable_new_team_card(card) then
		trace_team_card(card, "sync_new_blocked", { reason = "not_relayable_after_id" })
		return false
	end

	local encoded, compare_encoded, snapshot_reason = build_snapshot_data(card, true)
	if not encoded then
		trace_team_card(card, "sync_new_blocked", { reason = snapshot_reason or "snapshot_failed" })
		return false
	end

	local payload = {
		card_id = tostring(card.mp_card_id),
		action_type = "sync",
		card_data = encoded,
	}
	if not team_card_sync.relay_payload(payload) then
		trace_team_card(card, "sync_new_blocked", {
			reason = "relay_payload_failed",
			encoded_bytes = #encoded,
		})
		return false
	end

	mark_card_ready_for_team_sync(card)
	card.mp_last_sync_raw = compare_encoded
	trace_team_card_sync("sync_new_sent", {
		card_id = tostring(card.mp_card_id),
		playing_card = card.playing_card or "nil",
		encoded_bytes = #encoded,
	})
	return true
end

function team_card_sync.build_removal_payload(card)
	return build_team_card_payload(card, "removed", nil)
end

function team_card_sync.relay_removal(card)
	if card and card.mp_team_card_suppress_next_removal_relay then
		card.mp_team_card_suppress_next_removal_relay = nil
		return false
	end

	local payload = team_card_sync.build_removal_payload(card)
	return team_card_sync.relay_payload(payload)
end

local function create_remote_team_card_target(card_id, snapshot)
	local key = team_card_sync.snapshot_to_base_key(snapshot)
	if not key then
		trace_team_card_sync("remote_create_blocked", {
			card_id = tostring(card_id or "nil"),
			reason = "missing_base_key",
		})
		return nil
	end

	trace_team_card_sync("remote_create_start", {
		card_id = tostring(card_id or "nil"),
		base_key = tostring(key),
		center_key = tostring(snapshot_to_center_key(snapshot)),
	})
	local target = BALATRO.create_playing_card({
		front = BALATRO.get_card_front(key),
		center = BALATRO.get_center(snapshot_to_center_key(snapshot)) or BALATRO.get_center("c_base"),
	}, BALATRO.get_deck_area())
	target.mp_card_id = card_id
	target.mp_synced_as_added = true
	trace_team_card(target, "remote_create_complete")
	return target
end

local function ensure_remote_team_card_target(card_id, snapshot)
	local target = get_card_by_id(card_id)
	if target then
		return target
	end

	return create_remote_team_card_target(card_id, snapshot)
end

local function card_already_matches_snapshot(card, snapshot)
	local incoming_compare = encode_snapshot_for_compare(snapshot)
	if not incoming_compare then
		return false, nil
	end

	local current_compare = encode_snapshot_for_compare(get_card_snapshot(card))
	return current_compare ~= nil and current_compare == incoming_compare, incoming_compare
end

local function apply_remote_team_card_removal_now(card_id, options)
	local card = get_card_by_id(card_id)
	if not card then
		return false
	end

	if options and options.from_play_flush and is_card_in_play_area(card) and type(card.start_dissolve) == "function" then
		card.mp_team_card_suppress_next_removal_relay = true
		card.destroyed = true
		card:start_dissolve(nil, true)
		return true
	end

	card:remove()
	return true
end

local function apply_remote_team_card_snapshot_now(card_id, snapshot)
	trace_team_card_sync("remote_snapshot_apply_start", {
		card_id = tostring(card_id or "nil"),
		target_exists = not not get_card_by_id(card_id),
	})
	local target = ensure_remote_team_card_target(card_id, snapshot)
	if target and target.area and target.base then
		local already_matches, compare_data = card_already_matches_snapshot(target, snapshot)
		if already_matches then
			target.mp_last_sync_raw = compare_data
			trace_team_card_sync("remote_snapshot_apply_skipped", {
				card_id = tostring(card_id or "nil"),
				reason = "already_matches",
			})
			return true
		end

		apply_snapshot_to_card(target, snapshot)
		trace_team_card(target, "remote_snapshot_applied")
		return true
	end

	trace_team_card_sync("remote_snapshot_apply_blocked", {
		card_id = tostring(card_id or "nil"),
		reason = "missing_target_or_runtime",
		target_exists = not not target,
	})
	return false
end

local apply_remote_team_card_change_now

local function apply_remote_team_card_changes_now(changes, options)
	local applied_count = 0
	apply_remote_change(function()
		for _, change in ipairs(changes) do
			if apply_remote_team_card_change_now(change, options) then
				applied_count = applied_count + 1
			end
		end
	end)
	return applied_count
end

team_card_sync.apply_remote_changes_now = apply_remote_team_card_changes_now

apply_remote_team_card_change_now = function(change, options)
	if change.action_type == "removed" then
		return apply_remote_team_card_removal_now(change.card_id, options)
	end

	if change.snapshot then
		return apply_remote_team_card_snapshot_now(change.card_id, change.snapshot)
	end

	return false
end

local function enqueue_remote_team_card_change(change)
	if not (change and change.card_id and change.action_type) then
		return false
	end

	if team_card_sync.defer_remote_change and team_card_sync.defer_remote_change(change) then
		return true
	end

	local function apply_or_defer()
		if not is_team_card_sync_active() then
			return true
		end

		if team_card_sync.defer_remote_change and team_card_sync.defer_remote_change(change) then
			return true
		end

		apply_remote_change(function()
			apply_remote_team_card_change_now(change)
		end)
		return true
	end

	if not BALATRO.queue_event then
		apply_remote_change(function()
			apply_remote_team_card_change_now(change)
		end)
		return true
	end

	return BALATRO.queue_event({
		trigger = "after",
		delay = 0,
		func = apply_or_defer,
	})
end

local function apply_remote_team_card_removal(card_id)
	return enqueue_remote_team_card_change({
		card_id = card_id,
		action_type = "removed",
	})
end

local function apply_remote_team_card_snapshot(card_id, snapshot)
	return enqueue_remote_team_card_change({
		card_id = card_id,
		action_type = "sync",
		snapshot = snapshot,
	})
end

function team_card_sync.sync_card_list(cards)
	if is_applying_remote_change or not is_team_card_sync_active() or type(cards) ~= "table" then
		return
	end

	local seen = {}
	for _, card in ipairs(cards) do
		if is_relayable_synced_team_card(card) then
			local id = tostring(card.mp_card_id)
			if not seen[id] then
				seen[id] = true
				team_card_sync.sync(card)
			end
		end
	end
end

function team_card_sync.handle_sync(data)
	trace_team_card_sync("remote_sync_received", {
		card_id = data and tostring(data.cardKey or "nil") or "nil",
		action_type = data and tostring(data.actionType or "nil") or "nil",
		active = is_team_card_sync_active(),
		card_data_bytes = data and type(data.cardData) == "string" and #data.cardData or 0,
	})
	if not is_team_card_sync_active() or not data.cardKey then return end
	local id = data.cardKey

	if data.actionType == "removed" then
		mark_removed_card_id(id)
		apply_remote_team_card_removal(id)
		return
	end
	if is_removed_card_id(id) then
		trace_team_card_sync("remote_sync_ignored", {
			card_id = tostring(id),
			reason = "removed_card_id",
		})
		return
	end

	local snapshot = decode_snapshot_data(data.cardData)
	if not snapshot then
		trace_team_card_sync("remote_sync_ignored", {
			card_id = tostring(id),
			reason = "decode_failed",
			card_data_bytes = type(data.cardData) == "string" and #data.cardData or 0,
		})
		return
	end

	apply_remote_team_card_snapshot(id, snapshot)
end
