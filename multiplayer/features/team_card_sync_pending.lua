MP.SYNC = MP.SYNC or {}

local team_card_sync = MP.SYNC.TEAM_CARD or {}
MP.SYNC.TEAM_CARD = team_card_sync

if team_card_sync._pending_loaded then
	return
end
team_card_sync._pending_loaded = true

local BALATRO = MP.PLATFORM.BALATRO

local TEAM_CARD_REMOTE_APPLY_RETRY_DELAY = 0.1
local pending_remote_changes_by_card_id = {}
local pending_remote_change_order = {}
local pending_remote_flush_scheduled = false

local function is_team_card_sync_active()
	return team_card_sync.is_sync_active and team_card_sync.is_sync_active()
end

local function apply_remote_team_card_changes_now(changes, options)
	if team_card_sync.apply_remote_changes_now then
		return team_card_sync.apply_remote_changes_now(changes, options)
	end

	return 0
end

local function is_local_hand_resolution_active()
	local play_area = BALATRO.get_play_area and BALATRO.get_play_area() or nil
	if play_area and type(play_area.cards) == "table" and #play_area.cards > 0 then
		return true
	end

	local states = BALATRO.get_states and BALATRO.get_states() or nil
	local state = BALATRO.get_state and BALATRO.get_state() or nil
	local hand_area = BALATRO.get_hand_area and BALATRO.get_hand_area() or nil
	local highlighted = hand_area and hand_area.highlighted or nil
	return states and state == states.HAND_PLAYED and type(highlighted) == "table" and #highlighted > 0
end

local function remember_pending_remote_change(change)
	if not (change and change.card_id and change.action_type) then
		return false
	end

	local card_id = tostring(change.card_id)
	if not pending_remote_changes_by_card_id[card_id] then
		pending_remote_change_order[#pending_remote_change_order + 1] = card_id
	end
	pending_remote_changes_by_card_id[card_id] = change
	return true
end

local function has_pending_remote_changes()
	for _, card_id in ipairs(pending_remote_change_order) do
		if pending_remote_changes_by_card_id[card_id] then
			return true
		end
	end

	return false
end

local function take_pending_remote_changes()
	local changes = {}
	for _, card_id in ipairs(pending_remote_change_order) do
		local change = pending_remote_changes_by_card_id[card_id]
		if change then
			changes[#changes + 1] = change
			pending_remote_changes_by_card_id[card_id] = nil
		end
	end

	pending_remote_change_order = {}
	pending_remote_flush_scheduled = false
	return changes
end

local function schedule_pending_remote_flush()
	if pending_remote_flush_scheduled or not BALATRO.queue_event then
		return false
	end

	pending_remote_flush_scheduled = true
	return BALATRO.queue_event({
		trigger = "after",
		delay = TEAM_CARD_REMOTE_APPLY_RETRY_DELAY,
		func = function()
			pending_remote_flush_scheduled = false
			team_card_sync.flush_pending_remote_changes()
			return true
		end,
	})
end

local function queue_played_hand_remote_change_animation(changes, on_complete)
	if team_card_sync.queue_played_hand_remote_change_animation then
		return team_card_sync.queue_played_hand_remote_change_animation(changes, on_complete)
	end

	return false
end

function team_card_sync.clear_pending_remote_changes()
	pending_remote_changes_by_card_id = {}
	pending_remote_change_order = {}
	pending_remote_flush_scheduled = false
end

function team_card_sync.defer_remote_change(change)
	if not is_local_hand_resolution_active() then
		return false
	end

	remember_pending_remote_change(change)
	schedule_pending_remote_flush()
	return true
end

function team_card_sync.flush_pending_remote_changes(options)
	if not has_pending_remote_changes() then
		return false
	end
	if not is_team_card_sync_active() then
		take_pending_remote_changes()
		return false
	end
	if not (options and options.force) and is_local_hand_resolution_active() then
		schedule_pending_remote_flush()
		return false
	end

	local changes = take_pending_remote_changes()
	local applied_count = apply_remote_team_card_changes_now(changes, options)
	return applied_count > 0
end

function team_card_sync.animate_pending_remote_changes_for_played_hand(on_complete)
	if not has_pending_remote_changes() then
		return false
	end
	if not is_team_card_sync_active() then
		take_pending_remote_changes()
		return false
	end
	if not BALATRO.queue_event then
		team_card_sync.flush_pending_remote_changes({
			force = true,
			from_play_flush = true,
		})
		return false
	end

	local changes = take_pending_remote_changes()
	if not queue_played_hand_remote_change_animation(changes, on_complete) then
		apply_remote_team_card_changes_now(changes, {
			force = true,
			from_play_flush = true,
		})
		return false
	end

	return true
end
