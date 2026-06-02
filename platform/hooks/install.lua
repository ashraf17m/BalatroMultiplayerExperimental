MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.HOOKS = MP.PLATFORM.HOOKS or {}
MP.PLATFORM.SMODS = MP.PLATFORM.SMODS or {}

local installed_known_overrides = {}

function MP.PLATFORM.HOOKS.install_known_override(name, build_override)
	if type(build_override) ~= "function" then
		sendWarnMessage("Invalid multiplayer SMODS override builder for " .. tostring(name), "MULTIPLAYER")
		return false
	end

	if installed_known_overrides[name] then
		sendWarnMessage("Duplicate multiplayer SMODS override attempted for " .. tostring(name), "MULTIPLAYER")
		return false
	end

	local original, target_table, target_key = MP.PLATFORM.HOOKS.capture_known_target(name)
	if not original or not target_table then
		return false
	end

	local replacement = build_override(original)
	if type(replacement) ~= "function" then
		sendWarnMessage("Invalid multiplayer SMODS override for " .. tostring(name), "MULTIPLAYER")
		return false
	end

	target_table[target_key] = replacement
	installed_known_overrides[name] = true
	return true
end

MP.PLATFORM.SMODS.override_known = MP.PLATFORM.HOOKS.install_known_override
