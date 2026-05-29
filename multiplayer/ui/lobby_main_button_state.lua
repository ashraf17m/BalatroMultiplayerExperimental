local WAITING_FOR_MATCH_FINISH_TEXT = { "WAITING FOR", "MATCH TO FINISH" }

function MP.get_lobby_main_button_state()
	local lobby_context = MP.get_lobby_state_context and MP.get_lobby_state_context() or {}
	if lobby_context.is_host then
		local start_block_reason = MP.get_lobby_start_block_reason()
		local disabled_text = start_block_reason == "match_in_progress" and WAITING_FOR_MATCH_FINISH_TEXT
			or start_block_reason == "waiting_for_guest_ready" and localize("b_wait_for_guest_ready")
			or start_block_reason == "waiting_for_teams" and localize("b_wait_for_teams")
			or localize("b_wait_for_players")

		return {
			mode = "host_start",
			enabled = MP.can_host_start_lobby(),
			disabled_text = disabled_text,
		}
	end

	if not MP.lobby_uses_ready() then
		return {
			mode = "guest_wait",
			enabled = false,
			disabled_text = MP.is_lobby_match_in_progress() and WAITING_FOR_MATCH_FINISH_TEXT
				or localize("b_wait_for_host_start"),
		}
	end

	local pending_ready = lobby_context.client and lobby_context.client.pending_lobby_ready
	if pending_ready ~= nil then
		return {
			mode = "guest_ready_pending",
			enabled = false,
			is_ready = pending_ready,
		}
	end

	return {
		mode = "guest_ready",
		enabled = true,
		is_ready = MP.is_self_lobby_ready(),
	}
end
