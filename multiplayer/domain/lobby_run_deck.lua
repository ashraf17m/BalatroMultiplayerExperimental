MP.DOMAIN = MP.DOMAIN or {}
MP.DOMAIN.LOBBY = MP.DOMAIN.LOBBY or {}

local LOBBY_DOMAIN = MP.DOMAIN.LOBBY

function LOBBY_DOMAIN.ensure_run_deck_state(state)
	state = state or LOBBY_DOMAIN.ensure_state()

	if not state.run_deck then
		state.run_deck = LOBBY_DOMAIN.build_initial_run_deck_state()
	end

	return state.run_deck
end

function LOBBY_DOMAIN.build_run_deck_from_config(state)
	state = state or LOBBY_DOMAIN.ensure_state()
	return LOBBY_DOMAIN.build_deck_state(state.config or nil)
end

function LOBBY_DOMAIN.get_run_deck(state)
	return LOBBY_DOMAIN.ensure_run_deck_state(state)
end

function LOBBY_DOMAIN.sync_run_deck_from_config(state)
	state = state or LOBBY_DOMAIN.ensure_state()
	state.run_deck = LOBBY_DOMAIN.build_run_deck_from_config(state)
	LOBBY_DOMAIN.ensure_run_deck_state(state)
	return state.run_deck
end

return LOBBY_DOMAIN
