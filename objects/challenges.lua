-- Consolidated objects/challenges.lua
-- Combines all 22 micro-files from objects/challenges/ into a single file

-- === all_must_go.lua ===
SMODS.Challenge({
	key = "all_must_go",
	jokers = {
		{ id = "j_mp_taxes", eternal = true },
		{ id = "j_campfire", eternal = true },
	},
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})

-- === bacon.lua ===
SMODS.Challenge({
	key = "bacon",
	rules = {
		custom = {
			{ id = "mp_indigo" },
		},
	},
	restrictions = {
		banned_cards = {
			{
				id = "p_celestial_normal_1",
				ids = {
					"p_celestial_normal_2",
					"p_celestial_normal_3",
					"p_celestial_normal_4",
					"p_celestial_jumbo_1",
					"p_celestial_jumbo_2",
					"p_celestial_mega_1",
					"p_celestial_mega_2",
				},
			},
			{
				id = "p_standard_normal_1",
				ids = {
					"p_standard_normal_2",
					"p_standard_normal_3",
					"p_standard_normal_4",
					"p_standard_jumbo_1",
					"p_standard_jumbo_2",
					"p_standard_mega_1",
					"p_standard_mega_2",
				},
			},
			{
				id = "p_arcana_normal_1",
				ids = {
					"p_arcana_normal_2",
					"p_arcana_normal_3",
					"p_arcana_normal_4",
					"p_arcana_jumbo_1",
					"p_arcana_jumbo_2",
					"p_arcana_mega_1",
					"p_arcana_mega_2",
				},
			},
		},
	},
	apply = function(self)
		G.GAME.selected_back.atlas = "mp_decks"
		G.GAME.selected_back.pos = { x = 1, y = 0 }
		G.GAME.modifiers.booster_choice_mod = (G.GAME.modifiers.booster_choice_mod or 0) + 1
	end,
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})

-- === balancing_act.lua ===
SMODS.Challenge({
	key = "balancing_act",
	rules = {
		custom = {
			{ id = "mp_score_instability" },
			{ id = "mp_score_instability_EXAMPLE" },
			{ id = "mp_score_instability_LOC1" },
			{ id = "mp_score_instability_LOC2" },
			{ id = "mp_ante_scaling", value = 0.25 },
		},
	},
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})

MP.HOOKS.register_method_hook(Back, "Back", "trigger_effect", "mp.balancing_act.score_instability", {
	before = function(ctx)
		local args = ctx.args[1]
		if not (G.GAME.modifiers.mp_score_instability and args.context == "final_scoring_step") then
			return
		end

		local diff = args.chips - args.mult
		if diff > 0 then
			diff = math.min(diff, args.mult - 1)
		elseif diff < 0 then
			diff = math.max(diff, -args.chips)
		end
		args.chips = args.chips + diff
		args.mult = args.mult - diff
		update_hand_text({ delay = 0 }, { mult = args.mult, chips = args.chips })

		G.E_MANAGER:add_event(Event({
			func = function()
				local text = localize("k_destabilized")
				play_sound("timpani", 0.5 / 1.5, 0.4)
				play_sound("timpani", 0.5, 0.5)
				play_sound("timpani", 0.5 * 1.5, 0.6)
				play_sound("tarot1", 1.5)
				ease_colour(G.C.UI_CHIPS, G.C.PERISHABLE)
				ease_colour(G.C.UI_MULT, G.C.ETERNAL)
				attention_text({
					scale = 1.4,
					text = text,
					hold = 2,
					align = "cm",
					offset = { x = 0, y = -2.7 },
					major = G.play,
				})
				G.E_MANAGER:add_event(Event({
					trigger = "after",
					blockable = false,
					blocking = false,
					delay = 4.3,
					func = function()
						ease_colour(G.C.UI_CHIPS, G.C.BLUE, 2)
						ease_colour(G.C.UI_MULT, G.C.RED, 2)
						return true
					end,
				}))
				G.E_MANAGER:add_event(Event({
					trigger = "after",
					blockable = false,
					blocking = false,
					no_delete = true,
					delay = 6.3,
					func = function()
						G.C.UI_CHIPS[1], G.C.UI_CHIPS[2], G.C.UI_CHIPS[3], G.C.UI_CHIPS[4] =
							G.C.BLUE[1], G.C.BLUE[2], G.C.BLUE[3], G.C.BLUE[4]
						G.C.UI_MULT[1], G.C.UI_MULT[2], G.C.UI_MULT[3], G.C.UI_MULT[4] =
							G.C.RED[1], G.C.RED[2], G.C.RED[3], G.C.RED[4]
						return true
					end,
				}))
				return true
			end,
		}))
		delay(0.6)
		ctx.skip_original = true
		ctx.results = { args.chips, args.mult, n = 2 }
	end,
})

