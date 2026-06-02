local function apply_phantom(card)
	card.ability.eternal = true
	card.ability.mp_sticker_nemesis = true
end

local function remove_phantom(card)
	card.ability.eternal = false
	card.ability.mp_sticker_nemesis = false
end

SMODS.Edition({
	key = "phantom",
	shader = "voucher",
	discovered = true,
	unlocked = true,
	config = {},
	in_shop = false,
	apply_to_float = true,
	badge_colour = G.C.PURPLE,
	sound = { sound = "negative", per = 1.5, vol = 0.4 },
	disable_shadow = false,
	disable_base_shader = true,
	extra_cost = 0, -- Multiplayer lowers the minimum sell value, so phantom cards keep no sell value.
	on_apply = apply_phantom,
	on_remove = remove_phantom,
	on_load = apply_phantom,
	prefix_config = { shader = false },
	mp_credits = {
		idea = { "Virtualized" },
		art = { "Carter" },
		code = { "Virtualized" },
	},
})

MP.PLATFORM.SMODS.override_known("get_card_areas", function(get_card_areas_ref)
	return function(_type, _context)
		if _type == "jokers" and MP.shared then
			local t = get_card_areas_ref(_type, _context)
			table.insert(t, MP.shared)
			return t
		end
		return get_card_areas_ref(_type, _context)
	end
end)
