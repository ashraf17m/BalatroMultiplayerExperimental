MP.DOMAIN = MP.DOMAIN or {}
MP.DOMAIN.RECONNECT = MP.DOMAIN.RECONNECT or {}

local RECONNECT_DOMAIN = MP.DOMAIN.RECONNECT

local function build_runtime_match_sync_buffer()
	return {
		player_info = nil,
		money_update = nil,
		enemy_info_by_player_id = {},
		enemy_location_by_player_id = {},
		team_card_sync_by_card_id = {},
		team_hand_level_sync_by_hand = {},
		timer_state = nil,
		match_outcome_action = nil,
	}
end

local function get_resume_runtime_state_field(field_name, default_value)
	local value = RECONNECT_DOMAIN.ensure_resume_runtime_state()[field_name]
	if value == nil then
		return default_value
	end

	return value
end

local function set_resume_runtime_state_field(field_name, value)
	RECONNECT_DOMAIN.ensure_resume_runtime_state()[field_name] = value
	return value
end

local function clear_resume_runtime_state_field(field_name)
	RECONNECT_DOMAIN.ensure_resume_runtime_state()[field_name] = nil
	return true
end

local function consume_resume_runtime_state_fields(field_name, ...)
	local state = RECONNECT_DOMAIN.ensure_resume_runtime_state()
	local value = state[field_name]
	state[field_name] = nil
	for index = 1, select("#", ...) do
		state[select(index, ...)] = nil
	end
	return value
end

function RECONNECT_DOMAIN.build_resume_runtime_state()
	return {
		pending_manual_resume = nil,
		pending_runtime_resume = nil,
		pending_team_card_restore = nil,
		resume_transition_active = false,
		pending_snapshot_capture = nil,
		last_snapshot_capture_time = 0,
		buffered_runtime_match_sync = nil,
	}
end

function RECONNECT_DOMAIN.ensure_resume_runtime_state()
	RECONNECT_DOMAIN.runtime_state = RECONNECT_DOMAIN.runtime_state or RECONNECT_DOMAIN.build_resume_runtime_state()
	return RECONNECT_DOMAIN.runtime_state
end

function RECONNECT_DOMAIN.reset_resume_runtime_state()
	RECONNECT_DOMAIN.runtime_state = RECONNECT_DOMAIN.build_resume_runtime_state()
	return RECONNECT_DOMAIN.runtime_state
end

function RECONNECT_DOMAIN.get_pending_manual_resume()
	return get_resume_runtime_state_field("pending_manual_resume")
end

function RECONNECT_DOMAIN.set_pending_manual_resume(value)
	return set_resume_runtime_state_field("pending_manual_resume", value)
end

function RECONNECT_DOMAIN.clear_pending_manual_resume()
	return clear_resume_runtime_state_field("pending_manual_resume")
end

function RECONNECT_DOMAIN.set_pending_runtime_resume(value)
	return set_resume_runtime_state_field("pending_runtime_resume", value)
end

function RECONNECT_DOMAIN.get_pending_team_card_restore()
	return get_resume_runtime_state_field("pending_team_card_restore")
end

function RECONNECT_DOMAIN.set_pending_team_card_restore(value)
	return set_resume_runtime_state_field("pending_team_card_restore", value)
end

function RECONNECT_DOMAIN.consume_runtime_resume()
	return consume_resume_runtime_state_fields("pending_runtime_resume", "pending_team_card_restore")
end

function RECONNECT_DOMAIN.is_resume_transition_active()
	return not not get_resume_runtime_state_field("resume_transition_active")
end

function RECONNECT_DOMAIN.set_resume_transition_active(is_active)
	return set_resume_runtime_state_field("resume_transition_active", not not is_active)
end

function RECONNECT_DOMAIN.get_pending_snapshot_capture()
	return get_resume_runtime_state_field("pending_snapshot_capture")
end

function RECONNECT_DOMAIN.set_pending_snapshot_capture(value)
	return set_resume_runtime_state_field("pending_snapshot_capture", value)
end

function RECONNECT_DOMAIN.clear_pending_snapshot_capture()
	return clear_resume_runtime_state_field("pending_snapshot_capture")
end

