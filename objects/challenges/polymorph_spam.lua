SMODS.Challenge({
	key = "polymorph_spam",
	rules = {
		custom = {
			{ id = "mp_polymorph_spam" },
			{ id = "mp_polymorph_spam_EXTENDED1" },
			{ id = "mp_polymorph_spam_EXTENDED2" },
		},
	},
	restrictions = {
		banned_cards = function()
			local ret = {}
			local forced_bans = {
				j_campfire = true,
				j_invisible = true,
				j_caino = true,
				j_yorick = true,
			}
			for i, v in ipairs(G.P_CENTER_POOLS.Joker) do
				if (not v.perishable_compat) or forced_bans[v.key] then ret[#ret + 1] = { id = v.key } end
			end
			return ret
		end,
	},
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})

local function get_area(card)
	if not (card and card.config and card.config.center) then return end
	if card.config.center.set == "Joker" then
		return G.jokers
	elseif card.config.center.consumeable then
		return G.consumeables
	end
	return nil
end

local function get_pos(card)
	local area = get_area(card)
	if not area then return nil end
	for i, v in ipairs(area.cards) do
		if card == v then return i end
	end
	return nil
end

local function is_center_available(key)
	local center = G.P_CENTERS[key]
	if not center or G.GAME.banned_keys[key] then
		return false
	elseif center.mp_include and type(center.mp_include) == "function" then
		return center:mp_include()
	end
	return true
end

local function get_transmutations_loc(card)
	local done = false
	local num = 0
	local area = get_area(card)
	local limit = area.config.card_limit
	local pos = get_pos(card) or nil
	local ret = {}
	while not done do
		for i, v in ipairs(G.P_CENTER_POOLS[card.config.center.set]) do
			if is_center_available(v.key) then
				if num > 0 then
					ret[#ret + 1] = {
						strings = {
							localize({ type = "name_text", key = v.key, set = v.set }),
						},
						control = {
							C = (num - 1) == (limit - (pos or -1)) and "attention" or nil,
						},
					}
					if num == 1 then
						done = true
						break
					end
				end
				if v == card.config.center then
					num = limit
				else
					num = math.max(num - 1, 0)
				end
			end
		end
	end
	return ret
end

local function mass_polymorph(area)
	for _, card in ipairs(area) do
		local done = false
		local swap = 0
		while not done do
			for i, v in ipairs(G.P_CENTER_POOLS[card.config.center.set]) do
				if is_center_available(v.key) then
					if swap == 1 then
						card:set_ability(v)
						card:set_cost()
						done = true
						break
					end
					if v == card.config.center then
						swap = get_pos(card)
					else
						swap = math.max(swap - 1, 0)
					end
				end
			end
		end
	end
end

MP.PLATFORM.SMODS.override_known("calculate_context", function(calculate_context_ref)
	return function(context, return_table, no_resolve)
		if G.GAME.modifiers.mp_polymorph_spam and context and type(context) == "table" and context.setting_blind then
			mass_polymorph(G.jokers.cards)
			mass_polymorph(G.consumeables.cards)
		end
		return calculate_context_ref(context, return_table, no_resolve)
	end
end)

MP.HOOKS.register_method_hook(Card, "Card", "set_ability", "mp.polymorph_spam.debuff_unavailable_center", {
	after = function(ctx, self)
		local center = ctx.args and ctx.args[1]
		if G.GAME.modifiers.mp_polymorph_spam and G.OVERLAY_MENU and center then
			if not is_center_available(center.key) then self.ability.perma_debuff = true end
		end
	end,
})

local current_transmutation_card = nil

local generate_card_ui_ref = generate_card_ui
function generate_card_ui(_c, full_UI_table, specific_vars, card_type, badges, hide_desc, main_start, main_end, card)
	local ret =
		generate_card_ui_ref(_c, full_UI_table, specific_vars, card_type, badges, hide_desc, main_start, main_end, card)
	local center = card and card.config and card.config.center or nil
	if G.GAME.modifiers.mp_polymorph_spam and center and get_area(card) and is_center_available(center.key) then
		current_transmutation_card = card
		generate_card_ui_ref({ key = "mp_transmutations", set = "Other" }, ret)
	end
	return ret
end

local localize_ref = localize
function localize(args, misc_cat)
	if args and type(args) == "table" and args.key == "mp_transmutations" then
		local loc_target = G.localization.descriptions.Other.mp_transmutations.text_parsed
		for i = 2, #loc_target do
			table.remove(loc_target, 2)
		end
		local list = get_transmutations_loc(current_transmutation_card)
		for i = 1, #list do
			loc_target[#loc_target + 1] = { list[i] }
		end
	end
	return localize_ref(args, misc_cat)
end
