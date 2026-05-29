MP.SMODS = MP.SMODS or {}

if not (MP.PLATFORM and MP.PLATFORM.SMODS and MP.PLATFORM.SMODS.get_version
	and MP.PLATFORM.SMODS.compare_versions and MP.PLATFORM.SMODS.is_version_at_least
	and MP.PLATFORM.SMODS.has_optional_feature and MP.PLATFORM.SMODS.override_known) then
	sendWarnMessage("Multiplayer platform SMODS capabilities are missing.", "MULTIPLAYER")
	return nil
end

MP.SMODS.get_version = MP.PLATFORM.SMODS.get_version
MP.SMODS.compare_versions = MP.PLATFORM.SMODS.compare_versions
MP.SMODS.is_version_at_least = MP.PLATFORM.SMODS.is_version_at_least
MP.SMODS.has_optional_feature = MP.PLATFORM.SMODS.has_optional_feature
MP.SMODS.override_known = MP.PLATFORM.SMODS.override_known

return MP.SMODS
