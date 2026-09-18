MP.SYNC = MP.SYNC or {}

local team_hand_level_sync = MP.SYNC.TEAM_HAND_LEVEL or {}
MP.SYNC.TEAM_HAND_LEVEL = team_hand_level_sync

if team_hand_level_sync._loaded then
	return
end
team_hand_level_sync._loaded = true

local is_applying_remote_change = false
local pending_remote_syncs = {}

local function serialize_hand_level(level)
	if level == nil then
		return nil
	end
	if type(level) == "number" then
		return tostring(math.floor(level))
	end
	return tostring(level)
end

local function parse_hand_level(level)
	if type(level) == "number" then
		return level
	end
	if level == nil then
		return nil
	end
	local num = tonumber(level)
	if num ~= nil then
		return num
	end
	if type(to_big) == "function" then
		local ok, big_val = pcall(to_big, level)
		if ok and big_val ~= nil then
			return big_val
		end
	end
	return nil
end

local function calculate_hand_level_delta(target_level, current_level)
	if target_level == nil or current_level == nil then
		return nil
	end

	-- Fast path: standard numbers
	if type(target_level) == "number" and type(current_level) == "number" then
		local delta = target_level - current_level
		if delta > 0 then
			return delta
		end
		return nil -- Monotonic: do not downlevel or no-op
	end

	-- Talisman / BigNumber path
	if type(to_big) == "function" then
		local ok, is_greater = pcall(function()
			return to_big(target_level) > to_big(current_level)
		end)
		if ok and is_greater then
			local sub_ok, diff = pcall(function()
				return to_big(target_level) - to_big(current_level)
			end)
			if sub_ok and diff ~= nil then
				return diff
			end
		end
		return nil
	end

	local ok, delta = pcall(function()
		return target_level - current_level
	end)
	if ok and type(delta) == "number" and delta > 0 then
		return delta
	end

	return nil
end

local function is_team_hand_level_sync_active()
	-- Not gated on the shared hand-level option: that option only controls
	-- teammate routing (owned by the server). Spectators of this player rely
	-- on these syncs reaching the server.
	return (G and G.STAGES and G.STAGE == G.STAGES.RUN or false)
		and (G and G.GAME and G.GAME.hands)
		and MP.LOBBY
		and MP.LOBBY.code
		and not (G and (G.STATE == G.STATES.GAME_OVER or G.STATE == G.STATES.GAME_WIN) or false)
		and not (MP.GAME and MP.GAME.won)
		and not (MP.SPECTATOR and MP.SPECTATOR.is_spectating)
end

local function get_hand_level(hand)
	return (G and G.GAME and G.GAME.hands and G.GAME.hands[hand] and G.GAME.hands[hand].level or nil)
end

team_hand_level_sync.get_hand_level = get_hand_level
team_hand_level_sync.serialize_hand_level = serialize_hand_level
team_hand_level_sync.parse_hand_level = parse_hand_level
team_hand_level_sync.is_sync_active = is_team_hand_level_sync_active
team_hand_level_sync.is_applying_remote_change = function()
	return is_applying_remote_change
end

function team_hand_level_sync.flush_pending_syncs()
	if not is_team_hand_level_sync_active() then
		return
	end

	if not next(pending_remote_syncs) then
		return
	end

	local syncs = pending_remote_syncs
	pending_remote_syncs = {}

	for _, sync_data in pairs(syncs) do
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
	local target_level = type(data) == "table" and parse_hand_level(data.level) or nil

	if type(hand) ~= "string" or hand == "" or target_level == nil then
		return
	end

	local current_level = is_team_hand_level_sync_active() and get_hand_level(hand) or nil
	if current_level == nil then
		pending_remote_syncs[hand] = data
		return
	end

	local delta = calculate_hand_level_delta(target_level, current_level)
	if delta == nil then
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
return team_hand_level_sync
