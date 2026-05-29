MP.DOMAIN = MP.DOMAIN or {}
MP.DOMAIN.MATCH = MP.DOMAIN.MATCH or {}

local MATCH_DOMAIN = MP.DOMAIN.MATCH
local has_required_methods = MP.UTILS.has_required_methods

local MATCH_SERVICE_FILES = {
	{
		path = "multiplayer/domain/match_state_service.lua",
		required_method = "ensure_state",
	},
	{
		path = "multiplayer/domain/match_enemy_service.lua",
		required_method = "create_enemy_state",
	},
	{
		path = "multiplayer/domain/match_mutation_service.lua",
		required_method = "apply_local_player_info",
	},
	{
		path = "multiplayer/domain/match_restore_service.lua",
		required_method = "apply_saved_state",
	},
}

if not MATCH_DOMAIN._services_loaded then
	MATCH_DOMAIN._services_loaded = true

	for _, service in ipairs(MATCH_SERVICE_FILES) do
		local loaded = MP.PLATFORM.SMODS.load_mod_file(service.path, { required = true })
		if loaded == nil then
			MATCH_DOMAIN._services_loaded = false
			return nil
		end
		MATCH_DOMAIN = MP.DOMAIN and MP.DOMAIN.MATCH or MATCH_DOMAIN
		if not has_required_methods(MATCH_DOMAIN, service.required_method) then
			sendWarnMessage("Failed to load required match domain method: " .. service.required_method, "MULTIPLAYER")
			MATCH_DOMAIN._services_loaded = false
			return nil
		end
	end
end

return MATCH_DOMAIN
