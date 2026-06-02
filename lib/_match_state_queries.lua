local teams_domain = MP.UTILS.load_required_domain(
	"TEAMS",
	"is_cooperative_blind",
	"multiplayer/domain/teams.lua",
	"Multiplayer teams domain is missing."
)
if not teams_domain then return nil end
MP.OPPONENTS = MP.OPPONENTS or {}
local OPPONENTS = MP.OPPONENTS

function OPPONENTS.get_primary_enemy_state()
	if not MP.GAME then
		return nil
	end

	local nemesis_enemy = OPPONENTS.get_nemesis_enemy_state and OPPONENTS.get_nemesis_enemy_state() or nil
	if nemesis_enemy then
		return nemesis_enemy
	end

	local primary_opponent = OPPONENTS.get_primary_lobby_player and OPPONENTS.get_primary_lobby_player() or nil
	if primary_opponent and primary_opponent.id and MP.GAME.enemies and MP.GAME.enemies[primary_opponent.id] then
		return MP.GAME.enemies[primary_opponent.id]
	end

	local active_opponents = OPPONENTS.get_active_lobby_players and OPPONENTS.get_active_lobby_players() or {}
	for _, active_opponent in ipairs(active_opponents) do
		if active_opponent.id and MP.GAME.enemies and MP.GAME.enemies[active_opponent.id] then
			return MP.GAME.enemies[active_opponent.id]
		end
	end

	local lobby_opponents = OPPONENTS.get_lobby_players and OPPONENTS.get_lobby_players() or {}
	for _, lobby_opponent in ipairs(lobby_opponents) do
		if lobby_opponent.id and MP.GAME.enemies and MP.GAME.enemies[lobby_opponent.id] then
			return MP.GAME.enemies[lobby_opponent.id]
		end
	end

	for _, enemy in pairs(MP.GAME.enemies or {}) do
		if enemy then
			return enemy
		end
	end

	return MP.GAME.empty_enemy or MP.GAME.enemy
end

-- Maintain a stable single-enemy mirror for HUD/UI bindings that still point
-- at MP.GAME.enemy while the rest of the runtime tracks many enemies.
local function sync_primary_enemy_view(enemy)
	local primary_enemy_view = MP.GAME and MP.GAME.enemy
	if not primary_enemy_view then return end

	local empty_enemy = MP.GAME and MP.GAME.empty_enemy
	if empty_enemy then
		for key, value in pairs(empty_enemy) do
			primary_enemy_view[key] = value
		end
	end

	local source = enemy or empty_enemy
	if not source then return end

	for key, value in pairs(source) do
		primary_enemy_view[key] = value
	end
end

function OPPONENTS.refresh_primary_enemy_view(fallback_enemy)
	local source = OPPONENTS.get_primary_enemy_state and OPPONENTS.get_primary_enemy_state() or nil
	if not source or source == (MP.GAME and MP.GAME.empty_enemy) then
		source = fallback_enemy or source
	end

	sync_primary_enemy_view(source)
end

local function get_enemy_state_for_player_id(player_id)
	if not player_id or not MP.GAME or not MP.GAME.enemies then
		return nil
	end

	return MP.GAME.enemies[player_id]
end

function OPPONENTS.get_nemesis_enemy_state()
	local nemesis_player = OPPONENTS.get_nemesis_lobby_player and OPPONENTS.get_nemesis_lobby_player() or nil
	if not nemesis_player or not nemesis_player.id then
		return nil
	end

	return get_enemy_state_for_player_id(nemesis_player.id)
end

return teams_domain
