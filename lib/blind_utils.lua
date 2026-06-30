local BLIND_STATES_TO_SKIP = {
	Hidden = true,
	Defeated = true,
	Skipped = true,
}

local BLIND_STATE_PATH = { "Small", "Big", "Boss" }

local function get_balatro_platform()
	return MP.PLATFORM and MP.PLATFORM.BALATRO or nil
end

local function get_round_resets()
	local balatro = get_balatro_platform()
	if balatro and balatro.get_round_resets then
		local round_resets = balatro.get_round_resets()
		if round_resets then
			return round_resets
		end
	end

	return G and G.GAME and G.GAME.round_resets or nil
end

local function get_blind_state(row)
	local balatro = get_balatro_platform()
	if balatro and balatro.get_blind_state then
		local state = balatro.get_blind_state(row)
		if state ~= nil then
			return state
		end
	end

	local round_resets = get_round_resets()
	return round_resets and round_resets.blind_states and round_resets.blind_states[row] or nil
end

local function get_blind_choice(row)
	local balatro = get_balatro_platform()
	if balatro and balatro.get_blind_choice then
		local choice = balatro.get_blind_choice(row)
		if choice ~= nil then
			return choice
		end
	end

	local round_resets = get_round_resets()
	return round_resets and round_resets.blind_choices and round_resets.blind_choices[row] or nil
end

function MP.UTILS.get_blind_to_display(blind)
	if blind ~= nil and blind ~= "" then
		return blind
	end

	if not (G and G.GAME) then
		return "bl_small"
	end

	local blind_to_display = "Small"
	for _, blind_type in ipairs(BLIND_STATE_PATH) do
		local blind_state = get_blind_state(blind_type)
		if blind_state and not BLIND_STATES_TO_SKIP[blind_state] then
			blind_to_display = blind_type
			break
		end
	end

	return get_blind_choice(blind_to_display) or "bl_small"
end