function RECONNECT_DOMAIN.get_last_snapshot_capture_time()
	return get_resume_runtime_state_field("last_snapshot_capture_time", 0)
end

function RECONNECT_DOMAIN.set_last_snapshot_capture_time(value)
	return set_resume_runtime_state_field("last_snapshot_capture_time", tonumber(value) or 0)
end

function RECONNECT_DOMAIN.can_capture_snapshot_now(now, force, min_interval_seconds)
	local last_snapshot_capture_time = RECONNECT_DOMAIN.get_last_snapshot_capture_time()
	if
		not force
		and last_snapshot_capture_time > 0
		and now < (last_snapshot_capture_time + (min_interval_seconds or 0))
	then
		return false
	end

	return true
end

function RECONNECT_DOMAIN.request_snapshot_capture(now, options)
	options = options or {}

	local allow_unsafe = options.allow_unsafe
	local pending_snapshot_capture = RECONNECT_DOMAIN.get_pending_snapshot_capture()
	if pending_snapshot_capture and pending_snapshot_capture.allow_unsafe then
		allow_unsafe = true
	end

	local snapshot_request = {
		allow_unsafe = not not allow_unsafe,
		ready_at = now + (options.debounce_seconds or 0),
	}

	RECONNECT_DOMAIN.set_pending_snapshot_capture(snapshot_request)
	return snapshot_request
end

function RECONNECT_DOMAIN.get_due_snapshot_capture(now, min_interval_seconds)
	local pending_snapshot_capture = RECONNECT_DOMAIN.get_pending_snapshot_capture()
	if not pending_snapshot_capture then
		return nil
	end

	if now < pending_snapshot_capture.ready_at then
		return nil
	end

	if not RECONNECT_DOMAIN.can_capture_snapshot_now(now, false, min_interval_seconds) then
		return nil
	end

	return {
		allow_unsafe = pending_snapshot_capture.allow_unsafe,
	}
end

function RECONNECT_DOMAIN.note_snapshot_captured(capture_time)
	RECONNECT_DOMAIN.set_last_snapshot_capture_time(capture_time)
	RECONNECT_DOMAIN.clear_pending_snapshot_capture()
	return true
end

function RECONNECT_DOMAIN.begin_runtime_match_sync_buffer()
	local state = RECONNECT_DOMAIN.ensure_resume_runtime_state()
	state.resume_transition_active = true
	state.buffered_runtime_match_sync = state.buffered_runtime_match_sync or build_runtime_match_sync_buffer()
	return state.buffered_runtime_match_sync
end

function RECONNECT_DOMAIN.get_runtime_match_sync_buffer()
	return get_resume_runtime_state_field("buffered_runtime_match_sync")
end

function RECONNECT_DOMAIN.consume_runtime_match_sync_buffer()
	local state = RECONNECT_DOMAIN.ensure_resume_runtime_state()
	local value = state.buffered_runtime_match_sync
	state.buffered_runtime_match_sync = nil
	state.resume_transition_active = false
	return value
end

function RECONNECT_DOMAIN.build_manual_resume(run_snapshot, meta_snapshot)
	return {
		run_snapshot = run_snapshot,
		meta = meta_snapshot,
	}
end

function RECONNECT_DOMAIN.build_resume_meta_snapshot(args)
	args = args or {}

	return {
		lobby_code = args.lobby_code,
		reconnect_token = args.reconnect_token,
		player_id = args.player_id,
		username = args.username or "Guest",
		saved_at = args.saved_at,
		mp_state = args.mp_state,
	}
end

function RECONNECT_DOMAIN.validate_resume_meta_snapshot(meta_snapshot)
	if not meta_snapshot.lobby_code or not meta_snapshot.reconnect_token then
		return nil, "Saved match is missing reconnect details."
	end

	return true
end

function RECONNECT_DOMAIN.refresh_resume_meta_snapshot(meta_snapshot, token, code, player_id)
	meta_snapshot = meta_snapshot or {}

	if token and token ~= "" then
		meta_snapshot.reconnect_token = token
	end
	if code and code ~= "" then
		meta_snapshot.lobby_code = code
	end
	if player_id ~= nil then
		meta_snapshot.player_id = player_id
	end

	return meta_snapshot
end

return RECONNECT_DOMAIN
