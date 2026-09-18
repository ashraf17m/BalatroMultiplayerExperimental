local BLIND_STATES_TO_SKIP = {
	Hidden = true,
	Defeated = true,
	Skipped = true,
}

local BLIND_STATE_PATH = { "Small", "Big", "Boss" }

function MP.UTILS.get_blind_to_display(blind)
	if blind ~= nil and blind ~= "" then
		return blind
	end

	if not (G and G.GAME and G.GAME.round_resets) then
		return "bl_small"
	end

	local blind_states = G.GAME.round_resets.blind_states or {}
	local blind_choices = G.GAME.round_resets.blind_choices or {}

	local blind_to_display = "Small"
	for _, blind_type in ipairs(BLIND_STATE_PATH) do
		local blind_state = blind_states[blind_type]
		if blind_state and not BLIND_STATES_TO_SKIP[blind_state] then
			blind_to_display = blind_type
			break
		end
	end

	return blind_choices[blind_to_display] or "bl_small"
end

local POKER_HAND_LEVEL_PRIORITY = {
	["Flush Five"] = 1,
	["Flush House"] = 2,
	["Five of a Kind"] = 3,
	["Straight Flush"] = 4,
	["Four of a Kind"] = 5,
	["Full House"] = 6,
	["Flush"] = 7,
	["Straight"] = 8,
	["Three of a Kind"] = 9,
	["Two Pair"] = 11,
	["Pair"] = 12,
	["High Card"] = 13,
}

function MP.UTILS.get_highest_level_poker_hand(is_hand_visible)
	local hands = (G and G.GAME and G.GAME.hands) or nil
	local hand_type = "High Card"
	local max_level = 0

	for key, hand_state in pairs(hands or {}) do
		local visible = is_hand_visible and is_hand_visible(key, hand_state) or hand_state.visible
		if visible then
			if
				to_big(hand_state.level) > to_big(max_level)
				or (
					to_big(hand_state.level) == to_big(max_level)
					and (POKER_HAND_LEVEL_PRIORITY[key] or math.huge) < (POKER_HAND_LEVEL_PRIORITY[hand_type] or math.huge)
				)
			then
				hand_type = key
				max_level = hand_state.level
			end
		end
	end

	return hand_type, max_level
end
