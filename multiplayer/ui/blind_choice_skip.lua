MP.BLIND_CHOICE_INTERNAL = MP.BLIND_CHOICE_INTERNAL or {}

local INTERNAL = MP.BLIND_CHOICE_INTERNAL
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function find_skip_blind_button(blind_row)
	if not blind_row then
		return nil
	end
	local box = BALATRO.get_blind_select_option_box and BALATRO.get_blind_select_option_box(blind_row) or nil
	if not box or not box.get_UIE_by_ID then
		return nil
	end
	local tag_container = box:get_UIE_by_ID("tag_container")
	if not tag_container then
		return nil
	end

	local function find_skip_button(node)
		if not node then
			return nil
		end
		if node.config and node.config.button == "skip_blind" then
			return node
		end
		local children = node.children
		if not children then
			return nil
		end
		for i = 1, #children do
			local found = find_skip_button(children[i])
			if found then
				return found
			end
		end
		return nil
	end

	return find_skip_button(tag_container)
end

function INTERNAL.finish_skip_blind()
	if not MP.LOBBY.code then
		return
	end

	INTERNAL.reset_ready_blind_state()
	INTERNAL.set_selecting_location()
	if MP.ANTE_TIMER_RUNTIME and MP.ANTE_TIMER_RUNTIME.apply_skip_for_ante then
		MP.ANTE_TIMER_RUNTIME.apply_skip_for_ante(1)
	end
	MP.ACTIONS.skip(G.GAME.skips)

	local temp_furthest_blind = 0
	if G.GAME.round_resets.blind_states.Big == "Skipped" then
		temp_furthest_blind = G.GAME.round_resets.ante * 10 + 2
	elseif G.GAME.round_resets.blind_states.Small == "Skipped" then
		temp_furthest_blind = G.GAME.round_resets.ante * 10 + 1
	end

	if MP.advance_match_furthest_blind then
		MP.advance_match_furthest_blind(temp_furthest_blind)
	end

	MP.ACTIONS.set_furthest_blind(MP.GAME.furthest_blind)
end

function INTERNAL.perform_actual_skip(e)
	local skip_blind_ref = INTERNAL.original_skip_blind
	if not skip_blind_ref then
		sendTraceMessage("perform_actual_skip: missing original skip_blind reference", "MULTIPLAYER")
		return false
	end
	skip_blind_ref(e)
	INTERNAL.finish_skip_blind()
	return true
end

function MP.perform_team_skip(blind_row, retries_remaining)
	retries_remaining = retries_remaining or 3
	INTERNAL.reset_ready_blind_state()

	if G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_states[blind_row] == "Skipped" then
		return true
	end

	local target_row = blind_row or (G.GAME and G.GAME.blind_on_deck)
	local btn = find_skip_blind_button(target_row)
	if btn then
		return INTERNAL.perform_actual_skip(btn)
	end

	if retries_remaining > 0 then
		BALATRO.queue_event({
			trigger = "after",
			delay = 0.15,
			func = function()
				MP.perform_team_skip(blind_row, retries_remaining - 1)
				return true
			end,
		})
	else
		sendTraceMessage("teamSkipBlind: failed to find skip button for " .. tostring(target_row), "MULTIPLAYER")
	end
	return false
end

return INTERNAL
