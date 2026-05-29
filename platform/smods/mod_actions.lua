function MP.register_mod_action(modAction, callback, modId)
	if not modId and MP.PLATFORM and MP.PLATFORM.SMODS and MP.PLATFORM.SMODS.resolve_mod_action_owner_id then
		modId = MP.PLATFORM.SMODS.resolve_mod_action_owner_id(modId)
		if not modId then
			return
		end
	end

	MP.MOD_ACTIONS[modId] = MP.MOD_ACTIONS[modId] or {}
	MP.MOD_ACTIONS[modId][modAction] = callback
end