-- === chore_list.lua ===
SMODS.Challenge({
	key = "chore_list",
	jokers = {
		{ id = "j_todo_list", eternal = true, rental = true, edition = "negative" },
		{ id = "j_todo_list", eternal = true, rental = true, edition = "negative" },
	},
	restrictions = {
		banned_cards = {
			{ id = "j_trading" },
			{ id = "j_midas_mask" },
			{ id = "j_golden" },
			{ id = "j_todo_list" },
			{ id = "j_rough_gem" },
			{ id = "j_reserved_parking" },
			{ id = "j_to_the_moon" },
			{ id = "j_business" },
			{ id = "j_delayed_grat" },
			{ id = "j_satellite" },
			{ id = "j_egg" },
			{ id = "j_faceless" },
			{ id = "j_mail" },
			{ id = "j_golden" },
			{ id = "j_gift" },
			{ id = "j_riff_raff" },
			{ id = "j_chaos" },
			{ id = "j_mp_penny_pincher" },
		},
	},
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})

-- === divination.lua ===
SMODS.Challenge({
	key = "divination",
	jokers = {
		{ id = "j_vagabond", eternal = true },
	},
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})

-- === eeeee.lua ===
SMODS.Challenge({
	key = "mp_eeeee",
	rules = {
		custom = {
			{ id = "mp_eeeee" },
		},
	},
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})

local pseudoseed_ref = pseudoseed
function pseudoseed(key, predict_seed)
	if G.GAME and G.GAME.modifiers and G.GAME.modifiers.mp_eeeee and not G._MP_UNSAVED_PRNG then
		G.GAME.mp_eeeee = G.GAME.mp_eeeee or {}
		local ante = G.GAME.round_resets.mp_real_ante or G.GAME.round_resets.ante
		if not G.GAME.mp_eeeee[ante .. "_" .. key] then
			math.randomseed(pseudohash((G.GAME.pseudorandom.seed or "") .. ante .. "mp_eeeee_" .. key))
			G.GAME.mp_eeeee[ante .. "_" .. key] = {
				poll = math.random(),
				val = math.random(),
			}
		end
		if G.GAME.mp_eeeee[ante .. "_" .. key].poll < 0.4 then
			return G.GAME.mp_eeeee[ante .. "_" .. key].val
		end
	end
	return pseudoseed_ref(key, predict_seed)
end

-- === high_hand.lua ===
SMODS.Challenge({
	key = "high_hand",
	rules = {
		modifiers = {
			{ id = "hands", value = 1 },
			{ id = "hand_size", value = 26 },
			{ id = "discards", value = 0 },
		},
	},
	restrictions = {
		banned_cards = {
			{ id = "j_burglar" },
		},
	},
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})

-- === in_the_red.lua ===
SMODS.Challenge({
	key = "in_the_red",
	rules = {
		custom = {
			{ id = "no_reward_specific", value = "Small" },
			{ id = "no_reward_specific", value = "Big" },
		},
	},
	jokers = {
		{ id = "j_credit_card", eternal = true, edition = "negative", rental = true },
	},
	restrictions = {
		banned_tags = {
			{ id = "tag_investment" },
		},
	},
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})

