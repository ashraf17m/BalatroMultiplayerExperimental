MP.DOMAIN = MP.DOMAIN or {}
MP.DOMAIN.MATCH = MP.DOMAIN.MATCH or {}

local MATCH_DOMAIN = MP.DOMAIN.MATCH
MATCH_DOMAIN.INTERNAL = MATCH_DOMAIN.INTERNAL or {}

local INTERNAL = MATCH_DOMAIN.INTERNAL
local ENEMY_IN_MATCH = true
local ENEMY_CONNECTED = false

local function apply_enemy_presence(enemy, team, is_in_match, is_disconnected, raw_location, location)
	enemy.team = team
	if is_in_match ~= nil then
		enemy.in_match = not not is_in_match
	end
	if is_disconnected ~= nil then
		enemy.is_disconnected = not not is_disconnected
	end
	enemy.raw_location = raw_location or enemy.raw_location
	enemy.location = location or enemy.location
	return enemy
end

local function apply_enemy_lobby_lives(enemy, player_state)
	local lives = tonumber(player_state and player_state.lives)
	if lives ~= nil then
		enemy.lives = lives
		enemy.team_lives = lives
	end
end

local function restore_saved_enemy_state(saved_enemy)
	local enemy = MATCH_DOMAIN.create_enemy_state(saved_enemy.username, saved_enemy.lives)
	enemy.score = INTERNAL.restore_insane_int(saved_enemy.score)
	enemy.synced_score = INTERNAL.restore_insane_int(saved_enemy.synced_score or saved_enemy.score)
	enemy.score_text = tostring(saved_enemy.score_text or "0")
	enemy.hands = tonumber(saved_enemy.hands) or enemy.hands
	enemy.location = saved_enemy.location or enemy.location
	enemy.raw_location = saved_enemy.raw_location or enemy.raw_location
	enemy.is_disconnected = not not saved_enemy.is_disconnected
	enemy.skips = tonumber(saved_enemy.skips) or enemy.skips
	enemy.lives = tonumber(saved_enemy.lives) or enemy.lives
	enemy.team_lives = tonumber(saved_enemy.team_lives) or enemy.team_lives
	enemy.sells = tonumber(saved_enemy.sells) or enemy.sells
	enemy.sells_per_ante = INTERNAL.copy_table_shallow(saved_enemy.sells_per_ante)
	enemy.spent_in_shop = INTERNAL.copy_sequence(saved_enemy.spent_in_shop)
	enemy.highest_score = INTERNAL.restore_insane_int(saved_enemy.highest_score or saved_enemy.score)
	enemy.team = saved_enemy.team
	enemy.in_match = saved_enemy.in_match ~= false
	return enemy
end

INTERNAL.restore_saved_enemy_state = restore_saved_enemy_state

function MATCH_DOMAIN.create_enemy_state(username, lives)
	return {
		username = username or "Guest",
		score = MP.INSANE_INT.empty(),
		synced_score = MP.INSANE_INT.empty(),
		score_text = "0",
		hands = MP.DEFAULT_HANDS_PER_ROUND,
		location = localize("loc_selecting"),
		raw_location = "loc_selecting",
		is_disconnected = false,
		skips = 0,
		lives = lives or MP.LOBBY.config.starting_lives or MP.DEFAULT_STARTING_LIVES,
		team_lives = lives or MP.LOBBY.config.starting_lives or MP.DEFAULT_STARTING_LIVES,
		sells = 0,
		sells_per_ante = {},
		spent_in_shop = {},
		highest_score = MP.INSANE_INT.empty(),
	}
end

function MATCH_DOMAIN.get_or_create_enemy_state(player_id, username, state)
	local enemies = INTERNAL.ensure_enemy_collection(state)
	local enemy = enemies[player_id]

	if not enemy then
		enemy = MATCH_DOMAIN.create_enemy_state(username)
		enemies[player_id] = enemy
	elseif username and username ~= "" then
		enemy.username = username
	end

	return enemy
end

