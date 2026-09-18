function MP.UTILS.get_deck_key_from_name(_name)
	for k, v in pairs(G.P_CENTERS) do
		if v.name == _name then return k end
	end
end

-- Drives the grim/familiar/incantation lovely patch. Returns center objects
-- (not keys) to match the vanilla loop body the patch slots into.
function MP.UTILS.get_spectral_enhancement_pool()
	local ruleset = MP.current_ruleset and MP.current_ruleset() or {}
	local bans = ruleset.spectral_banned_enhancements
	local ban_set = {}
	if bans then
		for _, key in ipairs(bans) do
			ban_set[key] = true
		end
	end

	local ret = {}
	for _, center in pairs(G.P_CENTER_POOLS["Enhanced"]) do
		if not ban_set[center.key] then ret[#ret + 1] = center end
	end
	return ret
end
