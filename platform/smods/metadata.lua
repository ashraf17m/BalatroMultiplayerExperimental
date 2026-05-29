MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.SMODS = MP.PLATFORM.SMODS or {}

function MP.PLATFORM.SMODS.attach_current_mod()
	local current_mod = MP.PLATFORM.SMODS.get_current_mod and MP.PLATFORM.SMODS.get_current_mod() or nil
	if not current_mod then
		return nil
	end

	if MP ~= current_mod then
		local bootstrap_state = MP or {}
		for key, value in pairs(bootstrap_state) do
			if current_mod[key] == nil then
				current_mod[key] = value
			end
		end

		MP = current_mod
	end

	MP.id = MP.id or current_mod.id or MP.BOOT_MOD_ID
	MP.path = MP.path or current_mod.path

	return MP
end

function MP.PLATFORM.SMODS.resolve_mod_action_owner_id(mod_id)
	if mod_id then
		return mod_id
	end

	local mod = MP.PLATFORM.SMODS.get_current_mod and MP.PLATFORM.SMODS.get_current_mod() or nil
	if not mod then
		sendWarnMessage("MP.register_mod_action called outside of mod init without a modId", "MULTIPLAYER")
		return nil
	end

	return mod.id
end
