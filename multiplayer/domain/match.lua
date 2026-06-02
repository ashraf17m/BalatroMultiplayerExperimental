MP.DOMAIN = MP.DOMAIN or {}
MP.DOMAIN.MATCH = MP.DOMAIN.MATCH or {}

local MATCH_DOMAIN = MP.DOMAIN.MATCH
local load_required_service = MP.UTILS.load_required_service

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
		local loaded_match_domain = load_required_service(
			service.path,
			service.required_method,
			"Failed to load required match domain method: " .. service.required_method,
			function()
				return MP.DOMAIN and MP.DOMAIN.MATCH or nil
			end
		)
		if not loaded_match_domain then
			MATCH_DOMAIN._services_loaded = false
			return nil
		end
		MATCH_DOMAIN = loaded_match_domain
	end
end

return MATCH_DOMAIN
