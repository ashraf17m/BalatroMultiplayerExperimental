MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.SMODS = MP.PLATFORM.SMODS or {}

local LEGACY_REGISTRY_KEY = "Multiplayer"

function MP.PLATFORM.SMODS.install_legacy_registry_alias(mod)
	if not (SMODS and type(SMODS.Mods) == "table") then
		return false
	end

	SMODS.Mods[LEGACY_REGISTRY_KEY] = mod or MP.PLATFORM.SMODS.get_current_mod() or MP
	return true
end