-- === legendaries.lua ===
SMODS.Challenge({
	key = "legendaries",
	rules = {
		modifiers = {
			{
				id = "joker_slots",
				value = 6,
			},
		},
	},
	jokers = {
		{ id = "j_caino", eternal = true },
		{ id = "j_perkeo", eternal = true },
		{ id = "j_triboulet", eternal = true },
		{ id = "j_yorick", eternal = true },
		{ id = "j_joker" },
	},
	restrictions = {
		banned_cards = {
			{ id = "j_selzer" },
			{ id = "j_dusk" },
			{ id = "j_sock_and_buskin" },
			{ id = "j_hanging_chad" },
			{ id = "j_mp_hanging_chad" },
			{ id = "j_blueprint" },
			{ id = "j_brainstorm" },
		},
	},
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})

-- === lets_go_gambling.lua ===
SMODS.Challenge({
	key = "lets_go_gambling",
	rules = {
		custom = {
			{ id = "no_reward_specific", value = "Small" },
			{ id = "no_reward_specific", value = "Big" },
		},
	},
	jokers = {
		{ id = "j_oops", eternal = true, rental = true },
		{ id = "j_mp_lets_go_gambling", eternal = true, edition = "negative", rental = true },
	},
	restrictions = {
		banned_cards = {
			{ id = "j_selzer" },
			{ id = "j_dusk" },
			{ id = "j_hanging_chad" },
			{ id = "j_bloodstone" },
			{ id = "c_high_priestess" },
			{ id = "c_empress" },
			{ id = "c_heirophant" },
			{ id = "c_chariot" },
			{ id = "c_justice" },
			{ id = "c_hermit" },
			{ id = "c_strength" },
			{ id = "c_hanged_man" },
			{ id = "c_death" },
			{ id = "c_temperance" },
			{ id = "c_devil" },
			{ id = "c_tower" },
			{ id = "c_star" },
			{ id = "c_moon" },
			{ id = "c_sun" },
			{ id = "c_world" },
		},
	},
	deck = {
		type = "Challenge Deck",
		enhancement = "m_lucky",
	},
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})

-- === misprint_deck.lua ===
local deck_cards = {}
for i = 1, 52 do
	deck_cards[i] = { s = "S", r = "T" }
end

SMODS.Challenge({
	key = "misprint_deck",
	deck = {
		type = "Challenge Deck",
		cards = deck_cards,
	},
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})

-- === oops_all_jokers.lua ===
SMODS.Challenge({
	key = "oops_all_jokers",
	jokers = {
		{ id = "j_ring_master", eternal = true, edition = "negative" },
	},
	restrictions = {
		banned_cards = {
			{ id = "c_fool" },
			{ id = "c_magician" },
			{ id = "c_high_priestess" },
			{ id = "c_empress" },
			{ id = "c_emperor" },
			{ id = "c_heirophant" },
			{ id = "c_lovers" },
			{ id = "c_chariot" },
			{ id = "c_justice" },
			{ id = "c_hermit" },
			{ id = "c_wheel_of_fortune" },
			{ id = "c_strength" },
			{ id = "c_hanged_man" },
			{ id = "c_death" },
			{ id = "c_temperance" },
			{ id = "c_devil" },
			{ id = "c_tower" },
			{ id = "c_star" },
			{ id = "c_moon" },
			{ id = "c_sun" },
			{ id = "c_world" },
			{ id = "c_familiar" },
			{ id = "c_grim" },
			{ id = "c_incantation" },
			{ id = "c_talisman" },
			{ id = "c_aura" },
			{ id = "c_sigil" },
			{ id = "c_ouija" },
			{ id = "c_ectoplasm" },
			{ id = "c_immolate" },
			{ id = "c_deja_vu" },
			{ id = "c_hex" },
			{ id = "c_trance" },
			{ id = "c_medium" },
			{ id = "c_cryptid" },
			{ id = "c_black_hole" },
			{ id = "v_tarot_merchant" },
		},
		banned_tags = {
			{ id = "tag_charm" },
		},
	},
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})

