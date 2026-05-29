MP.MATCH_STATE_INTERNAL = MP.MATCH_STATE_INTERNAL or {}

local function normalize_score_text(score_value)
	if type(score_value) == "string" then
		return string.gsub(score_value, ",", "")
	end

	local score_text = tostring(to_big(score_value or 0))
	if string.match(score_text, "[eE]") == nil and string.match(score_text, "[.]") then
		score_text = string.sub(string.gsub(score_text, "%.", ","), 1, -3)
	end
	return string.gsub(score_text, ",", "")
end

MP.MATCH_STATE_INTERNAL.normalize_score_text = normalize_score_text

local teams_domain = MP.UTILS.load_required_domain(
	"TEAMS",
	"is_cooperative_blind",
	"multiplayer/domain/teams.lua",
	"Multiplayer teams domain is missing."
)
if not teams_domain then return nil end

MP.resolve_lobby_blinds_for_ante = teams_domain.resolve_lobby_blinds_for_ante
MP.is_team_cooperative_blind = teams_domain.is_cooperative_blind
MP.get_team_local_score_text = teams_domain.get_local_score_text

function MP.get_primary_enemy_state()
	if not MP.GAME then
		return nil
	end

	local nemesis_enemy = MP.get_nemesis_enemy_state and MP.get_nemesis_enemy_state() or nil
	if nemesis_enemy then
		return nemesis_enemy
	end

	local primary_opponent = MP.get_primary_opponent_lobby_player and MP.get_primary_opponent_lobby_player() or nil
	if primary_opponent and primary_opponent.id and MP.GAME.enemies and MP.GAME.enemies[primary_opponent.id] then
		return MP.GAME.enemies[primary_opponent.id]
	end

	local active_opponents = MP.get_active_opponent_lobby_players and MP.get_active_opponent_lobby_players() or {}
	for _, active_opponent in ipairs(active_opponents) do
		if active_opponent.id and MP.GAME.enemies and MP.GAME.enemies[active_opponent.id] then
			return MP.GAME.enemies[active_opponent.id]
		end
	end

	local lobby_opponents = MP.get_lobby_opponent_players and MP.get_lobby_opponent_players() or {}
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

local function get_enemy_state_for_player_id(player_id)
	if not player_id or not MP.GAME or not MP.GAME.enemies then
		return nil
	end

	return MP.GAME.enemies[player_id]
end

function MP.get_nemesis_enemy_state()
	local nemesis_player = MP.get_nemesis_lobby_player and MP.get_nemesis_lobby_player() or nil
	if not nemesis_player or not nemesis_player.id then
		return nil
	end

	return get_enemy_state_for_player_id(nemesis_player.id)
end

return teams_domain
