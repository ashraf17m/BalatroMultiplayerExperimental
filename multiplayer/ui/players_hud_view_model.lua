-- Shared player list state and reusable standings helpers.
-- FFA standings live in players_hud_ffa_view.lua.
-- Teams standings live in players_hud_teams_view.lua.

local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local shared = MP.UI.PLAYERS_HUD_SHARED or {}

local function get_self_player_id()
	return BALATRO.get_player_id and BALATRO.get_player_id() or nil
end

local function get_lobby_player(player_id)
	if player_id == nil then
		return nil
	end

	if MP.get_lobby_player_by_id then
		return MP.get_lobby_player_by_id(player_id)
	end

	for _, player in ipairs((MP.LOBBY and MP.LOBBY.players) or {}) do
		if player.id == player_id then
			return player
		end
	end

	return nil
end

local function get_local_hands_left()
	return BALATRO.get_hands_left and BALATRO.get_hands_left() or 0
end

local function build_self_standings_player()
	if not MP.GAME then
		return nil
	end

	local player_id = get_self_player_id()
	if player_id == nil then
		return nil
	end

	local lobby_player = MP.get_self_lobby_player and MP.get_self_lobby_player() or get_lobby_player(player_id)
	local lobby_client = MP.LOBBY and MP.LOBBY.client or {}
	return {
		id = player_id,
		username = (lobby_player and lobby_player.username) or lobby_client.username or "You",
		score_text = tostring(MP.GAME.score_text or "0"),
		score_display_int = MP.GAME.score_display,
		hands = get_local_hands_left(),
		lives = MP.GAME.lives or 0,
		is_self = true,
		team = (lobby_player and lobby_player.team) or 1,
		blind_col = (lobby_player and lobby_player.blind_col) or lobby_client.blind_col or 1,
		config = lobby_player and lobby_player.config or nil,
	}
end

local function build_enemy_standings_player(player_id, enemy)
	if not enemy or enemy.in_match == false then
		return nil
	end

	local lobby_player = get_lobby_player(player_id)
	return {
		id = player_id,
		username = enemy.username or (lobby_player and lobby_player.username) or "Unknown",
		score_text = tostring(enemy.score_text or "0"),
		score_display_int = enemy.score,
		hands = enemy.hands or 0,
		lives = enemy.lives or 0,
		is_self = false,
		team = enemy.team or (lobby_player and lobby_player.team),
		blind_col = (lobby_player and lobby_player.blind_col) or 1,
		config = lobby_player and lobby_player.config or nil,
	}
end

local function add_enemy_standings_player(players, included_ids, player_id, enemy)
	if player_id == nil or included_ids[player_id] then
		return
	end

	local row = build_enemy_standings_player(player_id, enemy)
	if not row then
		return
	end

	players[#players + 1] = row
	included_ids[player_id] = true
end

local function add_dummy_standings_players(players, included_ids)
	local testing = MP.TESTING or {}
	if not testing.get_dummy_players then
		return
	end

	for _, dummy in ipairs(testing.get_dummy_players()) do
		if dummy.id and not included_ids[dummy.id] then
			players[#players + 1] = {
				id = dummy.id,
				username = dummy.username or "Dummy",
				score_text = tostring(dummy.score_text or "0"),
				hands = dummy.hands or 0,
				lives = dummy.lives or 0,
				is_self = false,
				team = dummy.team,
				blind_col = dummy.blind_col or 1,
				config = dummy.config,
			}
			included_ids[dummy.id] = true
		end
	end
end

function MP.UI.get_live_match_standings_players()
	local players = {}
	local included_ids = {}
	local enemies = MP.GAME and MP.GAME.enemies or {}
	local self_player = build_self_standings_player()

	if self_player then
		players[#players + 1] = self_player
		included_ids[self_player.id] = true
	end

	for _, lobby_player in ipairs((MP.LOBBY and MP.LOBBY.players) or {}) do
		add_enemy_standings_player(players, included_ids, lobby_player.id, enemies[lobby_player.id])
	end

	for player_id, enemy in pairs(enemies) do
		add_enemy_standings_player(players, included_ids, player_id, enemy)
	end

	add_dummy_standings_players(players, included_ids)

	return players
end

local function get_terminal_standings_players()
	if not ((BALATRO.is_game_over_or_win and BALATRO.is_game_over_or_win()) or (MP.GAME and MP.GAME.won)) then
		return nil, false
	end

	if MP.UI and MP.UI.get_end_game_standings_participants then
		return MP.UI.get_end_game_standings_participants() or {}, true
	end

	return {}, true
end

local function get_standings_source_players()
	local terminal_players, using_terminal_standings = get_terminal_standings_players()
	if using_terminal_standings then
		return terminal_players
	end

	return MP.UI.get_live_match_standings_players()
end

function MP.UI.get_sorted_players()
	local players = {}
	local source_players = get_standings_source_players()

	if source_players then
		for _, standings_player in ipairs(source_players) do
			local raw_score_text = tostring(standings_player.score_text or "0")
			local target_score_display = shared.get_score_display(raw_score_text)
			local live_score_int = standings_player.score_display_int
			local score_display = shared.get_score_display(
				raw_score_text,
				live_score_int or target_score_display.score_int,
				{ prefer_score_int = live_score_int ~= nil }
			)
			table.insert(players, {
				id = standings_player.id,
				username = standings_player.username or "Unknown",
				score_text = score_display.text,
				score_target_text = target_score_display.text,
				score_int = target_score_display.score_int,
				score_display = score_display,
				hands = standings_player.hands or 0,
				lives = standings_player.lives or 0,
				is_self = not not standings_player.is_self,
				team = standings_player.team,
				blind_col = standings_player.blind_col or 1,
				config = standings_player.config,
			})
		end
	end

	table.sort(players, function(a, b)
		if not a.score_int or not b.score_int then return false end
		return MP.INSANE_INT.greater_than(a.score_int, b.score_int)
	end)

	for i, player in ipairs(players) do
		player.rank = i
	end

	return players
end
