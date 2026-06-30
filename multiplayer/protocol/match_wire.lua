MP.MATCH_WIRE = MP.MATCH_WIRE or {}
local to_finite_number = MP.PROTOCOL.to_finite_number
local trunc_number = MP.PROTOCOL.trunc_number
local normalize_non_negative_integer = MP.PROTOCOL.normalize_non_negative_integer

local function build_match_payload(action_name, extra_fields)
	return MP.PROTOCOL.build_v2_packet_for_schema("match", "intent", action_name, extra_fields)
end

local function build_system_payload(action_name, extra_fields)
	return MP.PROTOCOL.build_v2_packet_for_schema("system", "hello", action_name, extra_fields)
end

local function build_team_payload(action_name, extra_fields)
	return MP.PROTOCOL.build_v2_packet_for_schema("team", "state", action_name, extra_fields)
end

local function normalize_big_number(value)
	local normalized = tostring(to_big(value))
	if string.match(normalized, "[eE]") == nil and string.match(normalized, "[.]") then
		normalized = string.sub(string.gsub(normalized, "%.", ","), 1, -3)
	end

	return string.gsub(normalized, ",", "")
end

function MP.MATCH_WIRE.build_start_game_payload()
	return build_match_payload("startGame")
end

function MP.MATCH_WIRE.build_ready_blind_payload(blind_row, blind_kind, options)
	if not blind_row or not blind_kind then
		return nil
	end

	local payload = {
		blindRow = blind_row,
		blindKind = blind_kind,
	}
	local starting_hands = options and options.hands_left or nil
	if starting_hands ~= nil then
		payload.handsLeft = normalize_non_negative_integer(starting_hands)
	end
	local blind_target = options and options.blind_target or nil
	if blind_target ~= nil then
		payload.blindTarget = normalize_big_number(blind_target)
	end

	return build_match_payload("readyBlind", payload)
end

local function normalize_blind_preview_targets(targets)
	local normalized_targets = {}
	for _, row in ipairs({ "Small", "Big", "Boss" }) do
		local target = targets and targets[row] or nil
		if target ~= nil then
			normalized_targets[row] = normalize_big_number(target)
		end
	end
	return normalized_targets
end

function MP.MATCH_WIRE.build_blind_preview_payload(preview_key, targets)
	if preview_key == nil or preview_key == "" then
		return nil
	end

	return build_match_payload("blindPreview", {
		previewKey = tostring(preview_key),
		targets = normalize_blind_preview_targets(targets),
	})
end

function MP.MATCH_WIRE.build_coop_boss_blind_payload(phase, ante, boss_key)
	if phase ~= "start" and phase ~= "result" then
		return nil
	end

	local payload = {
		phase = phase,
		ante = trunc_number(ante),
	}
	if boss_key ~= nil then
		payload.bossKey = tostring(boss_key)
	end

	return build_match_payload("coopBossBlind", payload)
end

function MP.MATCH_WIRE.build_unready_blind_payload()
	return build_match_payload("unreadyBlind")
end

function MP.MATCH_WIRE.build_ready_skip_blind_payload(blind_row, ante)
	return build_match_payload("readySkipBlind", {
		blindRow = blind_row,
		ante = ante ~= nil and trunc_number(ante) or nil,
	})
end

function MP.MATCH_WIRE.build_unready_skip_blind_payload()
	return build_match_payload("unreadySkipBlind")
end

function MP.MATCH_WIRE.build_fail_round_payload()
	return build_match_payload("failRound")
end

function MP.MATCH_WIRE.build_version_payload(version)
	return build_system_payload("hello", {
		version = version,
	})
end

function MP.MATCH_WIRE.build_set_location_payload(location)
	return build_match_payload("setLocation", {
		location = location,
	})
end

function MP.MATCH_WIRE.build_play_hand_payload(score, hands_left, options)
	local normalized_score = normalize_big_number(score)
	local blind_target = nil

	local blind_target_value = options and options.blind_target or nil
	if blind_target_value ~= nil then
		blind_target = normalize_big_number(blind_target_value)
	end

	return build_match_payload("playHand", {
		score = normalized_score,
		handsLeft = normalize_non_negative_integer(hands_left),
		blindTarget = blind_target,
	}), normalized_score
end

function MP.MATCH_WIRE.build_set_ante_payload(ante)
	return build_match_payload("setAnte", {
		ante = trunc_number(ante),
	})
end

function MP.MATCH_WIRE.build_new_round_payload()
	return build_match_payload("newRound")
end

function MP.MATCH_WIRE.build_set_furthest_blind_payload(furthest_blind)
	return build_match_payload("setFurthestBlind", {
		furthestBlind = trunc_number(furthest_blind),
	})
end

function MP.MATCH_WIRE.build_skip_payload(skips)
	return build_match_payload("skip", {
		skips = normalize_non_negative_integer(skips),
	})
end

function MP.MATCH_WIRE.build_timer_payload(action_name, time, local_timer)
	local payload = {}
	local has_payload = false
	if time ~= nil then
		payload.time = normalize_non_negative_integer(time)
		has_payload = true
	end
	if local_timer ~= nil then
		payload.localTimer = not not local_timer
		has_payload = true
	end

	if not has_payload then payload = nil end

	return build_match_payload(action_name, payload)
end

function MP.MATCH_WIRE.build_fail_timer_payload()
	return build_match_payload("failTimer")
end

function MP.MATCH_WIRE.build_fail_pvp_timer_payload()
	return build_match_payload("failPvPTimer")
end

function MP.MATCH_WIRE.build_sync_client_payload(is_cached)
	return build_system_payload("sync", {
		isCached = is_cached,
	})
end

function MP.MATCH_WIRE.normalize_currency_amount(amount)
	return normalize_non_negative_integer(amount)
end

function MP.MATCH_WIRE.normalize_money_balance(money)
	return math.floor(to_finite_number(money, 0))
end

function MP.MATCH_WIRE.build_sync_money_payload(money)
	return build_team_payload("syncMoney", {
		money = MP.MATCH_WIRE.normalize_money_balance(money),
	})
end

function MP.MATCH_WIRE.build_send_team_money_payload(target_player_id, amount, money)
	return build_team_payload("sendTeamMoney", {
		targetPlayerId = target_player_id,
		amount = MP.MATCH_WIRE.normalize_currency_amount(amount),
		money = MP.MATCH_WIRE.normalize_money_balance(money),
	})
end
