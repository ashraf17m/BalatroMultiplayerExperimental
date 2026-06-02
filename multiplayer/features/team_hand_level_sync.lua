MP.SYNC = MP.SYNC or {}

local team_hand_level_sync = MP.SYNC.TEAM_HAND_LEVEL or {}
MP.SYNC.TEAM_HAND_LEVEL = team_hand_level_sync

if team_hand_level_sync._loaded then
	return
end
team_hand_level_sync._loaded = true

local is_applying_remote_change = false
local pending_remote_syncs = {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function is_finite_number(value)
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

local function normalize_level_text(value)
	if value == nil then
		return nil
	end

	local text = tostring(value)
	text = string.gsub(text, ",", "")
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")

	if text == "" or text == "nan" or text == "inf" or text == "-inf" then
		return nil
	end
	return text
end

local function to_local_finite_number(value)
	if is_finite_number(value) then
		return value
	end

	if type(to_number) ~= "function" then
		return nil
	end

	local ok, numeric_value = pcall(to_number, value)
	if ok and is_finite_number(numeric_value) then
		return numeric_value
	end
	return nil
end

local function serialize_hand_level(level)
	local numeric_level = to_local_finite_number(level)
	if numeric_level ~= nil then
		return normalize_level_text(numeric_level)
	end

	return normalize_level_text(level)
end

local function parse_hand_level(level)
	if is_finite_number(level) then
		return level
	end

	local level_text = normalize_level_text(level)
	if not level_text then
		return nil
	end

	local numeric_level = tonumber(level_text)
	if is_finite_number(numeric_level) then
		return numeric_level
	end

	if type(to_big) ~= "function" then
		return nil
	end

	local ok, parsed_level = pcall(to_big, level_text)
	if ok and parsed_level ~= nil and type(parsed_level) ~= "string" then
		return parsed_level
	end
	return nil
end

local function game_numbers_equal(left, right)
	if left == right then
		return true
	end

	if type(to_big) ~= "function" then
		return false
	end

	local ok, equal = pcall(function()
		return to_big(left) == to_big(right)
	end)
	return ok and equal or false
end

local function subtract_game_numbers(left, right)
	local ok, delta = pcall(function()
		return left - right
	end)
	if ok then
		return delta
	end

	if type(to_big) ~= "function" then
		return nil
	end

	ok, delta = pcall(function()
		return to_big(left) - to_big(right)
	end)
	if ok then
		return delta
	end
	return nil
end

local function is_team_hand_level_sync_active()
	return BALATRO.is_run_stage and BALATRO.is_run_stage()
		and BALATRO.get_hands and BALATRO.get_hands()
		and MP.is_shared_hand_level_sync_enabled()
		and MP.LOBBY
		and MP.LOBBY.code
		and BALATRO.is_game_over_or_win and not BALATRO.is_game_over_or_win()
		and not (MP.GAME and MP.GAME.won)
end

local function get_hand_level(hand)
	return BALATRO.get_hand_level and BALATRO.get_hand_level(hand) or nil
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

	if type(hand) ~= "string" or hand == "" then
		return
	end
	if target_level == nil then
		return
	end

	local current_level = is_team_hand_level_sync_active() and get_hand_level(hand) or nil
	if current_level == nil then
		pending_remote_syncs[hand] = data
		return
	end

	local delta = subtract_game_numbers(target_level, current_level)
	if delta == nil or game_numbers_equal(delta, 0) then
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
