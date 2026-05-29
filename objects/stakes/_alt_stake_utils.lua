MP.STAKES = MP.STAKES or {}

function MP.STAKES.register_alt_stake(definition)
	if not (MP.EXPERIMENTAL and MP.EXPERIMENTAL.alt_stakes) then
		return nil
	end

	local stake_definition = {}
	for key, value in pairs(definition or {}) do
		stake_definition[key] = value
	end

	stake_definition.mp_alt_stake = true
	if stake_definition.unlocked == nil then
		stake_definition.unlocked = true
	end
	stake_definition.atlas = stake_definition.atlas or "alt_mp_stakes"
	stake_definition.sticker_pos = stake_definition.sticker_pos or { x = 3, y = 1 }

	return SMODS.Stake(stake_definition)
end
