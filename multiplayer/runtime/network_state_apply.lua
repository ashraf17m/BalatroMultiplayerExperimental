local network_state_apply = MP.STATE_APPLY or {}
MP.STATE_APPLY = network_state_apply
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local load_required_domain = MP.UTILS.load_required_domain
local load_required_service = MP.UTILS.load_required_service

local STATE_APPLY_RUNTIME_METHODS = {
	"resolve_enemy_location_text",
	"handle_lobby_snapshot",
	"handle_lobby_player_joined",
	"handle_lobby_player_updated",
	"handle_lobby_player_left",
	"handle_lobby_type_changed",
	"handle_lobby_team_assignment",
	"handle_lobby_nemesis_assignments",
	"handle_local_player_info",
	"handle_remote_money_update",
	"handle_enemy_info",
	"handle_enemy_location",
}

local LOBBY_PLAYER_SNAPSHOT_METHODS = {
	"get_local_player_in_match",
	"normalize_player_payload",
}

local LOBBY_DOMAIN_METHODS = {
	"apply_info_snapshot",
	"apply_player_joined",
	"apply_player_updated",
	"apply_player_left",
	"apply_type_changed",
	"get_players",
	"update_player_team",
	"apply_nemesis_assignments",
}

local MATCH_DOMAIN_METHODS = {
	"sync_enemies_from_lobby_snapshot",
	"apply_enemy_team_assignment",
	"apply_local_player_info",
	"apply_remote_money_update",
	"apply_enemy_info",
	"apply_enemy_location",
	"sync_resume_enemies_from_lobby_players",
	"seed_enemies_from_lobby_players",
}

local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end

local function to_finite_number(value)
	local numeric_value = tonumber(value)
	if
		not numeric_value
		or numeric_value ~= numeric_value
		or numeric_value == math.huge
		or numeric_value == -math.huge
	then
		return nil
	end
	return numeric_value
end

local lobby_domain = load_required_domain(
	"LOBBY",
	LOBBY_DOMAIN_METHODS,
	"multiplayer/domain/lobby.lua",
	"Multiplayer lobby domain is missing required state-apply methods."
)
if not lobby_domain then
	return nil
end

local match_domain = load_required_domain(
	"MATCH",
	MATCH_DOMAIN_METHODS,
	"multiplayer/domain/match.lua",
	"Multiplayer match domain is missing required state-apply methods."
)
if not match_domain then
	return nil
end

local state_apply_runtime = load_required_service(
	"multiplayer/runtime/state_apply_runtime.lua",
	STATE_APPLY_RUNTIME_METHODS,
	"Multiplayer state apply runtime service is missing."
)
if not state_apply_runtime then
	return nil
end

local lobby_player_snapshot = load_required_service(
	"multiplayer/runtime/lobby_player_snapshot.lua",
	LOBBY_PLAYER_SNAPSHOT_METHODS,
	"Multiplayer lobby player snapshot service is missing."
)
if not lobby_player_snapshot then
	return nil
end

function network_state_apply.lobby_info(players, is_host, is_in_game, lobby_type)
	local lobby_players = players or {}
	local normalized_players = {}

	local uses_lobby_ready = MP.lobby_uses_ready and MP.lobby_uses_ready() or false

	for _, player_wire in ipairs(lobby_players) do
		local player_state = lobby_player_snapshot.normalize_player_payload(player_wire, is_host, uses_lobby_ready)
		table.insert(normalized_players, player_state)
	end

	local snapshot_result = lobby_domain.apply_info_snapshot({
		lobby_type = lobby_type,
		is_host = is_host,
		is_in_game = is_in_game,
		players = normalized_players,
	})

	if match_domain.sync_enemies_from_lobby_snapshot then
		local local_player_in_match = lobby_player_snapshot.get_local_player_in_match(lobby_players)
		match_domain.sync_enemies_from_lobby_snapshot(
			normalized_players,
			is_in_game,
			local_player_in_match,
			BALATRO.get_player_id and BALATRO.get_player_id() or nil
		)
	end

	state_apply_runtime.handle_lobby_snapshot(snapshot_result)
end

function network_state_apply.lobby_player_joined(player_wire)
	local uses_lobby_ready = MP.lobby_uses_ready and MP.lobby_uses_ready() or false
	local is_host = MP.LOBBY and MP.LOBBY.is_host or false
	local player_state = lobby_player_snapshot.normalize_player_payload(player_wire, is_host, uses_lobby_ready)
	local snapshot_result = lobby_domain.apply_player_joined(player_state)

	state_apply_runtime.handle_lobby_player_joined(snapshot_result)
end

