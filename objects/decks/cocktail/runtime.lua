local content_runtime = MP.CONTENT.RUNTIME
local runtime = {}

local sticker_x_pos = {
	b_red = 0,
	b_blue = 1,
	b_yellow = 2,
	b_green = 3,
	b_black = 4,
	b_magic = 5,
	b_nebula = 6,
	b_ghost = 7,
	b_abandoned = 8,
	b_checkered = 9,
	b_zodiac = 10,
	b_painted = 11,
	b_anaglyph = 12,
	b_plasma = 13,
	b_erratic = 14,
	b_mp_orange = 15,
	b_mp_indigo = 16,
	b_mp_violet = 17,
	b_mp_white = 18,
	b_mp_oracle = 19,
	b_mp_gradient = 20,
	b_mp_heidelberg = 21,
	b_mp_echodeck = 22,
}

local cocktail_deck_blacklist = {
	b_challenge = true,
	b_mp_cocktail = true,
	b_cry_antimatter = true,
	b_akyrs_hardcore_challenges = true,
}

local function get_cocktail_modifiers()
	G.GAME.modifiers = G.GAME.modifiers or {}
	return G.GAME.modifiers
end

local function get_starting_ante_scaling()
	G.GAME.starting_params = G.GAME.starting_params or {}
	return tonumber(G.GAME.starting_params.ante_scaling) or 1
end

local function set_starting_ante_scaling(value)
	local numeric_value = tonumber(value)
	if not numeric_value then
		return
	end

	G.GAME.starting_params = G.GAME.starting_params or {}
	G.GAME.starting_params.ante_scaling = numeric_value
end

local function sync_cocktail_config_ante_scaling(back, value)
	local numeric_value = tonumber(value)
	if not numeric_value or not (back and back.effect and back.effect.config) then
		return
	end

	back.effect.config.ante_scaling = numeric_value
end

-- Cocktail merges selected deck configs after vanilla run setup, so score scaling needs its own combine pass.
local function get_cocktail_ante_scaling_state()
	local modifiers = get_cocktail_modifiers()
	if modifiers.mp_cocktail_base_ante_scaling == nil then
		modifiers.mp_cocktail_base_ante_scaling = get_starting_ante_scaling()
	end
	modifiers.mp_cocktail_config_ante_scaling_multiplier = modifiers.mp_cocktail_config_ante_scaling_multiplier or 1
	modifiers.mp_cocktail_apply_ante_scaling_multiplier = modifiers.mp_cocktail_apply_ante_scaling_multiplier or 1
	return modifiers
end

local function reset_cocktail_ante_scaling_state()
	local modifiers = get_cocktail_modifiers()
	modifiers.mp_cocktail_base_ante_scaling = nil
	modifiers.mp_cocktail_config_ante_scaling_multiplier = nil
	modifiers.mp_cocktail_apply_ante_scaling_multiplier = nil
end

local function register_cocktail_config_ante_scaling(center)
	local scale = center and center.config and tonumber(center.config.ante_scaling) or nil
	if not scale or scale <= 0 then
		return
	end

	local modifiers = get_cocktail_ante_scaling_state()
	modifiers.mp_cocktail_config_ante_scaling_multiplier = modifiers.mp_cocktail_config_ante_scaling_multiplier * scale
end

local function capture_cocktail_apply_ante_scaling(previous_ante_scaling, center)
	local previous = tonumber(previous_ante_scaling)
	local current = get_starting_ante_scaling()
	if not previous or previous == 0 or previous == current then
		return
	end

	set_starting_ante_scaling(previous)
	if center and center.config and center.config.ante_scaling then
		return
	end

	local modifiers = get_cocktail_ante_scaling_state()
	modifiers.mp_cocktail_apply_ante_scaling_multiplier = modifiers.mp_cocktail_apply_ante_scaling_multiplier
		* (current / previous)
end

local function finalize_cocktail_ante_scaling(back)
	local modifiers = get_cocktail_ante_scaling_state()
	local base = tonumber(modifiers.mp_cocktail_base_ante_scaling) or 1
	local config_multiplier = tonumber(modifiers.mp_cocktail_config_ante_scaling_multiplier) or 1
	local apply_multiplier = tonumber(modifiers.mp_cocktail_apply_ante_scaling_multiplier) or 1
	local combined_ante_scaling = base * config_multiplier * apply_multiplier
	set_starting_ante_scaling(combined_ante_scaling)
	sync_cocktail_config_ante_scaling(back, combined_ante_scaling)
end

