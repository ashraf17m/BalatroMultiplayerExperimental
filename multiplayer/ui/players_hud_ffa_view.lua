local shared = MP.UI.PLAYERS_HUD_SHARED or {}
local get_player_blind_main_colour = shared.get_player_blind_main_colour
local calculate_standings_average = shared.calculate_standings_average
local create_compact_standings_entry = shared.create_compact_standings_entry
local create_compact_standings_nodes = shared.create_compact_standings_nodes
local get_eased_score_display = shared.get_eased_score_display

local function get_ffa_rank_colour(rank)
	if rank == 1 then
		return G.C.GOLD
	elseif rank == 2 then
		return G.C.BLUE
	elseif rank == 3 then
		return G.C.GREEN
	end
	return G.C.WHITE
end

function MP.UI.calculate_ffa_average(players)
	return calculate_standings_average(players, {
		score_key = "score_int",
		hands_key = "hands",
	})
end

function MP.UI.refresh_ffa_standings_score_targets(players)
	if not get_eased_score_display then
		return
	end

	local standings_players = players or MP.UI.get_sorted_players()
	for _, player in ipairs(standings_players) do
		if player.id and player.score_int then
			get_eased_score_display("player_standings_scores", player.id, player.score_int, {
				delay = shared.PVP_SCORE_EASE_DELAY,
			})
		end
	end

	local average_data = MP.UI.calculate_ffa_average(standings_players)
	if average_data.show_average then
		get_eased_score_display("average_standings_scores", "ffa", average_data.average_score, {
			delay = shared.PVP_SCORE_EASE_DELAY,
		})
	end
end

local function create_ffa_compact_entry(player, pvp_col)
	local accent = get_ffa_rank_colour(player.rank)
	local blind_main = get_player_blind_main_colour and get_player_blind_main_colour(player, pvp_col) or pvp_col
	local score_display = get_eased_score_display
		and get_eased_score_display("player_standings_scores", player.id, player.score_int, {
			delay = shared.PVP_SCORE_EASE_DELAY,
		})
		or player.score_display
	return create_compact_standings_entry({
		rank = player.rank,
		rank_colour = accent,
		title = player.username or "Unknown",
		title_colour = player.is_self and G.C.GOLD or G.C.UI.TEXT_LIGHT,
		title_outline_colour = player.is_duels_nemesis and G.C.RED or nil,
		palette_colour = blind_main,
		body_colour = pvp_col,
		far_right_colour = pvp_col,
		blind_player = player,
		lives = player.lives,
		hands = player.hands,
		score_text = player.score_text,
		score_display = score_display,
	}, pvp_col)
end

function MP.UI.create_ffa_standings_nodes(full_list)
	local players = MP.UI.get_sorted_players()
	local average_data = MP.UI.calculate_ffa_average(players)
	local pvp_col = G.C.MULTIPLAYER or HEX("AC3232")

	return create_compact_standings_nodes({
		full_list = full_list,
		entries = players,
		average_data = average_data,
		average_title = "AVERAGE SCORE",
		average_key = "ffa",
		average_header_darken = 0.22,
		pvp_col = pvp_col,
		pin_entry = function(player)
			return player.is_self
		end,
		create_entry = function(player)
			return create_ffa_compact_entry(player, pvp_col)
		end,
	})
end
