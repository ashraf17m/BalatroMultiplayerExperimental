MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.SMODS = MP.PLATFORM.SMODS or {}

function MP.PLATFORM.SMODS.get_current_mod()
	if SMODS and SMODS.current_mod then
		return SMODS.current_mod
	end

	return MP
end

function MP.PLATFORM.SMODS.get_current_mod_id()
	local mod = MP.PLATFORM.SMODS.get_current_mod()
	return mod and mod.id or "Multiplayer"
end

function MP.PLATFORM.SMODS.is_lovely_loaded()
	local mod = MP.PLATFORM.SMODS.get_current_mod()
	return not not (mod and mod.lovely)
end