local function adjust_cocktail_dynamic_ante_scaling_delta(back, previous_ante_scaling, current_ante_scaling, center)
	local previous = tonumber(previous_ante_scaling)
	local current = tonumber(current_ante_scaling)
	if not previous or not current or previous == current then
		return
	end

	local modifiers = get_cocktail_modifiers()
	local config_multiplier = tonumber(modifiers.mp_cocktail_config_ante_scaling_multiplier) or 1
	local center_config_multiplier = center and center.config and tonumber(center.config.ante_scaling) or nil
	if center_config_multiplier and center_config_multiplier ~= 0 then
		config_multiplier = config_multiplier / center_config_multiplier
	end
	if config_multiplier == 1 then
		sync_cocktail_config_ante_scaling(back, current)
		return
	end

	local adjusted_ante_scaling = previous + (current - previous) * config_multiplier
	set_starting_ante_scaling(adjusted_ante_scaling)
	sync_cocktail_config_ante_scaling(back, adjusted_ante_scaling)
end

local function get_cocktail_selector_areas()
	if not G.cocktail_select then
		G.cocktail_select = {}
	end

	return G.cocktail_select
end

local function set_cocktail_runtime_deck(num, deck_key, sticker)
	local modifiers = get_cocktail_modifiers()
	modifiers.mp_cocktail[num] = deck_key
	if sticker then
		modifiers.mp_cocktail_sticker[num] = deck_key
	end
end

local function reset_cocktail_runtime_decks()
	local modifiers = get_cocktail_modifiers()
	modifiers.mp_cocktail = {}
	modifiers.mp_cocktail_sticker = {}
	reset_cocktail_ante_scaling_state()
end

local function set_cocktail_seed(seed)
	G.GAME.pseudorandom.seed = seed
end

local function build_cocktail_mod_whitelist()
	local whitelist = {
		Multiplayer = true,
		MultiplayerExperimental = true,
		Cryptid = true,
		aikoyorisshenanigans = true,
		allinjest = true,
	}

	local current_mod_id = SMODS and SMODS.current_mod and SMODS.current_mod.id or nil
	if current_mod_id and current_mod_id ~= "" then
		whitelist[current_mod_id] = true
	end

	return whitelist
end

local function merge_cocktail_back_config_values(t1, t2, safe)
	local t3 = {}
	for k, v in pairs(t1) do
		if type(v) == "table" then
			t3[k] = merge_cocktail_back_config_values(v, {})
		else
			t3[k] = v
		end
	end
	for k, v in pairs(t2) do
		local existing = t3[k]

		if k == "ante_scaling" and type(existing) == "number" and type(v) == "number" then
			t3[k] = existing * v
		elseif type(existing) == "number" and type(v) == "number" then
			t3[k] = existing + v
		elseif type(existing) == "table" and type(v) == "table" then
			t3[k] = merge_cocktail_back_config_values(existing, v, true)
		else
			if type(v) == "table" then
				t3[k] = merge_cocktail_back_config_values(v, {})
			else
				local index = safe and #t3 + 1 or k
				t3[index] = v
			end
		end
	end
	return t3
end

local function is_cocktail_deck_center(key, center)
	local cocktail_back = G and G.P_CENTERS and G.P_CENTERS["b_mp_cocktail"] or nil
	local blacklist = cocktail_back and cocktail_back.deck_blacklist or cocktail_deck_blacklist
	return center.set == "Back" and not blacklist[key]
end

local function is_cocktail_deck_whitelisted(center)
	local cocktail_back = G and G.P_CENTERS and G.P_CENTERS["b_mp_cocktail"] or nil
	return not (center.mod and cocktail_back and cocktail_back.mod_whitelist and not cocktail_back.mod_whitelist[center.mod.id])
end

