MP.DOMAIN = MP.DOMAIN or {}
MP.DOMAIN.LOBBY = MP.DOMAIN.LOBBY or {}

local LOBBY_DOMAIN_FILES = {
	"multiplayer/domain/lobby_state.lua",
	"multiplayer/domain/lobby_options.lua",
	"multiplayer/domain/lobby_run_deck.lua",
	"multiplayer/domain/lobby_updates.lua",
	"multiplayer/domain/lobby_session.lua",
}

for _, file_path in ipairs(LOBBY_DOMAIN_FILES) do
	if MP.PLATFORM.SMODS.load_mod_file(file_path, { required = true }) == nil then
		return nil
	end
end

return MP.DOMAIN.LOBBY
