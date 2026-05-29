local teams_domain = MP.UTILS.load_required_domain(
	"TEAMS",
	"recalculate_state",
	"multiplayer/domain/teams.lua",
	"Multiplayer teams domain is missing."
)
if not teams_domain then return nil end

MP.reset_round_score_state = teams_domain.reset_round_score_state
MP.refresh_live_team_score = teams_domain.refresh_live_score
MP.recalculate_team_state = teams_domain.recalculate_state

return teams_domain