-- === planet_tycoon.lua ===
SMODS.Challenge({
	key = "planet_tycoon",
	rules = {
		custom = {
			{ id = "mp_shop_planets" },
			{ id = "mp_shop_planets_EXTENDED" },
			{ id = "mp_planet_tycoon_CREDITS" },
		},
	},
	restrictions = {
		banned_cards = {
			{ id = "v_planet_merchant", ids = { "v_planet_tycoon" } },
		},
	},
	apply = function(self)
		G.GAME.planet_rate = 360
	end,
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})

-- === polymorph_spam.lua ===
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

-- === psychosis.lua ===
SMODS.Challenge({
	key = "psychosis",
	jokers = {
		{ id = "j_madness", eternal = true },
	},
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})

-- === salvaged_sibyl.lua ===
SMODS.Challenge({
	key = "salvaged_sibyl",
	rules = {
		custom = {
			{ id = "mp_no_shop_planets" },
			{ id = "mp_only_medium" },
			{ id = "mp_only_purple_seals" },
			{ id = "mp_sibyl_CREDITS" },
		},
	},
	consumeables = {
		{ id = "c_medium" },
	},
	restrictions = {
		banned_cards = {
			{ id = "j_constellation" },
			{ id = "j_satellite" },
			{ id = "j_astronomer" },
			{ id = "c_high_priestess" },
			{ id = "v_planet_merchant", ids = { "v_planet_tycoon" } },
			{ id = "v_telescope", ids = { "v_observatory" } },
			{ id = "v_magic_trick", ids = { "v_illusion" } },
			{
				id = "p_celestial_normal_1",
				ids = {
					"p_celestial_normal_2",
					"p_celestial_normal_3",
					"p_celestial_normal_4",
					"p_celestial_jumbo_1",
					"p_celestial_jumbo_2",
					"p_celestial_mega_1",
					"p_celestial_mega_2",
				},
			},
			{
				id = "p_spectral_normal_1",
				ids = {
					"p_spectral_normal_2",
					"p_spectral_jumbo_1",
					"p_spectral_mega_1",
				},
			},
			{
				id = "p_standard_normal_1",
				ids = {
					"p_standard_normal_2",
					"p_standard_normal_3",
					"p_standard_normal_4",
					"p_standard_jumbo_1",
					"p_standard_jumbo_2",
					"p_standard_mega_1",
					"p_standard_mega_2",
				},
			},
		},
	},
	apply = function(self)
		G.GAME.selected_back.atlas = "mp_decks"
		G.GAME.selected_back.pos = { x = 3, y = 0 }
		G.GAME.planet_rate = 0
	end,
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})

local create_card_ref = create_card
function create_card(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append)
	if G.GAME.modifiers.mp_only_medium and _type == "Spectral" then
		G.GAME.banned_keys["c_medium"] = nil
		forced_key = "c_medium"
	end
	return create_card_ref(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append)
end

MP.HOOKS.register_method_hook(Card, "Card", "set_seal", "mp.salvaged_sibyl.only_purple_seals", {
	before = function(ctx)
		if G.GAME.modifiers.mp_only_purple_seals and ctx.args[1] then
			ctx.args[1] = "Purple"
		end
	end,
})

-- === scratch.lua ===
SMODS.Challenge({
	key = "scratch",
	jokers = {
		{ id = "j_half" },
	},
	vouchers = {
		{ id = "v_magic_trick" },
	},
	deck = {
		type = "Challenge Deck",
		cards = {
			{ s = "C", r = "7", e = "m_stone" },
		},
	},
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})

