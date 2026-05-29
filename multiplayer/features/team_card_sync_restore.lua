MP.SYNC = MP.SYNC or {}

local team_card_sync = MP.SYNC.TEAM_CARD or {}
MP.SYNC.TEAM_CARD = team_card_sync
MP.TEAM_CARD = team_card_sync
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

if team_card_sync._restore_loaded then
	return
end
team_card_sync._restore_loaded = true

MP.TEAM_CARD_SUSPENDED = MP.TEAM_CARD_SUSPENDED or false
MP.TEAM_CARD_INITIALIZING = MP.TEAM_CARD_INITIALIZING or false

local require_snapshot_api = assert(team_card_sync.require_snapshot_api, "Team card sync snapshot API missing: require_snapshot_api")
local get_card_id_suffix = require_snapshot_api("get_card_id_suffix")
local mark_card_ready_for_team_sync = require_snapshot_api("mark_card_ready_for_team_sync")
local finalize_team_card_setup = require_snapshot_api("finalize_team_card_setup")
local assign_initial_team_card_ids = require_snapshot_api("assign_initial_team_card_ids")

function team_card_sync.get_pending_team_card_restore_state()
	return MP.RESUME
		and MP.RESUME.get_pending_team_card_restore
		and MP.RESUME.get_pending_team_card_restore()
		or nil
end

function team_card_sync.restore_team_card_ids_from_pending_state(pending_restore)
	if not (type(pending_restore) == "table" and type(pending_restore.card_ids) == "table") then
		return false
	end

	local next_card_id = tonumber(pending_restore.next_card_id) or 0
	local local_prefix = BALATRO.get_player_id and BALATRO.get_player_id() or "LOCAL"
	local card_ids_by_playing_card = type(pending_restore.card_ids_by_playing_card) == "table"
		and pending_restore.card_ids_by_playing_card
		or nil

	for index, card in ipairs((BALATRO.get_playing_cards and BALATRO.get_playing_cards()) or {}) do
		local saved_id = nil
		if card_ids_by_playing_card and card.playing_card ~= nil then
			saved_id = card_ids_by_playing_card[tostring(card.playing_card)]
		end
		if saved_id == nil then
			saved_id = pending_restore.card_ids[index]
		end

		local resolved_id = type(saved_id) == "string" and saved_id ~= "" and saved_id or nil
		mark_card_ready_for_team_sync(card, resolved_id)

		local suffix = get_card_id_suffix(card.mp_card_id)
		if suffix and suffix >= next_card_id then
			next_card_id = suffix + 1
		end
	end

	for _, card in ipairs((BALATRO.get_playing_cards and BALATRO.get_playing_cards()) or {}) do
		if not card.mp_card_id or card.mp_card_id == "" then
			mark_card_ready_for_team_sync(card, local_prefix .. "_" .. next_card_id)
			next_card_id = next_card_id + 1
		end
	end

	finalize_team_card_setup(next_card_id)
	return true
end

function team_card_sync.ensure_team_card_ids_for_existing_run()
	local has_existing_ids = false
	local next_card_id = 0

	for _, card in ipairs((BALATRO.get_playing_cards and BALATRO.get_playing_cards()) or {}) do
		if type(card.mp_card_id) == "string" and card.mp_card_id ~= "" then
			has_existing_ids = true
			local suffix = get_card_id_suffix(card.mp_card_id)
			if suffix and suffix >= next_card_id then
				next_card_id = suffix + 1
			end
		end
	end

	local prefix = (MP.is_teams_mode() and not has_existing_ids) and "TEAM"
		or (BALATRO.get_player_id and BALATRO.get_player_id() or "LOCAL")

	for index, card in ipairs((BALATRO.get_playing_cards and BALATRO.get_playing_cards()) or {}) do
		local resolved_id = card.mp_card_id
		if not resolved_id or resolved_id == "" then
			if MP.is_teams_mode() and not has_existing_ids then
				resolved_id = "TEAM_" .. (index - 1)
				if index > next_card_id then
					next_card_id = index
				end
			else
				resolved_id = prefix .. "_" .. next_card_id
				next_card_id = next_card_id + 1
			end
		end

		mark_card_ready_for_team_sync(card, resolved_id)
	end

	finalize_team_card_setup(next_card_id)
end

function team_card_sync.setup(preserve_existing_ids)
	if not (BALATRO.get_playing_cards and BALATRO.get_playing_cards()) then
		return
	end

	if MP.MATCH_LIFECYCLE and MP.MATCH_LIFECYCLE.resume_team_card_sync then
		MP.MATCH_LIFECYCLE.resume_team_card_sync()
	end

	if not preserve_existing_ids then
		assign_initial_team_card_ids()
		return
	end

	local pending_restore = team_card_sync.get_pending_team_card_restore_state()
	if team_card_sync.restore_team_card_ids_from_pending_state(pending_restore) then
		return
	end

	team_card_sync.ensure_team_card_ids_for_existing_run()
end

MP.TEAM_CARD_SETUP = team_card_sync.setup