local function collect_cocktail_deck_keys()
	local decks = {}
	for key, center in pairs(G.P_CENTERS) do
		if is_cocktail_deck_center(key, center) and is_cocktail_deck_whitelisted(center) then
			decks[#decks + 1] = key
		end
	end

	table.sort(decks, function(a, b)
		return G.P_CENTERS[a].order < G.P_CENTERS[b].order
	end)

	return decks
end

local function get_cocktail_config_table()
	return content_runtime.get_current_mod_config()
end

local function build_default_cocktail_config_string(decks)
	local config_string = ""
	for _ = 1, #decks do
		config_string = config_string .. "1"
	end
	return config_string .. "H"
end

local function ensure_cocktail_config_string(decks)
	local cfg = get_cocktail_config_table()
	if not cfg then
		return nil
	end

	if (not cfg.cocktail) or #decks + 1 ~= #cfg.cocktail then
		cfg.cocktail = build_default_cocktail_config_string(decks)
	end

	return cfg.cocktail
end

local function replace_cocktail_config_char(str, pos, value)
	return str:sub(1, pos - 1) .. value .. str:sub(pos + 1)
end

local function cocktail_cfg_get()
	local lobby_cocktail = content_runtime.get_lobby_deck_value("cocktail")
	if lobby_cocktail then
		return lobby_cocktail
	end

	local cfg = get_cocktail_config_table()
	return cfg and cfg.cocktail or build_default_cocktail_config_string(collect_cocktail_deck_keys())
end

local function cocktail_cfg_readpos(pos, construct)
	local decks = collect_cocktail_deck_keys()
	local cfg = get_cocktail_config_table()
	if not cfg then
		return ""
	end

	ensure_cocktail_config_string(decks)
	if pos == "show" then pos = #cfg.cocktail end
	if construct then return cocktail_cfg_get():sub(pos, pos) end
	return cfg.cocktail:sub(pos, pos)
end

local function split_cocktail_decks_by_config(decks)
	local available = {}
	local forced = {}

	for i, deck_key in ipairs(decks) do
		local selection = cocktail_cfg_readpos(i, true)
		if selection == "1" then
			available[#available + 1] = deck_key
		elseif selection == "2" then
			forced[#forced + 1] = deck_key
		end
	end

	return available, forced
end

local function get_cocktail_decks(cull)
	local decks = collect_cocktail_deck_keys()
	if not cull then
		return decks, {}
	end

	local available, forced = split_cocktail_decks_by_config(decks)
	return available, forced
end

local function cocktail_cfg_edit(bool, deck)
	local decks = collect_cocktail_deck_keys()
	local cfg = get_cocktail_config_table()
	if not cfg then
		return
	end

	ensure_cocktail_config_string(decks)
	local num = (bool == 2) and "2" or (bool and "1" or "0")
	if not deck then
		local string = ""
		for i = 1, #decks do
			string = string .. num
		end
		local show = cocktail_cfg_readpos("show")
		string = string .. show
		cfg.cocktail = string
	else
		for i, v in ipairs(decks) do
			if v == deck then
				cfg.cocktail = replace_cocktail_config_char(cfg.cocktail, i, num)
				break
			end
		end
		if deck == "show" then
			cfg.cocktail = replace_cocktail_config_char(cfg.cocktail, #cfg.cocktail, bool and "S" or "H")
		end
	end
	content_runtime.persist_cocktail_config(cfg.cocktail)
	content_runtime.save_current_config()
end

local function cocktail_check_edited()
	local str = cocktail_cfg_get()
	for i = 1, #str - 1 do
		if string.sub(str, i, i) ~= "1" then return true end
	end
	if string.sub(str, #str, #str) ~= "H" then return true end
	return false
end

local function cocktail_get_forced_num()
	local str = cocktail_cfg_get()
	local c = 0
	for i = 1, #str - 1 do
		if string.sub(str, i, i) == "2" then c = c + 1 end
	end
	return c
end

local function add_cocktail_runtime_deck(num, deck_key, sticker)
	set_cocktail_runtime_deck(num, deck_key, sticker)

	if deck_key == "b_checkered" then
		G.E_MANAGER:add_event(Event({
			func = function()
				for _, card in pairs(G.playing_cards) do
					if card.base.suit == "Clubs" then card:change_suit("Spades") end
					if card.base.suit == "Diamonds" then card:change_suit("Hearts") end
				end
				return true
			end,
		}))
	end
end

local function apply_cocktail_back_config_for_deck(back, deck_key)
	local center = G.P_CENTERS[deck_key]
	back.effect.config = merge_cocktail_back_config_values(back.effect.config, center.config)
	if back.effect.config.voucher then
		back.effect.config.vouchers = back.effect.config.vouchers or {}
		back.effect.config.vouchers[#back.effect.config.vouchers + 1] = back.effect.config.voucher
		back.effect.config.voucher = nil
	end
end

local function apply_cocktail_runtime_deck_effect(back, deck_key)
	local obj = G.P_CENTERS[deck_key]
	register_cocktail_config_ante_scaling(obj)
	apply_cocktail_back_config_for_deck(back, deck_key)

	if obj.apply and type(obj.apply) == "function" then
		local previous_ante_scaling = get_starting_ante_scaling()
		obj:apply(back)
		capture_cocktail_apply_ante_scaling(previous_ante_scaling, obj)
	end

	G.GAME.starting_params = G.GAME.starting_params or {}
	G.GAME.modifiers = G.GAME.modifiers or {}
	if back.effect.config.akyrs_starting_letters then
		G.GAME.starting_params.akyrs_starting_letters = back.effect.config.akyrs_starting_letters
	end
	if back.effect.config.akyrs_letters_no_uppercase then
		G.GAME.starting_params.akyrs_letters_no_uppercase = back.effect.config.akyrs_letters_no_uppercase
	end
	if deck_key == "b_aij_patchwork" then
		G.GAME.modifiers.b_aij_patchwork = true
	end
end

local function setup_cocktail_runtime_decks()
	local decks, forced = get_cocktail_decks(true)
	pseudoshuffle(decks, pseudoseed("mp_cocktail"))

	for i = 1, #forced do
		add_cocktail_runtime_deck(i, forced[i], true)
	end

	for i = 1 + #forced, math.min(3, #decks) do
		add_cocktail_runtime_deck(i, decks[i], cocktail_cfg_readpos("show", true) ~= "H")
	end
end

local function apply_cocktail_runtime_back_effects(back)
	local deck_keys = G.GAME.modifiers.mp_cocktail
	get_cocktail_ante_scaling_state()
	for i = 1, #deck_keys do
		apply_cocktail_runtime_deck_effect(back, deck_keys[i])
	end
	finalize_cocktail_ante_scaling(back)

	if content_runtime.is_ruleset_active("smallworld") then
		content_runtime.apply_fake_back_vouchers(back)
	end

	back.effect.mp_cocktailed = true
end

local function calculate_cocktail_runtime_back_effects(back, context)
	local deck_keys = G.GAME.modifiers.mp_cocktail
	for i = 1, #deck_keys do
		local center = G.P_CENTERS[deck_keys[i]]
		back:change_to(center)
		local previous_ante_scaling = get_starting_ante_scaling()
		local ret1, ret2 = back:trigger_effect(context)
		adjust_cocktail_dynamic_ante_scaling_delta(back, previous_ante_scaling, get_starting_ante_scaling(), center)
		back:change_to(G.P_CENTERS["b_mp_cocktail"])
		if ret1 or ret2 then
			return ret1, ret2
		end
	end
end

local function save_initial_cocktail_config()
	local decks = collect_cocktail_deck_keys()
	ensure_cocktail_config_string(decks)
	content_runtime.save_current_config()
	return true
end

runtime.sticker_x_pos = sticker_x_pos
runtime.get_selector_areas = get_cocktail_selector_areas
runtime.set_viewed_back = function(center) G.GAME.viewed_back = center end
runtime.set_show_active_decks = function(show_active_decks) MP.show_cocktail_decks = show_active_decks end
runtime.set_select_area = function(index, area) get_cocktail_selector_areas()[index] = area end
runtime.set_selector_card_state = function(card, deck_key, highlighted, forced)
	card.sprite_facing = "back"
	card.facing = "back"
	card.mp_cocktail_select = deck_key
	card.highlighted = highlighted
	card.mp_cocktail_forced = forced
end
runtime.set_selector_card_highlight = function(card, highlighted)
	card.highlighted = highlighted
	card.mp_cocktail_forced = false
end
runtime.cache_sticker = function(key, sprite)
	G.shared_stickers[key] = sprite
	return sprite
end
runtime.collect_deck_keys = collect_cocktail_deck_keys
runtime.get_decks = get_cocktail_decks
content_runtime.get_cocktail_config = cocktail_cfg_get
content_runtime.get_cocktail_decks = get_cocktail_decks
runtime.cfg_edit = cocktail_cfg_edit
runtime.cfg_readpos = cocktail_cfg_readpos
runtime.check_edited = cocktail_check_edited
runtime.get_forced_num = cocktail_get_forced_num
runtime.build_default_config_string = build_default_cocktail_config_string

SMODS.Back({
	key = "cocktail",
	config = {},
	atlas = "mp_decks",
	pos = { x = 4, y = 0 },
	mod_whitelist = build_cocktail_mod_whitelist(),
	deck_blacklist = cocktail_deck_blacklist,
	apply = function(self)
		local seed = G._MP_SET_SEED
		set_cocktail_seed(seed or generate_starting_seed())
		reset_cocktail_runtime_decks()
		local back = G.GAME.selected_back
		setup_cocktail_runtime_decks()
		apply_cocktail_runtime_back_effects(back)
	end,
	calculate = function(self, back, context)
		return calculate_cocktail_runtime_back_effects(back, context)
	end,
	mp_credits = { art = { "aura!", "shai1n" }, code = { "Toneblock" } },
})

MP.HOOKS.register_method_hook(Back, "Back", "change_to", "mp.cocktail.preserve_config", {
	before = function(ctx, self)
		if self.effect.mp_cocktailed then
			ctx.mp_cocktail_config = copy_table(self.effect.config)
		end
	end,
	after = function(ctx, self)
		if not ctx.mp_cocktail_config then
			return
		end

		self.effect.config = copy_table(ctx.mp_cocktail_config)
		self.effect.mp_cocktailed = true
	end,
})

G.E_MANAGER:add_event(Event({
	func = save_initial_cocktail_config,
}))

return runtime
