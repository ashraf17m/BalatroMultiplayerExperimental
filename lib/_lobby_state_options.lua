local lobby_domain = MP.UTILS.load_required_domain(
	"LOBBY",
	"build_initial_state",
	"multiplayer/domain/lobby.lua",
	"Multiplayer lobby domain is missing."
)
if not lobby_domain then return nil end

MP.normalize_lobby_gamemode = lobby_domain.normalize_gamemode
MP.get_valid_lobby_gamemode = lobby_domain.get_valid_gamemode
MP.set_lobby_creation_ruleset = lobby_domain.set_creation_ruleset
MP.get_lobby_creation_ruleset = lobby_domain.get_creation_ruleset
MP.set_lobby_creation_gamemode = lobby_domain.set_creation_gamemode
MP.get_lobby_creation_gamemode = lobby_domain.get_creation_gamemode
MP.build_default_lobby_config = lobby_domain.build_default_config
MP.reset_lobby_config = lobby_domain.reset_config
MP.apply_lobby_option_update = lobby_domain.apply_option_update
MP.prepare_lobby_config_for_creation = lobby_domain.prepare_config_for_creation

return lobby_domain
