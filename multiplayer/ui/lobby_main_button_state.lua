MP.UI = MP.UI or {}
MP.UI.LOBBY_MAIN_BUTTON_STATE = MP.UI.LOBBY_MAIN_BUTTON_STATE or {}
local MAIN_BUTTON_STATE = MP.UI.LOBBY_MAIN_BUTTON_STATE

local WAITING_FOR_MATCH_FINISH_TEXT = { "WAITING FOR", "MATCH TO FINISH" }

local function get_lobby_team_count()
	if not MP.LOBBY or not MP.LOBBY.players then
		return 0
	end

	local teams = {}

	for _, player in ipairs(MP.LOBBY.players or {}) do
		teams[player.team or 1] = true
	end

	local count = 0
	for _, _ in pairs(teams) do
		count = count + 1
	end

	return count
end

local function get_lobby_start_block_reason(lobby_context)
	if MP.is_lobby_match_in_progress() then
		return "match_in_progress"
	end

	local player_count = (lobby_context and lobby_context.player_count) or 0

	if MP.lobby_uses_ready() then
		if player_count ~= 2 then
			return "waiting_for_players"
		end

		for _, player in ipairs(MP.LOBBY.players or {}) do
			if not player.is_owner then
				if player.is_ready == true then
					return nil
				end

				return "waiting_for_guest_ready"
			end
		end

		return "waiting_for_players"
	end

	if player_count < 2 then
		return "waiting_for_players"
	end

	if MP.is_teams_mode() and get_lobby_team_count() < 2 then
		return "waiting_for_teams"
	end

	return nil
end

function MAIN_BUTTON_STATE.get_state()
	local lobby_context = MP.get_lobby_state_context and MP.get_lobby_state_context() or {}
	if lobby_context.is_host then
		local start_block_reason = get_lobby_start_block_reason(lobby_context)
		local disabled_text = start_block_reason == "match_in_progress" and WAITING_FOR_MATCH_FINISH_TEXT
			or start_block_reason == "waiting_for_guest_ready" and localize("b_wait_for_guest_ready")
			or start_block_reason == "waiting_for_teams" and localize("b_wait_for_teams")
			or localize("b_wait_for_players")

		return {
			mode = "host_start",
			enabled = start_block_reason == nil,
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
	local self_ready = not not (lobby_context.self_player and lobby_context.self_player.is_ready)

	return {
		mode = "guest_ready",
		enabled = true,
		is_ready = pending_ready ~= nil and pending_ready or self_ready,
	}
end
