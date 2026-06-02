function MP.UTILS.get_deck_key_from_name(_name)
	for k, v in pairs(G.P_CENTERS) do
		if v.name == _name then return k end
	end
end

function MP.UTILS.get_culled_pool(_type, _rarity, _legendary, _append)
	local pool = get_current_pool(_type, _rarity, _legendary, _append)
	local ret = {}
	for i, v in ipairs(pool) do
		if v ~= "UNAVAILABLE" then ret[#ret + 1] = v end
	end
	return ret
end
