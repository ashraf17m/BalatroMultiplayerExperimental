local lobby_domain = MP.UTILS.load_required_domain(
	"LOBBY",
	"build_initial_state",
	"multiplayer/domain/lobby.lua",
	"Multiplayer lobby domain is missing."
)
if not lobby_domain then return nil end

function lobby_domain.get_effective_lobby_deck()
	if not MP.LOBBY then
		return lobby_domain.build_deck_state()
	end

	if MP.LOBBY.config and MP.LOBBY.config.different_decks then
		local run_deck = lobby_domain.get_run_deck and lobby_domain.get_run_deck() or nil
		return run_deck or lobby_domain.build_initial_run_deck_state()
	end

	return lobby_domain.build_run_deck_from_config()
end

function MP.lobby_uses_ready()
	return MP.LOBBY and MP.LOBBY.lobby_type == MP.LOBBY_TYPES.ONE_V_ONE
end

function MP.is_lobby_match_in_progress()
	return not not (MP.LOBBY and MP.LOBBY.match_in_progress)
end
