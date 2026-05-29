local shared = MP.UI.PLAYERS_HUD_SHARED or {}
local get_shared_team_lives = shared.get_shared_team_lives
local calculate_standings_average = shared.calculate_standings_average
local create_compact_standings_entry = shared.create_compact_standings_entry
local create_compact_standings_nodes = shared.create_compact_standings_nodes
local get_eased_score_display = shared.get_eased_score_display

local get_team_score_display

local function get_team_rank_colour(rank, pvp_col)
	if rank == 1 then
		return G.C.GOLD
	elseif rank == 2 then
		return HEX("D8DEE8")
	elseif rank == 3 then
		return HEX("D49A4A")
	end
	return lighten(pvp_col, 0.15)
end

local function build_active_teams(players)
	local teams_data = {}
	for i = 1, MP.MAX_TEAMS do
		teams_data[i] = {
			id = i,
			total_score = MP.INSANE_INT.empty(),
			score_text = "0",
			total_hands = 0,
			players = {},
			color = MP.TEAM_COLORS[i] or G.C.WHITE,
			name = MP.TEAM_NAMES[i] or ("TEAM " .. tostring(i)),
			is_self_team = false,
			shared_lives = 0,
		}
	end

	for _, player in ipairs(players) do
		local team_idx = math.max(1, math.min(MP.MAX_TEAMS, tonumber(player.team) or 1))
		local team = teams_data[team_idx]
		team.total_score = MP.INSANE_INT.add(team.total_score, player.score_int)
		team.total_hands = team.total_hands + (player.hands or 0)
		team.is_self_team = team.is_self_team or player.is_self
		table.insert(team.players, player)
	end

	local active_teams = {}
	for _, team in ipairs(teams_data) do
		if #team.players > 0 then
			table.sort(team.players, function(a, b)
				return MP.INSANE_INT.greater_than(a.score_int, b.score_int)
			end)
			team.shared_lives = get_shared_team_lives(team.id)
			team.score_text = MP.INSANE_INT.to_string(team.total_score)
			team.score_display = get_team_score_display(team)
			table.insert(active_teams, team)
		end
	end

	table.sort(active_teams, function(a, b)
		return MP.INSANE_INT.greater_than(a.total_score, b.total_score)
	end)

	for rank, team in ipairs(active_teams) do
		team.rank = rank
	end

	return active_teams
end

local function get_team_representative_player(team)
	if not team or not team.players then
		return nil
	end

	for _, player in ipairs(team.players) do
		if player.is_self then return player end
	end

	return team.players[1]
end

function get_team_score_display(team)
	return get_eased_score_display("team_standings_scores", team.id, team.total_score, {
		delay = shared.PVP_SCORE_EASE_DELAY,
	})
end

local function calculate_team_average(active_teams)
	return calculate_standings_average(active_teams, {
		score_key = "total_score",
		hands_key = "total_hands",
	})
end

function MP.UI.refresh_team_standings_score_targets(players)
	local active_teams = build_active_teams(players or MP.UI.get_sorted_players())
	local average_data = calculate_team_average(active_teams)
	if average_data.show_average then
		get_eased_score_display("average_standings_scores", "teams", average_data.average_score, {
			delay = shared.PVP_SCORE_EASE_DELAY,
		})
	end
	return active_teams
end

local function create_team_compact_entry(team, pvp_col)
	local rank_colour = get_team_rank_colour(team.rank, pvp_col)
	local representative = get_team_representative_player(team)

	return create_compact_standings_entry({
		rank = team.rank,
		rank_colour = rank_colour,
		title = team.name,
		title_colour = G.C.WHITE,
		palette_colour = team.color,
		body_colour = team.color,
		far_right_colour = team.color,
		blind_player = representative,
		lives = team.shared_lives,
		hands = team.total_hands,
		score_text = team.score_text,
		score_display = team.score_display,
	}, pvp_col)
end

function MP.UI.create_teams_standings_nodes(full_list)
	local players = MP.UI.get_sorted_players()
	local pvp_col = G.C.MULTIPLAYER or HEX("AC3232")
	local active_teams = build_active_teams(players)
	local average_data = calculate_team_average(active_teams)

	return create_compact_standings_nodes({
		full_list = full_list,
		entries = active_teams,
		average_data = average_data,
		average_title = "TEAM AVERAGE",
		average_key = "teams",
		average_header_darken = 0.24,
		pvp_col = pvp_col,
		pin_entry = function(team)
			return team.is_self_team
		end,
		create_entry = function(team)
			return create_team_compact_entry(team, pvp_col)
		end,
	})
end