function MATCH_DOMAIN.prune_stale_enemies(tracked_enemy_ids, self_player_id, state)
	local enemies = INTERNAL.ensure_enemy_collection(state)
	local stale_enemy_ids = {}

	for enemy_id, _ in pairs(enemies) do
		if enemy_id ~= self_player_id and not tracked_enemy_ids[enemy_id] then
			stale_enemy_ids[#stale_enemy_ids + 1] = enemy_id
		end
	end

	for _, enemy_id in ipairs(stale_enemy_ids) do
		enemies[enemy_id] = nil
	end

	return enemies
end

local function player_is_spectator(player)
	return not not (player and (player.is_spectator or player.role == "spectator"))
end

function MATCH_DOMAIN.sync_resume_enemies_from_lobby_players(players, self_player_id, state)
	local tracked_enemy_ids = {}

	for _, player in ipairs(players or {}) do
		if player.id ~= self_player_id and not player_is_spectator(player) then
			local enemy = MATCH_DOMAIN.get_or_create_enemy_state(player.id, player.username, state)
			apply_enemy_presence(
				enemy,
				player.team,
				player.is_in_match ~= false,
				player.is_disconnected,
				player.raw_location,
				player.location
			)
			apply_enemy_lobby_lives(enemy, player)
			tracked_enemy_ids[player.id] = true
		end
	end

	MATCH_DOMAIN.prune_stale_enemies(tracked_enemy_ids, self_player_id, state)
	return tracked_enemy_ids
end

function MATCH_DOMAIN.seed_enemies_from_lobby_players(players, self_player_id, state)
	for _, player in ipairs(players or {}) do
		if player.id ~= self_player_id and not player_is_spectator(player) then
			local enemy = MATCH_DOMAIN.get_or_create_enemy_state(player.id, player.username, state)
			apply_enemy_presence(enemy, player.team, true)
			apply_enemy_lobby_lives(enemy, player)
		end
	end

	return INTERNAL.ensure_enemy_collection(state)
end

function MATCH_DOMAIN.sync_enemy_from_lobby_snapshot_player(player_state, is_in_game, local_player_in_match, tracked_enemy_ids, state)
	if not player_state or player_state.is_self or player_is_spectator(player_state) then
		return nil
	end

	local should_track_enemy = (not is_in_game) or (local_player_in_match and player_state.is_in_match)
	if should_track_enemy then
		local enemy = MATCH_DOMAIN.get_or_create_enemy_state(player_state.id, player_state.username, state)
		apply_enemy_presence(
			enemy,
			player_state.team,
			player_state.is_in_match,
			player_state.is_disconnected,
			player_state.raw_location,
			player_state.location
		)
		apply_enemy_lobby_lives(enemy, player_state)
		if tracked_enemy_ids then
			tracked_enemy_ids[player_state.id] = true
		end
		return enemy
	end

	local enemies = INTERNAL.ensure_enemy_collection(state)
	enemies[player_state.id] = nil
	return nil
end

function MATCH_DOMAIN.get_local_player_in_match_from_snapshot(players, self_player_id)
	for _, player_state in ipairs(players or {}) do
		if player_state and (player_state.is_self or player_state.id == self_player_id) then
			return not not player_state.is_in_match
		end
	end

	return false
end

function MATCH_DOMAIN.sync_enemies_from_lobby_snapshot(players, is_in_game, local_player_in_match, self_player_id, state)
	if local_player_in_match == nil then
		local_player_in_match = MATCH_DOMAIN.get_local_player_in_match_from_snapshot(players, self_player_id)
	end

	local tracked_enemy_ids = {}

	for _, player_state in ipairs(players or {}) do
		MATCH_DOMAIN.sync_enemy_from_lobby_snapshot_player(
			player_state,
			is_in_game,
			local_player_in_match,
			tracked_enemy_ids,
			state
		)
	end

	MATCH_DOMAIN.prune_stale_enemies(tracked_enemy_ids, self_player_id, state)
	return tracked_enemy_ids
end

function MATCH_DOMAIN.apply_enemy_team_assignment(player_id, team_id, is_in_match, state)
	local enemies = INTERNAL.ensure_enemy_collection(state)
	local enemy = enemies[player_id]

	if not enemy then
		return nil
	end

	return apply_enemy_presence(enemy, team_id, is_in_match)
end

local function get_enemy_info_field(enemy_info, camel_key, snake_key)
	if type(enemy_info) ~= "table" then
		return nil
	end
	if enemy_info[camel_key] ~= nil then
		return enemy_info[camel_key]
	end
	return enemy_info[snake_key]
end

function MATCH_DOMAIN.apply_enemy_info(enemy_info, self_player_id, state)
	state = state or MATCH_DOMAIN.ensure_state()

	local player_id = get_enemy_info_field(enemy_info, "playerId", "player_id")
	local username = get_enemy_info_field(enemy_info, "username", "username")
	local score_value = get_enemy_info_field(enemy_info, "score", "score_str")
	local hands_left_value = get_enemy_info_field(enemy_info, "handsLeft", "hands_left_str")
	local skips_value = get_enemy_info_field(enemy_info, "skips", "skips_str")
	local lives_value = get_enemy_info_field(enemy_info, "lives", "lives_str")
	local team = get_enemy_info_field(enemy_info, "team", "team")
	local team_lives_value = get_enemy_info_field(enemy_info, "teamLives", "team_lives")
	local life_loss_reason = get_enemy_info_field(enemy_info, "lifeLossReason", "life_loss_reason")
	local server_previous_lives = get_enemy_info_field(enemy_info, "previousLives", "previous_lives")

	if player_id == nil then
		return {
			invalid = true,
			missing_player = true,
		}
	end

	if player_id == self_player_id then
		local enemies = INTERNAL.ensure_enemy_collection(state)
		enemies[player_id] = nil
		return {
			removed_self = true,
		}
	end

	local enemy = MATCH_DOMAIN.get_or_create_enemy_state(player_id, username, state)
	local score = (type(score_value) == "string" or type(score_value) == "number") and MP.INSANE_INT.from_string(score_value) or nil
	local hands_left = tonumber(hands_left_value)
	local skips = tonumber(skips_value)
	local lives = tonumber(lives_value)
	local shared_team_lives = tonumber(team_lives_value)

	if score == nil or hands_left == nil then
		return {
			enemy = enemy,
			invalid = true,
			score = score,
			hands_left = hands_left,
			skips = skips,
			lives = lives,
			shared_team_lives = shared_team_lives,
		}
	end

	local skip_delta = 0
	if skips ~= nil and enemy.skips ~= skips then
		skip_delta = skips - enemy.skips
		if skip_delta > 0 then
			for _ = 1, skip_delta do
				enemy.spent_in_shop[#enemy.spent_in_shop + 1] = 0
			end
		end
	end

	local previous_lives = enemy.lives
	local highest_score_updated = false
	if (MP.is_pvp_boss and MP.is_pvp_boss()) and MP.INSANE_INT.greater_than(score, enemy.highest_score) then
		enemy.highest_score = score
		highest_score_updated = true
	end

	enemy.hands = hands_left
	enemy.skips = skips
	enemy.lives = lives
	enemy.synced_score = score
	enemy.score_text = score_value
	enemy.team_lives = shared_team_lives or lives or enemy.team_lives
	apply_enemy_presence(enemy, team, ENEMY_IN_MATCH, ENEMY_CONNECTED)

	local local_team_lives_updated = false
	if MP.is_teams_mode() and team ~= nil and team == MP.get_self_team_id() then
		state.team_lives = shared_team_lives or lives or state.team_lives
		local_team_lives_updated = true
	end

	return {
		enemy = enemy,
		score = score,
		hands_left = hands_left,
		skips = skips,
		lives = lives,
		shared_team_lives = shared_team_lives,
		skip_delta = skip_delta,
		previous_lives = previous_lives,
		server_previous_lives = tonumber(server_previous_lives),
		life_lost = previous_lives > lives,
		life_loss_reason = life_loss_reason,
		highest_score_updated = highest_score_updated,
		local_team_lives_updated = local_team_lives_updated,
	}
end

function MATCH_DOMAIN.apply_enemy_location(player_id, username, raw_location, resolved_location, state)
	state = state or MATCH_DOMAIN.ensure_state()

	local enemy = MATCH_DOMAIN.get_or_create_enemy_state(player_id, username, state)
	apply_enemy_presence(enemy, enemy.team, ENEMY_IN_MATCH, ENEMY_CONNECTED, raw_location, resolved_location)

	return enemy
end

return MATCH_DOMAIN
