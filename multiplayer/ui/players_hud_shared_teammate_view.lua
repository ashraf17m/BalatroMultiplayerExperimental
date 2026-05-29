MP.UI = MP.UI or {}
MP.UI.PLAYERS_HUD_SHARED = MP.UI.PLAYERS_HUD_SHARED or {}

local shared = MP.UI.PLAYERS_HUD_SHARED
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function get_shared_team_lives(team_idx)
	local self_team = MP.get_self_team_id and MP.get_self_team_id() or nil
	if self_team ~= nil and team_idx == self_team then
		return (MP.GAME and (MP.GAME.team_lives or MP.GAME.lives)) or 0
	end

	if MP.LOBBY and MP.LOBBY.players and MP.GAME and MP.GAME.enemies then
		for _, lobby_player in ipairs(MP.LOBBY.players) do
			if (lobby_player.team or 1) == team_idx and lobby_player.id ~= (BALATRO.get_player_id and BALATRO.get_player_id() or nil) then
				local enemy = MP.GAME.enemies[lobby_player.id]
				if enemy and enemy.team_lives ~= nil then
					return enemy.team_lives
				elseif enemy and enemy.lives ~= nil then
					return enemy.lives
				end
			end
		end
	end

	return 0
end

shared.get_shared_team_lives = get_shared_team_lives
shared.get_player_blind_main_colour = BALATRO.get_player_blind_main_colour
shared.create_blind_style_palette = BALATRO.create_blind_style_palette
shared.create_player_blind_icon_object = BALATRO.create_player_blind_icon_object