function network_state_apply.lobby_player_updated(player_wire)
	local uses_lobby_ready = MP.lobby_uses_ready and MP.lobby_uses_ready() or false
	local is_host = MP.LOBBY and MP.LOBBY.is_host or false
	local player_state = lobby_player_snapshot.normalize_player_payload(player_wire, is_host, uses_lobby_ready)
	local snapshot_result = lobby_domain.apply_player_updated(player_state)

	state_apply_runtime.handle_lobby_player_updated(snapshot_result)
end

function network_state_apply.lobby_player_left(player_id, is_host, owner_player_id, assignments)
	local snapshot_result = lobby_domain.apply_player_left(player_id, is_host, owner_player_id, assignments)

	if match_domain.sync_enemies_from_lobby_snapshot then
		match_domain.sync_enemies_from_lobby_snapshot(
			lobby_domain.get_players(),
			MP.LOBBY and MP.LOBBY.match_in_progress,
			nil,
			BALATRO.get_player_id and BALATRO.get_player_id() or nil
		)
	end

	state_apply_runtime.handle_lobby_player_left(snapshot_result)
end

function network_state_apply.lobby_type_changed(lobby_type, players)
	local snapshot_result = lobby_domain.apply_type_changed(lobby_type, players)

	if match_domain.sync_enemies_from_lobby_snapshot then
		match_domain.sync_enemies_from_lobby_snapshot(
			lobby_domain.get_players(),
			MP.LOBBY and MP.LOBBY.match_in_progress,
			nil,
			BALATRO.get_player_id and BALATRO.get_player_id() or nil
		)
	end

	state_apply_runtime.handle_lobby_type_changed(snapshot_result)
end

function network_state_apply.lobby_player_team(player_id, team_id)
	local updated_player, normalized_team = lobby_domain.update_player_team(player_id, team_id)

	if MP.LOBBY.match_in_progress then
		return
	end

	match_domain.apply_enemy_team_assignment(
		player_id,
		normalized_team,
		updated_player and updated_player.is_in_match
	)

	state_apply_runtime.handle_lobby_team_assignment()
end

function network_state_apply.lobby_nemesis_assignments(assignments)
	local changed = lobby_domain.apply_nemesis_assignments(assignments)

	if not changed then
		return
	end

	state_apply_runtime.handle_lobby_nemesis_assignments()
end

function network_state_apply.player_info(lives, life_loss_reason, previous_lives, team)
	local update_result = match_domain.apply_local_player_info(lives, life_loss_reason, previous_lives, team)
	state_apply_runtime.handle_local_player_info(update_result)
end

function network_state_apply.money_update(money, delta, source_player_id)
	if MP.uses_shared_sync_group() and not MP.is_shared_money_sync_enabled() then
		trace_runtime_event("team_money.update_ignored", {
			reason = "disabled",
			money = money,
			delta = delta,
			source_player_id = source_player_id,
		})
		return
	end

	local update_result
	if money ~= nil then
		update_result = match_domain.apply_remote_money_update(money)
	else
		local delta_value = to_finite_number(delta)
		if not delta_value then
			update_result = { invalid = true }
		else
			local current_money = MP.get_local_money and MP.get_local_money() or 0
			update_result = match_domain.apply_remote_money_update(current_money + delta_value)
		end
	end

	if update_result.invalid then
		trace_runtime_event("team_money.update_invalid", {
			money = money,
			delta = delta,
			source_player_id = source_player_id,
		})
		return
	end

	money = update_result.money

	trace_runtime_event("team_money.update_apply", {
		money = money,
		delta = delta,
		source_player_id = source_player_id,
	})
	state_apply_runtime.handle_remote_money_update(money, delta, source_player_id)
end

function network_state_apply.enemy_info(enemy_info)
	local update_result = match_domain.apply_enemy_info(
		enemy_info,
		BALATRO.get_player_id and BALATRO.get_player_id() or nil
	)

	state_apply_runtime.handle_enemy_info(update_result)
end

function network_state_apply.enemy_location(options)
	local player_id = options.playerId
	local username = options.username
	local _, resolved_location = state_apply_runtime.resolve_enemy_location_text(options.location)
	local enemy = match_domain.apply_enemy_location(player_id, username, options.location, resolved_location)

	state_apply_runtime.handle_enemy_location(enemy)
end

function network_state_apply.sync_resume_enemies_from_lobby()
	match_domain.sync_resume_enemies_from_lobby_players(
		MP.LOBBY.players,
		BALATRO.get_player_id and BALATRO.get_player_id() or nil
	)
end

function network_state_apply.seed_match_enemies_from_lobby()
	match_domain.seed_enemies_from_lobby_players(
		MP.LOBBY.players,
		BALATRO.get_player_id and BALATRO.get_player_id() or nil
	)
end

return network_state_apply
