local THE_ORDER = MP.COMPAT.THE_ORDER

local original_create_card = create_card

local function get_card_key_append(_type, area, _rarity, key_append)
	if _type == "Tarot" or _type == "Planet" or _type == "Spectral" then
		if area == G.pack_cards then
			return _type .. "_pack"
		end
		return _type
	end

	if _type == "Base" or _type == "Enhanced" then
		return key_append
	end

	if key_append == "jud" and G.GAME.stake >= 7 then
		return key_append
	end

	-- _rarity replacing key_append can be entirely removed to normalize rarity-specific
	-- skip tags, riff raff, and wraith with shop rarity queues.
	return _rarity
end

function create_card(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append)
	if MP.should_use_the_order() then
		return THE_ORDER.with_zero_ante(function()
			local normalized_key_append = get_card_key_append(_type, area, _rarity, key_append)
			return original_create_card(
				_type,
				area,
				legendary,
				_rarity,
				skip_materialize,
				soulable,
				forced_key,
				normalized_key_append
			)
		end)
	end

	return original_create_card(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append)
end

MP.PLATFORM.SMODS.take_booster_ownership_by_kind("Standard", {
	create_card = function(self, card, i)
		local s_append = ""
		local b_append = MP.ante_based() .. s_append

		local _edition = poll_edition("standard_edition" .. b_append, 2, true)
		local _seal = MP.PLATFORM.SMODS.poll_seal({ mod = 10, key = "stdseal" .. b_append })

		return {
			set = (pseudorandom(pseudoseed("stdset" .. b_append)) > 0.6) and "Enhanced" or "Base",
			edition = _edition,
			seal = _seal,
			area = G.pack_cards,
			skip_materialize = true,
			soulable = true,
			key_append = "sta" .. s_append,
		}
	end,
}, true)

MP.PLATFORM.SMODS.override_known("poll_seal", function(pollseal)
	return function(args)
		-- The Order intentionally bypasses ante-based queue drift, even on newer Steamodded builds.
		if MP.should_use_the_order() then
			return THE_ORDER.with_zero_ante(function()
				return pollseal(args)
			end)
		end
		return pollseal(args)
	end
end)
