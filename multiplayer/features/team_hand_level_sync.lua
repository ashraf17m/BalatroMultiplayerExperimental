MP.SYNC = MP.SYNC or {}

local team_hand_level_sync = MP.SYNC.TEAM_HAND_LEVEL or {}
MP.SYNC.TEAM_HAND_LEVEL = team_hand_level_sync
MP.TEAM_HAND_LEVEL = team_hand_level_sync

if team_hand_level_sync._loaded then
	return
end
team_hand_level_sync._loaded = true

local is_applying_remote_change = false
local pending_remote_syncs = {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local normalize_integer = MP.PROTOCOL.trunc_number

local function is_team_hand_level_sync_active()
	return BALATRO.is_run_stage and BALATRO.is_run_stage()
		and BALATRO.get_hands and BALATRO.get_hands()
		and MP.is_teams_mode()
		and MP.LOBBY
		and MP.LOBBY.code
		and BALATRO.is_game_over_or_win and not BALATRO.is_game_over_or_win()
		and not (MP.GAME and MP.GAME.won)
end

local function get_hand_level(hand)
	return BALATRO.get_hand_level and BALATRO.get_hand_level(hand) or nil
end

team_hand_level_sync.get_hand_level = get_hand_level
team_hand_level_sync.is_sync_active = is_team_hand_level_sync_active
team_hand_level_sync.is_applying_remote_change = function()
	return is_applying_remote_change
end

function team_hand_level_sync.flush_pending_syncs()
	if not is_team_hand_level_sync_active() then
		return
	end

	if #pending_remote_syncs == 0 then
		return
	end

	local syncs = pending_remote_syncs
	pending_remote_syncs = {}

	for _, sync_data in ipairs(syncs) do
		if team_hand_level_sync.handle_sync then
			team_hand_level_sync.handle_sync(sync_data)
		end
	end
end

function team_hand_level_sync.clear_pending_syncs()
	pending_remote_syncs = {}
end

function team_hand_level_sync.handle_sync(data)
	local hand = type(data) == "table" and data.hand or nil
	local target_level = type(data) == "table" and normalize_integer(data.level) or 0

	if type(hand) ~= "string" or hand == "" then
		return
	end

	local current_level = is_team_hand_level_sync_active() and get_hand_level(hand) or nil
	if not current_level then
		pending_remote_syncs[#pending_remote_syncs + 1] = data
		return
	end

	local delta = target_level - current_level
	if delta == 0 then
		return
	end

	local should_animate = not not (type(data) == "table" and data.playerId and data.playerId ~= "SERVER")

	is_applying_remote_change = true
	local ok, err = pcall(level_up_hand, nil, hand, not should_animate, delta)
	is_applying_remote_change = false

	if not ok then
		if MP.NETWORKING_INTERNAL and MP.NETWORKING_INTERNAL.report_feature_runtime_issue then
			MP.NETWORKING_INTERNAL.report_feature_runtime_issue(
				"teamHandLevelSync",
				"Failed to apply teammate hand level sync.",
				err
			)
		else
			sendWarnMessage("Failed to apply teammate hand level sync: " .. tostring(err), "MULTIPLAYER")
		end
	end
end

-- Team hand-level host hooks now live in `overrides/team_hand_level_sync.lua`.
