MP.SYNC = MP.SYNC or {}

local team_card_sync = MP.SYNC.TEAM_CARD or {}
MP.SYNC.TEAM_CARD = team_card_sync
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

local function get_playing_cards()
	return BALATRO.get_playing_cards and BALATRO.get_playing_cards() or nil
end

local function get_playing_cards_or_empty()
	return get_playing_cards() or {}
end

local function get_local_card_id_prefix()
	return BALATRO.get_player_id and BALATRO.get_player_id() or "LOCAL"
end

local function is_valid_card_id(card_id)
	return type(card_id) == "string" and card_id ~= ""
end

local function normalize_card_id(card_id)
	return is_valid_card_id(card_id) and card_id or nil
end

local function advance_next_card_id_from_card(card, next_card_id)
	local suffix = get_card_id_suffix(card and card.mp_card_id)
	if suffix and suffix >= next_card_id then
		return suffix + 1
	end

	return next_card_id
end

local function get_saved_card_id(pending_restore, card_ids_by_playing_card, card, index)
	if card_ids_by_playing_card and card.playing_card ~= nil then
		local saved_id = card_ids_by_playing_card[tostring(card.playing_card)]
		if saved_id ~= nil then
			return saved_id
		end
	end

	return pending_restore.card_ids[index]
end

local function assign_missing_card_ids(cards, prefix, next_card_id)
	for _, card in ipairs(cards) do
		if not is_valid_card_id(card.mp_card_id) then
			mark_card_ready_for_team_sync(card, prefix .. "_" .. next_card_id)
			next_card_id = next_card_id + 1
		end
	end

	return next_card_id
end

local function scan_existing_card_ids(cards)
	local has_existing_ids = false
	local next_card_id = 0

	for _, card in ipairs(cards) do
		if is_valid_card_id(card.mp_card_id) then
			has_existing_ids = true
			next_card_id = advance_next_card_id_from_card(card, next_card_id)
		end
	end

	return has_existing_ids, next_card_id
end

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

	local cards = get_playing_cards_or_empty()
	local next_card_id = tonumber(pending_restore.next_card_id) or 0
	local card_ids_by_playing_card = type(pending_restore.card_ids_by_playing_card) == "table"
		and pending_restore.card_ids_by_playing_card
		or nil

	for index, card in ipairs(cards) do
		local saved_id = get_saved_card_id(pending_restore, card_ids_by_playing_card, card, index)
		mark_card_ready_for_team_sync(card, normalize_card_id(saved_id))
		next_card_id = advance_next_card_id_from_card(card, next_card_id)
	end

	next_card_id = assign_missing_card_ids(cards, get_local_card_id_prefix(), next_card_id)

	finalize_team_card_setup(next_card_id)
	return true
end

function team_card_sync.ensure_team_card_ids_for_existing_run()
	local cards = get_playing_cards_or_empty()
	local has_existing_ids, next_card_id = scan_existing_card_ids(cards)

	local uses_shared_sync_group = MP.uses_shared_sync_group()
	local prefix = (uses_shared_sync_group and not has_existing_ids) and "TEAM"
		or get_local_card_id_prefix()

	for index, card in ipairs(cards) do
		local resolved_id = card.mp_card_id
		if not is_valid_card_id(resolved_id) then
			if uses_shared_sync_group and not has_existing_ids then
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
	if not get_playing_cards() then
		return
	end

	if MP.MATCH_LIFECYCLE and MP.MATCH_LIFECYCLE.resume_team_card_sync then
		MP.MATCH_LIFECYCLE.resume_team_card_sync()
	end
	if team_card_sync.clear_removed_card_ids then
		team_card_sync.clear_removed_card_ids()
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