-- === shared_pockets.lua ===
SMODS.Challenge({
	key = "shared_pockets",
	rules = {
		custom = {
			{ id = "mp_shared_pockets" },
		},
	},
	restrictions = {
		banned_cards = {
			{ id = "j_stencil" },
		},
	},
	apply = function(self)
		G.GAME.starting_params.joker_slots = (G.GAME.starting_params.joker_slots or 0) + 1e5
		G.GAME.starting_params.consumable_slots = (G.GAME.starting_params.consumable_slots or 0) + 1e5
		G.GAME.starting_params.hand_size = (G.GAME.starting_params.hand_size or 0) + 7

		G.GAME.mp_shared_pockets = { count = 0, slots = 15 }
	end,
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})

local cardarea_update_ref = CardArea.update
function CardArea:update(dt)
	if self == G.hand and G.GAME.modifiers.mp_shared_pockets then
		self.config.mp_last_size = self.config.mp_last_size or 0
		local slots = (G.jokers.config.card_count - (G.jokers.config.card_limit - 100005))
			+ (G.consumeables.config.card_count - (G.consumeables.config.card_limit - 100002))
		if slots ~= self.config.last_poll_size then
			self:change_size(self.config.mp_last_size - slots)
			self.config.mp_last_size = slots
		end
	end
	local ret = cardarea_update_ref(self, dt)
	if G.GAME.modifiers.mp_shared_pockets then
		G.GAME.mp_shared_pockets.count = G.hand.config.card_count + G.jokers.config.card_count + G.consumeables.config.card_count
		G.GAME.mp_shared_pockets.limit = G.hand.config.card_limit + G.jokers.config.card_count + G.consumeables.config.card_count
	end
	return ret
end

local uie_update_text_ref = UIElement.update_text
function UIElement:update_text()
	if G.GAME.modifiers.mp_shared_pockets then
		if self.config.ref_value == "card_count" then
			if self.config.ref_table == G.hand.config
				or self.config.ref_table == G.jokers.config
				or self.config.ref_table == G.consumeables.config
			then
				self.config.ref_table = G.GAME.mp_shared_pockets
				self.config.ref_value = "count"
			end
		end
		if self.config.ref_value == "total_slots" then
			if self.config.ref_table == G.hand.config.card_limits
				or self.config.ref_table == G.jokers.config.card_limits
				or self.config.ref_table == G.consumeables.config.card_limits
			then
				self.config.ref_table = G.GAME.mp_shared_pockets
				self.config.ref_value = "limit"
			end
		end
	end
	local ret = uie_update_text_ref(self)
	return ret
end

-- === skip_off.lua ===
SMODS.Challenge({
	key = "skip_off",
	jokers = {
		{ id = "j_mp_skip_off", eternal = true },
		{ id = "j_throwback", eternal = true },
	},
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})

-- === speed.lua ===
SMODS.Challenge({
	key = "speed",
	jokers = {
		{ id = "j_mp_conjoined_joker", eternal = true, edition = "negative" },
		{ id = "j_mp_speedrun", eternal = true, edition = "negative" },
	},
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})

-- === twin_towers.lua ===
SMODS.Challenge({
	key = "twin_towers",
	jokers = {
		{ id = "j_obelisk", eternal = true },
		{ id = "j_obelisk", eternal = true },
	},
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})

-- === vantablack.lua ===
SMODS.Challenge({
	key = "vantablack",
	rules = {
		custom = {
			{ id = "mp_vantablack_CREDITS" },
		},
		modifiers = {
			{ id = "joker_slots", value = 8 },
			{ id = "hands", value = 1 },
		},
	},
	apply = function(self)
		G.GAME.selected_back.atlas = "mp_decks"
		G.GAME.selected_back.pos = { x = 3, y = 1 }
	end,
	unlocked = MP.CONTENT.RUNTIME.always_unlocked,
})

