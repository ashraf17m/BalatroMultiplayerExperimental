local lobby_domain = MP.UTILS.load_required_domain(
	"LOBBY",
	"build_initial_state",
	"multiplayer/domain/lobby.lua",
	"Multiplayer lobby domain is missing."
)
if not lobby_domain then return nil end

MP.build_lobby_deck_state = lobby_domain.build_deck_state
MP.build_initial_lobby_client_state = lobby_domain.build_initial_client_state
MP.build_initial_lobby_setup_state = lobby_domain.build_initial_setup_state
MP.build_initial_lobby_run_deck_state = lobby_domain.build_initial_run_deck_state
MP.build_initial_lobby_state = lobby_domain.build_initial_state
MP.initialize_lobby_runtime_state = lobby_domain.initialize_runtime_state
MP.ensure_lobby_client_state = lobby_domain.ensure_client_state
MP.ensure_lobby_setup_state = lobby_domain.ensure_setup_state
MP.ensure_lobby_config_state = lobby_domain.ensure_config_state
MP.set_lobby_players = lobby_domain.set_players
MP.set_lobby_host_state = lobby_domain.set_host_state
MP.set_lobby_match_in_progress = lobby_domain.set_match_in_progress
MP.set_lobby_type = lobby_domain.set_lobby_type
MP.set_lobby_config = lobby_domain.set_config
MP.set_lobby_config_field = lobby_domain.set_config_field
MP.clear_lobby_config_selection = lobby_domain.clear_config_selection
MP.clear_lobby_session = lobby_domain.clear_session
MP.set_pending_lobby_ready = lobby_domain.set_pending_ready
MP.set_lobby_client_username = lobby_domain.set_client_username
MP.set_lobby_client_connected = lobby_domain.set_client_connected
MP.set_lobby_client_blind_col = lobby_domain.set_client_blind_col
MP.set_lobby_setup_temp_code = lobby_domain.set_setup_temp_code
MP.set_lobby_setup_fetched_weekly = lobby_domain.set_setup_fetched_weekly
MP.set_lobby_setup_ruleset_preview = lobby_domain.set_setup_ruleset_preview
MP.set_lobby_setup_gamemode_preview = lobby_domain.set_setup_gamemode_preview
MP.ensure_lobby_run_deck_state = lobby_domain.ensure_run_deck_state
MP.build_lobby_run_deck_from_config = lobby_domain.build_run_deck_from_config
MP.get_lobby_run_deck = lobby_domain.get_run_deck
MP.sync_lobby_run_deck_from_config = lobby_domain.sync_run_deck_from_config
MP.update_lobby_run_deck = lobby_domain.update_run_deck
MP.apply_lobby_info_snapshot = lobby_domain.apply_info_snapshot
MP.update_lobby_player_team = lobby_domain.update_player_team
MP.apply_lobby_nemesis_assignments = lobby_domain.apply_nemesis_assignments
MP.begin_lobby_session = lobby_domain.begin_session

return lobby_domain
