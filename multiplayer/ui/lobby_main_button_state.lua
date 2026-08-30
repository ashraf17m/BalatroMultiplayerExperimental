MP.UI = MP.UI or {}
MP.UI.LOBBY_MAIN_BUTTON_STATE = MP.UI.LOBBY_MAIN_BUTTON_STATE or {}
local MAIN_BUTTON_STATE = MP.UI.LOBBY_MAIN_BUTTON_STATE

local WAITING_FOR_MATCH_FINISH_TEXT = { "WAITING FOR", "MATCH TO FINISH" }

local function get_active_players()
	local active = {}
	for _, player in ipairs(MP.LOBBY and MP.LOBBY.players or {}) do
		if not (player.is_spectator or player.role == "spectator") then
			table.insert(active, player)
		end
	end
	return active
end

local function get_active_player_count()
	return #get_active_players()
end

local function get_lobby_team_count()
	local teams = {}

	for _, player in ipairs(get_active_players()) do
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

	local active_players = get_active_players()
	local player_count = #active_players

	if lobby_context and lobby_context.is_saved_coop_restore then
		local required_players = tonumber(lobby_context.config and lobby_context.config.max_players) or 1
		if player_count < required_players then
			return "waiting_for_players"
		end
		return nil
	end

	if MP.lobby_uses_ready() then
		if player_count ~= 2 then
			return "waiting_for_players"
		end

		for _, player in ipairs(active_players) do
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
	local is_self_spectator = not not (
		(lobby_context.self_player and (lobby_context.self_player.is_spectator or lobby_context.self_player.role == "spectator"))
		or (MP.SPECTATOR and MP.SPECTATOR.is_spectator_role)
	)

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

	if not MP.lobby_uses_ready() or is_self_spectator then
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
