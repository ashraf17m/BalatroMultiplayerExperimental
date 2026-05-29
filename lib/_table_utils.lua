-- Used only for some UI blob, can be moved
function MP.UTILS.get_array_index_by_value(options, value)
	for i, v in ipairs(options) do
		if v == value then return i end
	end
	return nil
end

function MP.UTILS.reverse_key_value_pairs(tbl, stringify_keys)
	local reversed_tbl = {}
	for k, v in pairs(tbl) do
		if stringify_keys then v = tostring(v) end
		reversed_tbl[v] = k
	end
	return reversed_tbl
end
