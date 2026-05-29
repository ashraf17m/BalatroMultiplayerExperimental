MP.SYNC = MP.SYNC or {}

local team_card_sync = MP.SYNC.TEAM_CARD or {}
MP.SYNC.TEAM_CARD = team_card_sync
MP.TEAM_CARD = team_card_sync

if team_card_sync._apply_loaded then
	return
end
team_card_sync._apply_loaded = true

MP.TEAM_CARD_SUSPENDED = MP.TEAM_CARD_SUSPENDED or false
local BALATRO = MP.PLATFORM.BALATRO

local is_applying_remote_change = false
local TEAM_CARD_SYNC_RETRY_DELAY = 0.35
local TEAM_CARD_SYNC_MAX_RETRIES = 2
local removal_retry_by_card_id = {}

local require_snapshot_api = assert(team_card_sync.require_snapshot_api, "Team card sync snapshot API missing: require_snapshot_api")
local get_card_by_id = require_snapshot_api("get_card_by_id")
local encode_snapshot = require_snapshot_api("encode_snapshot")
local decode_snapshot_data = require_snapshot_api("decode_snapshot_data")
local apply_snapshot_to_card = require_snapshot_api("apply_snapshot_to_card")
local get_card_snapshot = require_snapshot_api("get_card_snapshot")

local function is_team_card_sync_active()
	return BALATRO.is_run_stage()
		and MP.is_teams_mode()
		and MP.LOBBY
		and MP.LOBBY.code
		and not MP.TEAM_CARD_INITIALIZING
		and not MP.TEAM_CARD_SUSPENDED
		and not BALATRO.is_game_over_or_win()
		and not (MP.GAME and MP.GAME.won)
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

function team_card_sync.is_applying_remote_change()
	return is_applying_remote_change
end

function team_card_sync.can_relay_changes()
	return not is_applying_remote_change and is_team_card_sync_active()
end

local function is_relayable_synced_team_card(card)
	return card and card.mp_card_id and card.mp_synced_as_added
end

local function clear_sync_retry_state(card)
	if not card then
		return
	end

	card.mp_team_card_sync_retry_pending = nil
	card.mp_team_card_sync_retry_count = nil
end

local function cancel_sync_retry(card)
	if not card then
		return
	end

	card.mp_team_card_sync_retry_cancelled = true
	card.mp_team_card_sync_retry_pending = nil
end

local function clear_removal_retry_state(card_id)
	if card_id == nil then
		return
	end

	removal_retry_by_card_id[tostring(card_id)] = nil
end

local function build_team_card_payload(card, action_type, card_data)
	if not team_card_sync.can_relay_changes() or not is_relayable_synced_team_card(card) then
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

local function schedule_sync_retry(card)
	if
		not (
			card
			and is_relayable_synced_team_card(card)
			and not card.mp_team_card_sync_retry_cancelled
			and not card.mp_team_card_sync_retry_pending
			and BALATRO.queue_event
		)
	then
		return false
	end

	local retry_count = tonumber(card.mp_team_card_sync_retry_count) or 0
	if retry_count >= TEAM_CARD_SYNC_MAX_RETRIES then
		return false
	end

	card.mp_team_card_sync_retry_count = retry_count + 1
	card.mp_team_card_sync_retry_pending = true

	BALATRO.queue_event({
		trigger = "after",
		delay = TEAM_CARD_SYNC_RETRY_DELAY,
		func = function()
			card.mp_team_card_sync_retry_pending = nil
			if not card.mp_team_card_sync_retry_cancelled then
				team_card_sync.sync(card)
			end
			return true
		end,
	})

	return true
end

local function schedule_removal_retry(payload)
	if not (payload and payload.card_id and payload.action_type == "removed" and BALATRO.queue_event) then
		return false
	end

	local card_id = tostring(payload.card_id)
	local retry_state = removal_retry_by_card_id[card_id] or { count = 0 }
	if retry_state.pending then
		return false
	end

	if retry_state.count >= TEAM_CARD_SYNC_MAX_RETRIES then
		clear_removal_retry_state(card_id)
		return false
	end

	retry_state.count = retry_state.count + 1
	retry_state.pending = true
	removal_retry_by_card_id[card_id] = retry_state

	BALATRO.queue_event({
		trigger = "after",
		delay = TEAM_CARD_SYNC_RETRY_DELAY,
		func = function()
			local current_retry_state = removal_retry_by_card_id[card_id]
			if not current_retry_state then
				return true
			end

			current_retry_state.pending = false
			if not team_card_sync.can_relay_changes() then
				clear_removal_retry_state(card_id)
				return true
			end

			if team_card_sync.relay_payload(payload) then
				clear_removal_retry_state(card_id)
			else
				schedule_removal_retry(payload)
			end
			return true
		end,
	})

	return true
end

function team_card_sync.build_snapshot_payload(card)
	if not is_relayable_synced_team_card(card) then
		return nil
	end

	local snapshot = get_card_snapshot(card)
	local encoded = encode_snapshot(snapshot)
	if not encoded or card.mp_last_sync_raw == encoded then
		return nil
	end

	return build_team_card_payload(card, "sync", encoded)
end

function team_card_sync.sync(card)
	local payload = team_card_sync.build_snapshot_payload(card)
	if not payload then
		return false
	end

	if not team_card_sync.relay_payload(payload) then
		schedule_sync_retry(card)
		return false
	end

	clear_sync_retry_state(card)
	card.mp_last_sync_raw = payload.card_data
	return true
end

function team_card_sync.build_removal_payload(card)
	return build_team_card_payload(card, "removed", nil)
end

function team_card_sync.relay_removal(card)
	cancel_sync_retry(card)
	local payload = team_card_sync.build_removal_payload(card)
	if team_card_sync.relay_payload(payload) then
		clear_removal_retry_state(payload and payload.card_id)
		return true
	end

	schedule_removal_retry(payload)
	return false
end

local function create_remote_team_card_target(card_id, snapshot)
	local key = team_card_sync.snapshot_to_base_key(snapshot)
	if not key then
		return nil
	end

	local target = BALATRO.create_playing_card({
		front = BALATRO.get_card_front(key),
		center = BALATRO.get_center(snapshot.ak or "c_base") or BALATRO.get_center("c_base"),
	}, BALATRO.get_deck_area())
	target.mp_card_id = card_id
	target.mp_synced_as_added = true
	return target
end

local function ensure_remote_team_card_target(card_id, snapshot)
	local target = get_card_by_id(card_id)
	if target then
		return target
	end

	return create_remote_team_card_target(card_id, snapshot)
end

local function enqueue_remote_team_card_change(apply_fn)
	if not apply_fn then
		return false
	end

	BALATRO.queue_event({
		trigger = "after",
		delay = 0,
		func = function()
			apply_remote_change(apply_fn)
			return true
		end,
	})

	return true
end

local function apply_remote_team_card_removal(card)
	if not card then
		return false
	end

	return enqueue_remote_team_card_change(function()
		card:remove()
	end)
end

local function apply_remote_team_card_snapshot(card_id, snapshot)
	return enqueue_remote_team_card_change(function()
		local target = ensure_remote_team_card_target(card_id, snapshot)
		if target and target.area and target.base then
			apply_snapshot_to_card(target, snapshot)
		end
	end)
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
	if not is_team_card_sync_active() or not data.cardKey then return end
	local id = data.cardKey
	local card = get_card_by_id(id)

	if data.actionType == "removed" then
		apply_remote_team_card_removal(card)
		return
	end

	local snapshot = decode_snapshot_data(data.cardData)
	if not snapshot then return end

	apply_remote_team_card_snapshot(id, snapshot)
end
