-- Consolidated Main Menu Module (Shell, Play System, Title Card & Mutators)
-- Replaces 7 fragmented files with a unified, cohesive vertical module.

G = G or {}
G.UIDEF = G.UIDEF or {}
G.FUNCS = G.FUNCS or {}
MP = MP or {}
MP.UI = MP.UI or {}
MP.UI.MAIN_MENU = MP.UI.MAIN_MENU or {}
MP.UI.MAIN_MENU_PLAY = MP.UI.MAIN_MENU_PLAY or {}
MP.UI.MUTATORS_WALL = MP.UI.MUTATORS_WALL or {}
MP.HOOKS = MP.HOOKS or {}
MP.GAME_UPDATE_CYCLE = MP.GAME_UPDATE_CYCLE or {}

local main_menu = MP.UI.MAIN_MENU
local view_model = MP.UI.MAIN_MENU_PLAY
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY or {}

-- ============================================================================
-- SECTION 1: DEV BUILD WARNING
-- (Consolidated from main_menu_dev_warning.lua)
-- ============================================================================

local function create_column(config, nodes)
	config = config or {}
	return { n = G.UIT.C, config = config, nodes = nodes or {} }
end

local function create_blank(width, height)
	return {
		n = G.UIT.C,
		config = {
			minw = width or 0,
			minh = height or 0,
		},
		nodes = {},
	}
end

local function get_client_version()
	return MP.RUNTIME_POLICY and MP.RUNTIME_POLICY.client and tostring(MP.RUNTIME_POLICY.client.version or "")
		or tostring(MP.version or "")
end

BALATRO.set_ui_function("mp_open_install_docs", function()
	if love and love.system and love.system.openURL then
		love.system.openURL("https://balatromp.com/docs/getting-started/installation")
	end
end)

function main_menu.show_dev_build_warning()
	if MP._dev_warning_shown then
		return
	end
	if MP.EXPERIMENTAL and MP.EXPERIMENTAL.suppress_dev_warning then
		return
	end

	local version = get_client_version()
	if not version:lower():match("dev") then
		return
	end

	MP._dev_warning_shown = true

	BALATRO.set_paused(true)
	BALATRO.open_overlay_menu({
		definition = create_UIBox_generic_options({
			no_back = true,
			no_esc = true,
			contents = {
				create_column({ align = "cm", padding = 0.15 }, {
					MP.UI.UTILS.create_row({ align = "cm", padding = 0.1 }, {
						MP.UI.UTILS.create_text_node("MULTIPLAYER", {
							scale = 0.8,
							colour = G.C.UI.TEXT_LIGHT,
						}),
					}),
					MP.UI.UTILS.create_row({ align = "cm", padding = 0.05 }, {
						MP.UI.UTILS.create_text_node("Hand of cards, off the workbench - " .. version, {
							scale = 0.55,
							colour = G.C.MULT,
						}),
					}),
					MP.UI.UTILS.create_row({ align = "cm", padding = 0.04 }, {
						MP.UI.UTILS.create_text_node("You're playing a dev build - jokers may misbehave.", {
							scale = 0.4,
							colour = G.C.UI.TEXT_LIGHT,
						}),
					}),
					MP.UI.UTILS.create_row({ align = "cm", padding = 0.04 }, {
						MP.UI.UTILS.create_text_node("Ranked is locked. You may desync your nemesis.", {
							scale = 0.4,
							colour = G.C.UI.TEXT_LIGHT,
						}),
					}),
					MP.UI.UTILS.create_row({ align = "cm", padding = 0.04 }, {
						MP.UI.UTILS.create_text_node("For a clean shuffle, get the launcher below.", {
							scale = 0.4,
							colour = G.C.UI.TEXT_LIGHT,
						}),
					}),
					MP.UI.UTILS.create_row({ align = "cm", padding = 0.15 }, {
						UIBox_button({
							label = { "Grab the launcher" },
							button = "mp_open_install_docs",
							colour = HEX("72A5F2"),
							minw = 4.2,
							scale = 0.5,
							col = true,
						}),
						create_blank(0.25, 0.1),
						UIBox_button({
							label = { "OK, I'll risk it" },
							button = "exit_overlay_menu",
							colour = G.C.RED,
							minw = 3.2,
							scale = 0.5,
							col = true,
						}),
					}),
				}),
			},
		}),
	})
end

MP.UI.show_dev_build_warning = main_menu.show_dev_build_warning

-- ============================================================================
-- SECTION 2: CUSTOM TITLE CARD
-- (Consolidated from main_menu_title_card.lua)
-- ============================================================================

local function nope_a_joker(card)
	attention_text({
		text = localize("k_nope_ex"),
		scale = 0.8,
		hold = 0.8,
		major = card,
		backdrop_colour = G.C.SECONDARY_SET.Tarot,
		align = (G.STATE == G.STATES.TAROT_PACK or G.STATE == G.STATES.SPECTRAL_PACK) and "tm" or "cm",
		offset = {
			x = 0,
			y = (G.STATE == G.STATES.TAROT_PACK or G.STATE == G.STATES.SPECTRAL_PACK) and -0.2 or 0,
		},
		silent = true,
	})
	BALATRO.queue_event({
		trigger = "after",
		delay = 0.06 * ((tonumber(G and G.SETTINGS and G.SETTINGS["GAMESPEED"] or 1)) or 1),
		blockable = false,
		blocking = false,
		func = function()
			play_sound("tarot2", 0.76, 0.4)
			return true
		end,
	})
	play_sound("tarot2", 1, 0.4)
end

function main_menu.juice_up(thing, a, b)
	if MP.PLATFORM.SMODS.is_mod_loadable("Talisman") then
		local disable_anims = Talisman.config_file.disable_anims
		Talisman.config_file.disable_anims = false
		thing:juice_up(a, b)
		Talisman.config_file.disable_anims = disable_anims
	else
		thing:juice_up(a, b)
	end
end

local function wheel_of_fortune_the_card(card)
	math.randomseed(os.time())
	local chance = math.random(4)
	if chance == 1 then
		local editions = {
			{ name = "e_foil", weight = 499 },
			{ name = "e_holo", weight = 350 },
			{ name = "e_polychrome", weight = 150 },
			{ name = "e_negative", weight = 1 },
		}
		local edition = poll_edition("main_menu" .. os.time(), nil, nil, true, editions)
		card:set_edition(edition, true)
		main_menu.juice_up(card, 0.3, 0.5)
		if BALATRO.set_controller_lock then
			BALATRO.set_controller_lock("edition", false)
		end
	else
		nope_a_joker(card)
		main_menu.juice_up(card, 0.3, 0.5)
	end
end

local function has_mod_manipulating_title_card()
	local modlist = { "BUMod", "Cryptid", "Talisman", "Pokermon" }
	for _, modname in ipairs(modlist) do
		if MP.PLATFORM.SMODS.is_mod_loadable(modname) then
			return true
		end
	end
	return false
end

local function make_wheel_of_fortune_a_card_func(card)
	return function()
		if card then
			wheel_of_fortune_the_card(card)
		end
		return true
	end
end

function main_menu.add_custom_title_card(change_context)
	local only_mod_affecting_title_card = not has_mod_manipulating_title_card()

	if only_mod_affecting_title_card then
		G.title_top.cards[1]:set_base(G.P_CARDS["S_A"], true)
	end

	local title_card = create_card("Base", G.title_top, nil, nil, nil, nil)
	title_card:set_base(G.P_CARDS["H_A"], true)
	G.title_top.T.w = G.title_top.T.w * 1.7675
	G.title_top.T.x = G.title_top.T.x - 0.8
	G.title_top:emplace(title_card)
	title_card.T.w = title_card.T.w * 1.1 * 1.2
	title_card.T.h = title_card.T.h * 1.1 * 1.2
	title_card.no_ui = true
	title_card.states.visible = false

	BALATRO.queue_event({
		trigger = "after",
		delay = change_context == "game" and 1.5 or 0,
		blockable = false,
		blocking = false,
		func = function()
			if change_context == "splash" then
				title_card.states.visible = true
				title_card:start_materialize({ G.C.WHITE, G.C.WHITE }, true, 2.5)
				play_sound("whoosh1", math.random() * 0.1 + 0.3, 0.3)
				play_sound("crumple" .. math.random(1, 5), math.random() * 0.2 + 0.6, 0.65)
			else
				title_card.states.visible = true
				title_card:start_materialize({ G.C.WHITE, G.C.WHITE }, nil, 1.2)
			end
			G.VIBRATION = G.VIBRATION + 1
			return true
		end,
	})

	local wheel_delay = 2
	if only_mod_affecting_title_card then
		BALATRO.queue_event({
			trigger = "after",
			delay = wheel_delay,
			blockable = false,
			blocking = false,
			func = make_wheel_of_fortune_a_card_func(G.title_top.cards[1]),
		})
		wheel_delay = wheel_delay + 1
	end

	BALATRO.queue_event({
		trigger = "after",
		delay = wheel_delay,
		blockable = false,
		blocking = false,
		func = make_wheel_of_fortune_a_card_func(title_card),
	})
end

-- ============================================================================
-- SECTION 3: MODIFIERS OVERLAY
-- (Consolidated from main_menu_modifiers_overlay.lua)
-- ============================================================================

MP.UI.MAIN_MENU_SELECTION = MP.UI.MAIN_MENU_SELECTION or {}

local selection = MP.UI.MAIN_MENU_SELECTION
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function build_smallworld_toggle()
	local toggle_state = {
		val = MP.has_modifier and MP.has_modifier("smallworld") or false,
	}

	return create_toggle({
		id = "modifier_smallworld_toggle",
		label = localize("b_opts_modifier_smallworld"),
		ref_table = toggle_state,
		ref_value = "val",
		callback = function(new_val)
			if new_val then
				MP.add_modifier("smallworld")
			else
				MP.remove_modifier("smallworld")
			end
		end,
	})
end

local function build_modifier_entry(option_node, description_key)
	local message_table = localize(description_key)
	local result_text = {}
	for _, line in ipairs(message_table) do
		result_text[#result_text + 1] = {
			n = G.UIT.R,
			config = { minw = 8.5, maxw = 8.5 },
			nodes = SMODS.localize_box(loc_parse_string(line), {
				default_col = G.C.UI.TEXT_LIGHT,
			}),
		}
	end

	return {
		n = G.UIT.R,
		config = {
			padding = 0.25,
			align = "cm",
			r = 0.25,
			colour = { 1, 1, 1, 0.1 },
		},
		nodes = {
			{
				n = G.UIT.C,
				config = { minw = 5, align = "cm" },
				nodes = { option_node },
			},
			{
				n = G.UIT.C,
				config = { align = "cm" },
				nodes = result_text,
			},
		},
	}
end

function G.FUNCS.mp_return_to_ruleset_selection_from_modifiers()
	local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY or {}
	local ruleset_key = lobby_domain.get_creation_ruleset and lobby_domain.get_creation_ruleset()
		or MP.DEFAULT_LOBBY_CREATION_RULESET

	BALATRO.open_overlay_menu({
		definition = (G.UIDEF.ruleset_selection_tabs or G.UIDEF.ruleset_selection_options)(ruleset_key, {
			preserve_modifiers = true,
		}),
	})
end

function G.FUNCS.mp_open_modifiers_overlay(e)
	local ref_table = e and e.config and e.config.ref_table or {}
	local ruleset = ref_table.ruleset
	if not ruleset then
		return
	end
	local back_func = "mp_return_to_ruleset_selection_from_modifiers"

	local timer_cycle = MP.UI.build_timer_modifier_cycle and MP.UI.build_timer_modifier_cycle() or nil
	local pvp_timer_toggle = MP.UI.build_pvp_timer_toggle and MP.UI.build_pvp_timer_toggle() or nil
	local smallworld_toggle = build_smallworld_toggle()
	local modifier_nodes = {
		timer_cycle and build_modifier_entry(timer_cycle, "k_experimental_modifiers_timers") or nil,
		{ n = G.UIT.R, config = { minh = 0.25 } },
		pvp_timer_toggle and build_modifier_entry(pvp_timer_toggle, "k_experimental_modifiers_pvp_timer") or nil,
		{ n = G.UIT.R, config = { minh = 0.25 } },
		build_modifier_entry(smallworld_toggle, "k_experimental_modifiers_smallworld"),
	}

	BALATRO.open_overlay_menu({
		definition = create_UIBox_generic_options({
			back_func = back_func,
			contents = {
				{
					n = G.UIT.R,
					config = { align = "cm", padding = 0.25, colour = G.C.BLACK, r = 0.25 },
					nodes = {
						{
							n = G.UIT.R,
							nodes = modifier_nodes,
						},
						{ n = G.UIT.R },
						{
							n = G.UIT.R,
							config = { align = "cm" },
							nodes = {
								selection.build_ruleset_continue_button(ruleset, 5, mode),
							},
						},
					},
				},
			},
		}),
	})
end

-- ============================================================================
-- SECTION 4: MUTATORS WALL & CYCLES
-- (Consolidated from main_menu_mutators_wall.lua)
-- ============================================================================

G.FUNCS = G.FUNCS or {}

local function has_modifier(name)
	return MP.has_modifier and MP.has_modifier(name)
end

local function add_modifier(name)
	if MP.add_modifier then MP.add_modifier(name) end
end

local function remove_modifier(name)
	if MP.remove_modifier then MP.remove_modifier(name) end
end

local function timer_modifier_to_index()
	if has_modifier("pressure_timer_plus") then return 4 end
	if has_modifier("pressure_timer") then return 3 end
	if has_modifier("no_animation_timer") then return 2 end
	return 1
end

G.FUNCS.change_modifier_timer = function(args)
	remove_modifier("no_animation_timer")
	remove_modifier("pressure_timer")
	remove_modifier("pressure_timer_plus")
	if args.to_key == 2 then
		add_modifier("no_animation_timer")
	elseif args.to_key == 3 then
		add_modifier("pressure_timer")
	elseif args.to_key == 4 then
		add_modifier("pressure_timer")
		add_modifier("pressure_timer_plus")
	end
end

local function play_ui_sound(name, pitch, volume)
	if play_sound then
		play_sound(name, pitch, volume)
	end
end

local GLASS_VARIANTS = {
	{ label = "Inherit", mod = nil, blurb = "Inherit the main ruleset." },
	{ label = "Vanilla", mod = "glass_vanilla", blurb = "x2 mult." },
	{ label = "Standard", mod = "glass_standard", blurb = "x1.5 (Justice Disabled)." },
	{ label = "Legacy", mod = "glass_legacy", blurb = "x1.5 (Justice Enabled)." },
	{ label = "Experimental", mod = "glass_experimental", blurb = "x2 (Grim/Familiar/Incantation only)." },
}

local function variant_labels(variants)
	local labels = {}
	for idx, variant in ipairs(variants) do
		labels[idx] = variant.label
	end
	return labels
end

local function variant_index(variants)
	for idx, variant in ipairs(variants) do
		if variant.mod and has_modifier(variant.mod) then
			return idx
		end
	end
	return 1
end

local function pick_variant(variants, to_key)
	for _, variant in ipairs(variants) do
		if variant.mod then
			remove_modifier(variant.mod)
		end
	end
	local chosen = variants[to_key]
	if chosen and chosen.mod then
		add_modifier(chosen.mod)
	end
end

local function variant_blurb_func(variants)
	return function(e)
		local txt = variants[variant_index(variants)].blurb
		if e.children[1] and e.children[1].config.text ~= txt then
			e.children[1].config.text = txt
			e.UIBox:recalculate(true)
		end
	end
end

G.FUNCS.change_glass_variant = function(args)
	pick_variant(GLASS_VARIANTS, args.to_key)
end
G.FUNCS.mp_glass_blurb = variant_blurb_func(GLASS_VARIANTS)

local MUTATOR_WALL = {
	{
		name = "ECONOMY",
		colour = G.C.MONEY,
		cells = {
			{ key = "inflation", label = "Inflation", desc = { "Shop prices creep up $1 with", "every card you buy." } },
			{ key = "no_interest", label = "No Interest", desc = { "Savings earn nothing.", "Spend it or lose the edge." } },
			{ key = "discard_tax", label = "Discard Tax", desc = { "Every discard costs $1." } },
			{ key = "frugal", label = "Frugal", desc = { "Unspent discards pay out $1." } },
		},
	},
	{
		name = "MAYHEM",
		colour = G.C.PURPLE,
		cells = {
			{ key = "flipped_cards", label = "Blind Poker", desc = { "Your hand is dealt face-down." } },
			{ key = "debuff_played_cards", label = "Dead Cards", desc = { "Playing cards are debuffed.", "Jokers are the whole engine." } },
			{ key = "all_eternal", label = "No Takebacks", desc = { "Every joker is eternal." } },
			{ key = "shrinking_hand", label = "Heavy Pockets", desc = { "-1 hand size for every $10", "you're holding." } },
		},
	},
	{
		name = "HAZARDS",
		colour = G.C.RED,
		cells = {
			{ key = "gambling_opportunity", label = "No Easy Money", desc = { "No Gold or Lucky cards." } },
			{ key = "no_uncommons", label = "No Uncommons", desc = { "Uncommon jokers are out", "of the pool." } },
			{ key = "bigger_shop", label = "Bigger Shop", desc = { "One extra card slot", "in the shop." } },
			{ key = "chip_cap", label = "Cash Ceiling", desc = { "Chip score can't exceed your", "cash. Greed is the only way up." } },
		},
	},
	{
		name = "CHAOS",
		colour = G.C.ORANGE,
		cells = {
			{ key = "glass_cannon", label = "Glass Cannon", desc = { "Only 2 hands a round — but", "every hand hits for 4x mult." } },
			{ key = "smallworld", label = "Small World", desc = { "75% of the pool banned at", "random. Showman always on." } },
			{ key = "spartan", label = "Spartan", desc = { "No cash from Small or Big", "blinds." } },
			{ key = "pricey_packs", label = "Pricey Packs", desc = { "Booster packs cost more", "for each ante you reach." } },
		},
	},
}

local SOON = {
	cells = {
		{ key = "pvp_reward_draft", label = "Reward Draft", desc = { "Win a PvP blind, draft 1 of 3", "rewards.", "(coming soon)" } },
		{ key = "rubber_band", label = "Rubber Band", desc = { "Falling behind grants", "escalating buffs.", "(coming soon)" } },
		{ key = "score_tax", label = "Score Tax", desc = { "Each hand you play raises", "your opponent's target.", "(coming soon)" } },
	},
}

G.FUNCS.mp_toggle_mutator = function(e)
	local key = e.config.ref_table.key
	MP.MUTATORS_BLIND = false
	if has_modifier(key) then
		remove_modifier(key)
		play_ui_sound("cardSlide2", 1.1, 0.4)
	else
		add_modifier(key)
		play_ui_sound("cardSlide1", 1.1, 0.5)
	end
	e:juice_up(0.2, 0.1)
end

G.FUNCS.mp_mutator_cell_colour = function(e)
	local rt = e.config.ref_table
	local lit = has_modifier(rt.key) and not MP.MUTATORS_BLIND
	e.config.colour = lit and rt.on or rt.off
end

local function roll_mutators()
	for _, category in ipairs(MUTATOR_WALL) do
		for _, cell in ipairs(category.cells) do
			remove_modifier(cell.key)
			if math.random() < 0.35 then
				add_modifier(cell.key)
			end
		end
	end
end

G.FUNCS.mp_randomize_mutators = function(e)
	MP.MUTATORS_BLIND = false
	roll_mutators()
	play_ui_sound("generic1", 1.0, 0.5)
	e:juice_up(0.3, 0.1)
end

G.FUNCS.mp_blind_random_mutators = function(e)
	roll_mutators()
	MP.MUTATORS_BLIND = true
	play_ui_sound("timpani", 1.0, 0.5)
	e:juice_up(0.3, 0.1)
end

local function variant_cycle(args)
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.04 },
		nodes = {
			{
				n = G.UIT.R,
				config = { align = "cm" },
				nodes = {
					create_option_cycle({
						id = args.id,
						label = args.label,
						scale = 0.7,
						options = args.options,
						current_option = args.current_option,
						opt_callback = args.opt_callback,
						w = 4,
						minw = 4,
					}),
				},
			},
			{
				n = G.UIT.R,
				config = { align = "cm", func = args.blurb_func, minh = 0.3 },
				nodes = {
					{ n = G.UIT.T, config = { text = "", scale = 0.3, colour = G.C.UI.TEXT_INACTIVE } },
				},
			},
		},
	}
end

function MP.UI.build_glass_cycle()
	return variant_cycle({
		id = "modifier_glass_option",
		label = "Glass",
		options = variant_labels(GLASS_VARIANTS),
		current_option = variant_index(GLASS_VARIANTS),
		opt_callback = "change_glass_variant",
		blurb_func = "mp_glass_blurb",
	})
end

function MP.UI.build_timer_modifier_cycle()
	return MP.UI.Disableable_Option_Cycle({
		id = "modifier_timer_option",
		enabled_ref_table = { val = true },
		enabled_ref_value = "val",
		label = localize("k_opts_modifier_timer"),
		scale = 0.8,
		options = localize("ml_mp_modifier_timer_opt"),
		current_option = timer_modifier_to_index(),
		opt_callback = "change_modifier_timer",
		minw = 4,
		w = 4,
	})
end

function MP.UI.build_pvp_timer_toggle()
	local toggle_state = {
		val = has_modifier("pvp_timer"),
	}
	return MP.UI.Disableable_Toggle({
		id = "modifier_pvp_timer_toggle",
		label = localize("b_opts_modifier_pvp_timer"),
		enabled_ref_table = { val = true },
		enabled_ref_value = "val",
		ref_table = toggle_state,
		ref_value = "val",
		callback = function(value)
			local enabled = value
			if enabled == nil then
				enabled = toggle_state.val
			end

			if enabled then
				add_modifier("pvp_timer")
			else
				remove_modifier("pvp_timer")
			end
		end,
	})
end

local function mutator_cell(cell, colour)
	local on = colour
	local off = darken(colour, 0.72)
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.035 },
		nodes = {
			{
				n = G.UIT.C,
				config = {
					align = "cm",
					minw = 2.5,
					minh = 0.46,
					padding = 0.06,
					r = 0.1,
					emboss = 0.05,
					hover = true,
					shadow = true,
					colour = off,
					button = "mp_toggle_mutator",
					func = "mp_mutator_cell_colour",
					ref_table = { key = cell.key, on = on, off = off },
					tooltip = { title = cell.label, text = cell.desc },
				},
				nodes = {
					{
						n = G.UIT.T,
						config = {
							text = cell.label,
							scale = 0.34,
							colour = G.C.UI.TEXT_LIGHT,
						},
					},
				},
			},
		},
	}
end

local function mutator_column(category)
	local nodes = {
		{
			n = G.UIT.R,
			config = { align = "cm", padding = 0.04, minh = 0.4 },
			nodes = {
				{ n = G.UIT.T, config = { text = category.name, scale = 0.4, colour = category.colour, shadow = true } },
			},
		},
	}
	for _, cell in ipairs(category.cells) do
		nodes[#nodes + 1] = mutator_cell(cell, category.colour)
	end
	return { n = G.UIT.C, config = { align = "tm", padding = 0.06 }, nodes = nodes }
end

function MP.UI.build_mutators_wall()
	local columns = {}
	for _, category in ipairs(MUTATOR_WALL) do
		columns[#columns + 1] = mutator_column(category)
	end

	local soon_labels = {}
	for _, cell in ipairs(SOON.cells) do
		soon_labels[#soon_labels + 1] = cell.label
	end

	return {
		n = G.UIT.R,
		config = { align = "cm" },
		nodes = {
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.02 },
				nodes = {
					{ n = G.UIT.T, config = { text = "MUTATORS", scale = 0.5, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
				},
			},
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.02 },
				nodes = {
					{ n = G.UIT.T, config = { text = "stack freely · hover for details", scale = 0.3, colour = G.C.UI.TEXT_INACTIVE } },
				},
			},
			{ n = G.UIT.R, config = { align = "cm", padding = 0.04 }, nodes = columns },
			{ n = G.UIT.R, config = { minh = 0.06 } },
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.02 },
				nodes = {
					{ n = G.UIT.T, config = { text = "coming soon · " .. table.concat(soon_labels, " · "), scale = 0.3, colour = G.C.UI.TEXT_INACTIVE } },
				},
			},
		},
	}
end

function MP.UI.build_mutator_randomize_row()
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.05 },
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm", padding = 0.05 },
				nodes = {
					UIBox_button({
						id = "mp_randomize_mutators_btn",
						button = "mp_randomize_mutators",
						label = { "Randomize" },
						colour = G.C.ORANGE,
						minw = 2.8,
						minh = 0.7,
						scale = 0.4,
						hover = true,
						shadow = true,
					}),
				},
			},
			{
				n = G.UIT.C,
				config = { align = "cm", padding = 0.05 },
				nodes = {
					UIBox_button({
						id = "mp_blind_random_mutators_btn",
						button = "mp_blind_random_mutators",
						label = { "Blind Random" },
						colour = G.C.PURPLE,
						minw = 2.8,
						minh = 0.7,
						scale = 0.4,
						hover = true,
						shadow = true,
					}),
				},
			},
		},
	}
end

-- ============================================================================
-- SECTION 5: MAIN MENU PLAY VIEW MODEL & LOBBY BROWSER
-- (Consolidated from main_menu_play_view_model.lua)
-- ============================================================================

local INLINE_JOIN_LOBBY_INPUT_ID = "mp_main_join_lobby_input"
local JOIN_LOBBY_BUTTON_WIDTH = 2.95
local MAIN_MENU_BUTTON_HEIGHT = 1.15
local JOIN_LOBBY_BUTTON_SCALE = 0.5
local PASTE_ICON_ATLAS_KEY = "mp_paste_icon"
local PASTE_ICON_BUTTON_WIDTH = 1.35
local PASTE_ICON_SIZE = 0.9
local LOBBY_BROWSER_ROWS_ID = "mp_lobby_browser_rows"
local LOBBY_BROWSER_NOTICE_ID = "mp_lobby_browser_notice"
local JOIN_REQUEST_NOTIFICATION_ID = "mp_join_request_notification"
local JOIN_REQUEST_CANCEL_BUTTON_WIDTH = 4.42
local LOBBY_TYPE_COLOUR = { 0.08, 0.58, 0.70, 1 }
local LOBBY_ROW_TRAY_COLOUR = { 0.13, 0.24, 0.25, 1 }
local LOBBY_ROW_TEXT_SCALE = 0.45
local LOBBY_BROWSER_ROWS_PER_PAGE = 6
local LOBBY_BROWSER_HIDDEN_NAME = "*******"

view_model.inline_join_lobby_input_active = view_model.inline_join_lobby_input_active or false
view_model.browse_lobbies_page = view_model.browse_lobbies_page or 1
view_model.browse_lobbies_notice = view_model.browse_lobbies_notice or { display = "", expires_at = 0 }
view_model.hide_browse_lobby_names = view_model.hide_browse_lobby_names or false
view_model.browse_lobby_name_toggle = view_model.browse_lobby_name_toggle or { display = "Hide Names" }

local function append_node(contents, node)
	if node then
		contents[#contents + 1] = node
	end
end

local function get_real_time()
	if G and G.TIMERS and G.TIMERS.REAL then
		return G.TIMERS.REAL
	end
	if love and love.timer and love.timer.getTime then
		return love.timer.getTime()
	end
	return os.clock()
end

local function localize_or_default(key, fallback)
	if type(localize) ~= "function" then
		return fallback or tostring(key or "")
	end
	local text = localize(key)
	if text == nil or text == "ERROR" then
		return fallback or tostring(key or "")
	end
	return text
end

local function update_browse_lobby_name_toggle_label()
	view_model.browse_lobby_name_toggle.display = view_model.hide_browse_lobby_names and "Show Names" or "Hide Names"
end

local function try_localize(key)
	if type(localize) ~= "function" then
		return nil
	end
	local text = localize(key)
	if text == nil or text == "ERROR" then
		return nil
	end
	return text
end

local function create_text_node(text, scale, colour)
	return {
		n = G.UIT.T,
		config = {
			text = tostring(text or ""),
			scale = scale or 0.4,
			colour = colour or G.C.UI.TEXT_LIGHT,
			shadow = true,
		},
	}
end

local function create_play_button(label_key, colour, button, minh)
	return UIBox_button({
		label = { localize(label_key) },
		colour = colour,
		button = button,
		minw = 5,
		minh = minh,
	})
end

local function create_overlay_button(id, label, colour, button, minw, scale, extra_config)
	local config = {
		id = id,
		label = { label },
		colour = colour,
		button = button,
		minw = minw or 3,
		minh = 0.65,
		scale = scale or 0.42,
		hover = true,
		shadow = true,
	}

	for key, value in pairs(extra_config or {}) do
		config[key] = value
	end

	return UIBox_button(config)
end

local function create_main_menu_button(spec)
	return UIBox_button({
		id = spec.id,
		label = { localize(spec.label_key) },
		colour = spec.colour,
		button = spec.button,
		minw = spec.minw or 2.9,
		minh = spec.minh or 1.15,
		scale = spec.scale or 0.5,
		col = true,
	})
end

local function create_dynamic_button(spec)
	local config = {
		id = spec.id,
		align = "cm",
		padding = 0.05,
		r = 0.1,
		hover = true,
		shadow = true,
		colour = spec.colour,
		button = spec.button,
		minw = spec.minw or 3,
		minh = spec.minh or MAIN_MENU_BUTTON_HEIGHT,
	}

	for key, value in pairs(spec.extra_config or {}) do
		config[key] = value
	end

	return {
		n = G.UIT.C,
		config = config,
		nodes = {
			{
				n = G.UIT.O,
				config = {
					object = DynaText({
						string = {{ ref_table = spec.ref_table, ref_value = spec.ref_value or "display" }},
						colours = { spec.text_colour or G.C.UI.TEXT_LIGHT },
						shadow = true,
						silent = true,
						scale = spec.scale or 0.48,
						pop_in = 0,
					}),
				},
			},
		},
	}
end

local function create_paste_icon_sprite_node()
	local atlas = SMODS and SMODS.get_atlas and SMODS.get_atlas(PASTE_ICON_ATLAS_KEY)
	if atlas then
		if atlas.image and not atlas.mp_nearest_filter_applied then
			if atlas.image.setFilter then
				atlas.image:setFilter("nearest", "nearest")
			end
			if atlas.image.setMipmapFilter then
				pcall(function()
					atlas.image:setMipmapFilter("nearest", 0)
				end)
			end
			atlas.mp_nearest_filter_applied = true
		end

		local icon = Sprite(0, 0, PASTE_ICON_SIZE, PASTE_ICON_SIZE, atlas, { x = 0, y = 0 })
		icon.states.drag.can = false
		return { n = G.UIT.O, config = { w = PASTE_ICON_SIZE, h = PASTE_ICON_SIZE, object = icon } }
	end

	return create_text_node("V", 0.52, G.C.UI.TEXT_LIGHT)
end

local function create_paste_icon_button()
	return {
		n = G.UIT.C,
		config = { align = "cm" },
		nodes = {
			{
				n = G.UIT.C,
				config = {
					id = "mp_main_join_clipboard",
					align = "cm",
					padding = 0,
					r = 0.1,
					hover = true,
					colour = G.C.PURPLE,
					button = "join_from_clipboard",
					minw = PASTE_ICON_BUTTON_WIDTH,
					minh = MAIN_MENU_BUTTON_HEIGHT,
					shadow = true,
					on_demand_tooltip = {
						text = { try_localize("k_paste") or "Paste Code" },
					},
				},
				nodes = {
					create_paste_icon_sprite_node(),
				},
			},
		},
	}
end

local function get_pending_join_request()
	return lobby_domain.get_pending_join_request and lobby_domain.get_pending_join_request() or nil
end

local function get_join_request_remaining_seconds(request)
	if lobby_domain.get_join_request_remaining_seconds then
		return lobby_domain.get_join_request_remaining_seconds(request)
	end
	return 0
end

local function update_join_request_text(request)
	if type(request) ~= "table" then
		return 0
	end

	local remaining = get_join_request_remaining_seconds(request)
	request.remaining_display = tostring(remaining) .. "s"
	request.display = localize_or_default("b_cancel", "Cancel") .. " " .. request.remaining_display
	request.notice_display = request.remaining_display
	return remaining
end

local function create_pending_join_request_button(minw, scale)
	local request = get_pending_join_request()
	if not request then
		return nil
	end

	update_join_request_text(request)
	return create_dynamic_button({
		id = "mp_main_pending_join_request",
		ref_table = request,
		colour = G.C.ORANGE,
		button = "cancel_lobby_join_request",
		minw = minw or JOIN_REQUEST_CANCEL_BUTTON_WIDTH,
		minh = MAIN_MENU_BUTTON_HEIGHT,
		scale = scale or 0.48,
		extra_config = {
			request_id = request.requestId,
			ref_table = { request_id = request.requestId },
		},
	})
end

local function create_inline_join_lobby_input()
	if lobby_domain.ensure_setup_state then
		lobby_domain.ensure_setup_state()
	end
	MP.LOBBY = MP.LOBBY or {}
	MP.LOBBY.setup = MP.LOBBY.setup or {}
	MP.LOBBY.setup.temp_code = MP.LOBBY.setup.temp_code or ""

	local input = create_text_input({
		id = INLINE_JOIN_LOBBY_INPUT_ID,
		w = JOIN_LOBBY_BUTTON_WIDTH,
		h = MAIN_MENU_BUTTON_HEIGHT,
		max_length = 5,
		all_caps = true,
		prompt_text = localize_or_default("k_lobby_code", "Code"),
		ref_table = MP.LOBBY.setup,
		ref_value = "temp_code",
		extended_corpus = false,
		keyboard_offset = 4,
		text_scale = JOIN_LOBBY_BUTTON_SCALE,
		colour = G.C.RED,
		hooked_colour = darken(copy_table(G.C.RED), 0.3),
		callback = function()
			BALATRO.call_ui_function("submit_inline_join_lobby")
		end,
	})

	input.config.minw = JOIN_LOBBY_BUTTON_WIDTH
	input.config.maxw = JOIN_LOBBY_BUTTON_WIDTH
	input.config.minh = MAIN_MENU_BUTTON_HEIGHT
	input.config.maxh = MAIN_MENU_BUTTON_HEIGHT

	local input_body = input.nodes and input.nodes[1]
	if input_body and input_body.config then
		input_body.config.minw = JOIN_LOBBY_BUTTON_WIDTH
		input_body.config.maxw = JOIN_LOBBY_BUTTON_WIDTH
		input_body.config.minh = MAIN_MENU_BUTTON_HEIGHT
		input_body.config.maxh = MAIN_MENU_BUTTON_HEIGHT
	end

	return input
end

function view_model.get_inline_join_lobby_input_id()
	return INLINE_JOIN_LOBBY_INPUT_ID
end

function view_model.set_inline_join_lobby_input_active(active)
	view_model.inline_join_lobby_input_active = not not active
end

function view_model.cancel_inline_join_lobby_input()
	if not view_model.inline_join_lobby_input_active then
		return false
	end

	view_model.inline_join_lobby_input_active = false
	if lobby_domain.set_setup_temp_code then
		lobby_domain.set_setup_temp_code("")
	elseif MP.LOBBY and MP.LOBBY.setup then
		MP.LOBBY.setup.temp_code = ""
	end

	return true
end

local function append_play_button_if(contents, condition, label_key, colour, button, minh)
	if condition then
		append_node(contents, create_play_button(label_key, colour, button, minh))
	end
end

local function append_multiplayer_lobby_create_buttons(contents)
	if not (MP.LOBBY and MP.LOBBY.client and MP.LOBBY.client.connected) then
		return
	end

	append_node(contents, create_play_button("b_create_party", G.C.GREEN, "create_group_lobby"))
end

local function append_resume_match_button(contents)
	if not (MP.RESUME and MP.RESUME.has_saved_resume and MP.RESUME.has_saved_resume()) then
		return
	end

	append_node(contents, create_play_button("b_resume_match", G.C.GREEN, "resume_match"))
end

function view_model.build_play_options_contents()
	local contents = {}

	append_resume_match_button(contents)
	append_multiplayer_lobby_create_buttons(contents)

	local is_connected = MP.LOBBY.client.connected
	append_play_button_if(contents, is_connected, "b_browse_lobbies", G.C.BLUE, "browse_lobbies", 0.7)
	append_play_button_if(contents, is_connected, "b_join_lobby", G.C.RED, "join_lobby", 0.7)
	append_play_button_if(contents, not is_connected, "b_reconnect", G.C.RED, "reconnect")

	return contents
end

function view_model.build_main_menu_button_nodes()
	local buttons = {}

	if MP.RESUME and MP.RESUME.has_saved_resume and MP.RESUME.has_saved_resume() then
		append_node(buttons, create_main_menu_button({
			id = "mp_main_resume_match",
			label_key = "b_resume_match",
			colour = G.C.GREEN,
			button = "resume_match",
			minw = 3.65,
			scale = 0.46,
		}))
	end

	local is_connected = MP.LOBBY and MP.LOBBY.client and MP.LOBBY.client.connected
	if is_connected then
		local pending_join_request = get_pending_join_request()
		append_node(buttons, create_main_menu_button({
			id = "mp_main_create_party",
			label_key = "b_create_lobby",
			colour = G.C.GREEN,
			button = "create_group_lobby",
			minw = 3.3,
			scale = 0.5,
		}))
		append_node(buttons, create_main_menu_button({
			id = "mp_main_browse_lobbies",
			label_key = "b_browse_lobbies",
			colour = G.C.BLUE,
			button = "browse_lobbies",
			minw = 4.15,
			scale = 0.48,
		}))
		if pending_join_request then
			append_node(buttons, create_pending_join_request_button())
		elseif view_model.inline_join_lobby_input_active then
			append_node(buttons, create_inline_join_lobby_input())
		else
			append_node(buttons, create_main_menu_button({
				id = "mp_main_join_lobby",
				label_key = "b_enter_code",
				colour = G.C.RED,
				button = "join_lobby",
				minw = JOIN_LOBBY_BUTTON_WIDTH,
				minh = MAIN_MENU_BUTTON_HEIGHT,
				scale = JOIN_LOBBY_BUTTON_SCALE,
			}))
		end
		if not pending_join_request then
			append_node(buttons, create_paste_icon_button())
		end
	else
		append_node(buttons, create_main_menu_button({
			id = "mp_main_reconnect",
			label_key = "b_reconnect",
			colour = G.C.RED,
			button = "reconnect",
			minw = 3.15,
			scale = 0.52,
		}))
	end

	return buttons
end

function view_model.create_main_menu_button_row()
	local buttons = view_model.build_main_menu_button_nodes()
	if not buttons or #buttons == 0 then
		return nil
	end

	return {
		n = G.UIT.R,
		config = {
			align = "cm",
			padding = 0.12,
			colour = G.C.CLEAR,
		},
		nodes = buttons,
	}
end

function view_model.create_play_options_overlay()
	return create_UIBox_generic_options({
		contents = view_model.build_play_options_contents(),
	})
end

local function shorten_text(text, max_length)
	text = tostring(text or "")
	max_length = max_length or 16
	if #text <= max_length then
		return text
	end
	return text:sub(1, math.max(1, max_length - 3)) .. "..."
end

local function title_case_key(value)
	local label = tostring(value or "?"):gsub("_", " ")
	return (label:gsub("^%l", string.upper))
end

local function display_ruleset(ruleset_key)
	local key = tostring(ruleset_key or "")
	if key == "" then
		return "?"
	end

	local ruleset = MP.Rulesets and MP.Rulesets[key] or nil
	if ruleset and ruleset.name then
		return tostring(ruleset.name)
	end

	local suffix = key:gsub("^ruleset_mp_", "")
	return try_localize("k_" .. suffix) or title_case_key(suffix)
end

local function display_gamemode(game_mode)
	local key = tostring(game_mode or "")
	if key == "" then
		return "?"
	end

	local full_key = key:find("^gamemode_mp_") and key or ("gamemode_mp_" .. key)
	local gamemode = MP.Gamemodes and MP.Gamemodes[full_key] or nil
	if gamemode and gamemode.name then
		return tostring(gamemode.name)
	end

	if key == "attrition" then
		return localize_or_default("k_attrition_name", "Attrition")
	elseif key == "coop" then
		return localize_or_default("k_cooperative", "Co-op")
	end
	return title_case_key(key:gsub("^gamemode_mp_", ""))
end

local function display_lobby_type(lobby_type)
	local key = tostring(lobby_type or "")
	if key == "1v1" then
		return "1v1"
	elseif key == "ffa" then
		return "FFA"
	elseif key == "teams" then
		return "Teams"
	elseif key == "duels" then
		return "Duels"
	elseif key == "coop" then
		return "Co-op"
	end
	return title_case_key(key)
end

local function get_lobby_browser_owner_display(lobby)
	if view_model.hide_browse_lobby_names then
		return LOBBY_BROWSER_HIDDEN_NAME
	end

	return shorten_text(lobby.ownerUsername or lobby.owner_username or "Guest", 12)
end

local function create_lobby_row_spacer(width)
	return { n = G.UIT.B, config = { w = width or 0.08, h = 0.01 } }
end

local function create_lobby_row_pill(nodes, width, align, colour)
	return {
		n = G.UIT.C,
		config = {
			align = align or "cm",
			minw = width,
			maxw = width,
			minh = 0.58,
			padding = 0.03,
			r = 0.08,
			colour = colour,
			line_emboss = 0.35,
		},
		nodes = nodes,
	}
end

local function create_lobby_row_tray(nodes)
	return {
		n = G.UIT.R,
		config = {
			align = "cm",
			minw = 12.3,
			maxw = 12.3,
			minh = 0.76,
			padding = 0.04,
			r = 0.1,
			colour = LOBBY_ROW_TRAY_COLOUR,
			line_emboss = 0.25,
		},
		nodes = nodes,
	}
end

local function create_lobby_row_text_pill(text, width, align, scale, colour)
	return create_lobby_row_pill({
		create_text_node(text, scale or LOBBY_ROW_TEXT_SCALE, G.C.UI.TEXT_LIGHT),
	}, width, align, colour)
end

local function create_lobby_row_dynamic_pill(ref_table, ref_value, width, align, scale, colour)
	return create_lobby_row_pill({
		{
			n = G.UIT.O,
			config = {
				object = DynaText({
					string = {{ ref_table = ref_table, ref_value = ref_value or "display" }},
					colours = { G.C.UI.TEXT_LIGHT },
					shadow = true,
					silent = true,
					scale = scale or LOBBY_ROW_TEXT_SCALE,
					pop_in = 0,
				}),
			},
		},
	}, width, align, colour)
end

local function lobby_browser_row_colour(access_mode)
	if access_mode == "ask_first" then
		return G.C.BLUE
	elseif access_mode == "private" then
		return G.C.PURPLE
	end

	return G.C.GREEN
end

local function display_lobby_access(access_mode)
	if access_mode == "ask_first" then
		return "Ask First"
	elseif access_mode == "private" then
		return "Private"
	end

	return "Public"
end

local function build_lobby_browser_row(lobby, index)
	local access_mode = tostring(lobby.accessMode or lobby.access_mode or "public")
	local access_colour = lobby_browser_row_colour(access_mode)
	local access_label = display_lobby_access(access_mode)
	local code = tostring(lobby.code or "")
	local pending_request = get_pending_join_request()
	local pending_code = pending_request and tostring(pending_request.code or ""):upper() or nil
	local is_pending_lobby = pending_code and pending_code == code:upper()
	local owner = get_lobby_browser_owner_display(lobby)
	local player_count = tostring(lobby.playerCount or lobby.player_count or "?")
	local max_players = tostring(lobby.maxPlayers or lobby.max_players or "?")
	local lobby_type = shorten_text(display_lobby_type(lobby.lobbyType or lobby.lobby_type), 8)
	local ruleset = shorten_text(display_ruleset(lobby.ruleset), 16)
	local gamemode = shorten_text(display_gamemode(lobby.gameMode or lobby.game_mode), 11)
	if is_pending_lobby then
		update_join_request_text(pending_request)
	end

	return {
		n = G.UIT.R,
		config = {
			id = "browse_lobby_" .. tostring(index),
			button = is_pending_lobby and "cancel_lobby_join_request" or "join_browsed_lobby",
			lobby_code = code,
			request_id = is_pending_lobby and pending_request.requestId or nil,
			align = "cm",
			padding = 0,
			minw = 12.5,
			minh = 0.78,
			colour = G.C.CLEAR,
			hover = true,
		},
		nodes = {
			create_lobby_row_tray({
				create_lobby_row_text_pill(owner, 2.65, "cm", LOBBY_ROW_TEXT_SCALE, G.C.BLUE),
				create_lobby_row_spacer(0.06),
				create_lobby_row_text_pill(player_count .. "/" .. max_players, 0.95, "cm", LOBBY_ROW_TEXT_SCALE, G.C.RED),
				create_lobby_row_spacer(0.06),
				create_lobby_row_text_pill(lobby_type, 1.05, "cm", LOBBY_ROW_TEXT_SCALE, LOBBY_TYPE_COLOUR),
				create_lobby_row_spacer(0.06),
				create_lobby_row_text_pill(ruleset, 2.85, "cm", LOBBY_ROW_TEXT_SCALE, G.C.RED),
				create_lobby_row_spacer(0.06),
				create_lobby_row_text_pill(gamemode, 2.25, "cm", LOBBY_ROW_TEXT_SCALE, G.C.ORANGE),
				create_lobby_row_spacer(0.06),
				is_pending_lobby and create_lobby_row_dynamic_pill(pending_request, "display", 1.75, "cm", LOBBY_ROW_TEXT_SCALE, access_colour)
					or create_lobby_row_text_pill(access_label, 1.75, "cm", LOBBY_ROW_TEXT_SCALE, access_colour),
			}),
		},
	}
end

local function get_lobby_browser_page(total_pages)
	total_pages = math.max(1, tonumber(total_pages) or 1)
	local page = math.floor(tonumber(view_model.browse_lobbies_page) or 1)
	page = math.min(math.max(1, page), total_pages)
	view_model.browse_lobbies_page = page
	return page
end

function view_model.set_browse_lobbies_page(page)
	view_model.browse_lobbies_page = math.max(1, math.floor(tonumber(page) or 1))
	return view_model.browse_lobbies_page
end

function view_model.step_browse_lobbies_page(delta)
	local lobbies = lobby_domain.get_browser_lobbies and lobby_domain.get_browser_lobbies() or {}
	local total_pages = math.max(1, math.ceil(#lobbies / LOBBY_BROWSER_ROWS_PER_PAGE))
	local page = get_lobby_browser_page(total_pages) + (tonumber(delta) or 0)
	view_model.browse_lobbies_page = math.min(math.max(1, page), total_pages)
	if view_model.refresh_browse_lobbies_overlay then
		view_model.refresh_browse_lobbies_overlay()
	end
	return view_model.browse_lobbies_page
end

function view_model.toggle_browse_lobby_names()
	view_model.hide_browse_lobby_names = not view_model.hide_browse_lobby_names
	update_browse_lobby_name_toggle_label()
	if view_model.refresh_browse_lobbies_overlay then
		view_model.refresh_browse_lobbies_overlay()
	end
	return view_model.hide_browse_lobby_names
end

local function build_lobby_browser_page_button(label, button)
	return {
		n = G.UIT.C,
		config = {
			align = "cm",
			minw = 0.68,
			minh = 0.58,
			padding = 0.025,
			r = 0.08,
			colour = G.C.PURPLE,
			line_emboss = 0.3,
			shadow = true,
			hover = true,
			button = button,
		},
		nodes = {
			create_text_node(label, 0.45, G.C.UI.TEXT_LIGHT),
		},
	}
end

local function build_lobby_browser_page_switcher(current_page, total_pages)
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.1, minw = 12.3 },
		nodes = {
			build_lobby_browser_page_button("<", "browse_lobbies_prev_page"),
			create_lobby_row_spacer(0.08),
			{
				n = G.UIT.C,
				config = {
					align = "cm",
					minw = 1.35,
					minh = 0.58,
					padding = 0.025,
					r = 0.08,
					colour = LOBBY_ROW_TRAY_COLOUR,
					line_emboss = 0.25,
				},
				nodes = {
					create_text_node(tostring(current_page) .. "/" .. tostring(total_pages), 0.45, G.C.UI.TEXT_LIGHT),
				},
			},
			create_lobby_row_spacer(0.08),
			build_lobby_browser_page_button(">", "browse_lobbies_next_page"),
		},
	}
end

local function build_lobby_browser_empty_row_slot()
	return {
		n = G.UIT.R,
		config = {
			align = "cm",
			padding = 0,
			minw = 12.5,
			minh = 0.78,
			colour = G.C.CLEAR,
		},
		nodes = {
			{ n = G.UIT.B, config = { w = 0.01, h = 0.01 } },
		},
	}
end

local function build_lobby_browser_rows()
	local rows = {}
	if lobby_domain.is_browser_pending and lobby_domain.is_browser_pending() then
		return {
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.3, minw = 10.3, minh = 4.6 },
				nodes = {
					create_text_node(localize_or_default("k_loading_lobbies", "Loading lobbies..."), 0.48, G.C.UI.TEXT_INACTIVE),
				},
			},
		}
	end

	local lobbies = lobby_domain.get_browser_lobbies and lobby_domain.get_browser_lobbies() or {}
	if #lobbies == 0 then
		return {
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.3, minw = 10.3, minh = 4.6 },
				nodes = {
					create_text_node(localize_or_default("k_no_public_lobbies", "No lobbies found"), 0.46, G.C.UI.TEXT_INACTIVE),
				},
			},
		}
	end

	local total_pages = math.max(1, math.ceil(#lobbies / LOBBY_BROWSER_ROWS_PER_PAGE))
	local current_page = get_lobby_browser_page(total_pages)
	local first_index = ((current_page - 1) * LOBBY_BROWSER_ROWS_PER_PAGE) + 1
	local last_index = math.min(#lobbies, first_index + LOBBY_BROWSER_ROWS_PER_PAGE - 1)
	for index = first_index, last_index do
		rows[#rows + 1] = build_lobby_browser_row(lobbies[index], index)
	end
	if total_pages > 1 then
		local visible_rows = last_index - first_index + 1
		for _ = visible_rows + 1, LOBBY_BROWSER_ROWS_PER_PAGE do
			rows[#rows + 1] = build_lobby_browser_empty_row_slot()
		end
		rows[#rows + 1] = build_lobby_browser_page_switcher(current_page, total_pages)
	end
	return rows
end

local function build_lobby_browser_footer_button()
	return create_overlay_button(
		"refresh_lobbies_button",
		localize_or_default("b_refresh_lobbies", "Refresh"),
		G.C.ORANGE,
		"refresh_lobbies",
		3.45,
		0.5
	)
end

local function build_lobby_browser_name_toggle_button()
	update_browse_lobby_name_toggle_label()
	return create_dynamic_button({
		id = "hide_browse_lobby_names_button",
		ref_table = view_model.browse_lobby_name_toggle,
		ref_value = "display",
		colour = G.C.BLUE,
		button = "toggle_browse_lobby_names",
		minw = 2.35,
		minh = 0.68,
		scale = 0.45,
	})
end

local function build_lobby_browser_title_row()
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.08, minw = 12.8 },
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm", minw = 2.35 },
				nodes = {
					{ n = G.UIT.B, config = { w = 0.01, h = 0.01 } },
				},
			},
			{
				n = G.UIT.C,
				config = { align = "cm", minw = 8.1 },
				nodes = {
					create_text_node(localize_or_default("k_browse_lobbies", "Browse Lobbies"), 0.62),
				},
			},
			{
				n = G.UIT.C,
				config = { align = "cm", minw = 2.35 },
				nodes = {
					build_lobby_browser_name_toggle_button(),
				},
			},
		},
	}
end

local function build_lobby_browser_notice_row()
	return {
		n = G.UIT.R,
		config = {
			id = LOBBY_BROWSER_NOTICE_ID,
			align = "cm",
			padding = 0.02,
			minh = 0.42,
			minw = 12.8,
		},
		nodes = {
			{
				n = G.UIT.O,
				config = {
					object = DynaText({
						string = {{ ref_table = view_model.browse_lobbies_notice, ref_value = "display" }},
						colours = { G.C.UI.TEXT_LIGHT },
						shadow = true,
						silent = true,
						scale = LOBBY_ROW_TEXT_SCALE,
						maxw = 12.2,
						pop_in = 0,
					}),
				},
			},
		},
	}
end

local function lobby_browser_panel_height(rows)
	return 5.7
end

local function set_overlay_marker(marker_name)
	if BALATRO.set_overlay_property then
		BALATRO.set_overlay_property(marker_name, true)
	elseif G and G.OVERLAY_MENU then
		G.OVERLAY_MENU[marker_name] = true
	end
end

function view_model.is_browse_lobbies_overlay_open()
	local overlay = (G and G.OVERLAY_MENU) or G.OVERLAY_MENU
	return not not (overlay and overlay.is_mp_lobby_browser)
end

local function normalize_browse_lobbies_notice_message(message)
	return tostring(message or ""):gsub("\r\n", "\n"):gsub("\n", "  ")
end

function view_model.show_browse_lobbies_notice(message, duration)
	if not view_model.is_browse_lobbies_overlay_open() then
		return false
	end

	view_model.browse_lobbies_notice.display = normalize_browse_lobbies_notice_message(message)
	view_model.browse_lobbies_notice.expires_at = get_real_time() + (tonumber(duration) or 4)
	return true
end

function view_model.clear_browse_lobbies_notice()
	view_model.browse_lobbies_notice.display = ""
	view_model.browse_lobbies_notice.expires_at = 0
end

function view_model.update_browse_lobbies_notice()
	local notice = view_model.browse_lobbies_notice
	if
		notice
		and notice.display
		and notice.display ~= ""
		and tonumber(notice.expires_at)
		and get_real_time() >= tonumber(notice.expires_at)
	then
		view_model.clear_browse_lobbies_notice()
	end
end

function view_model.create_browse_lobbies_overlay()
	local browser_rows = build_lobby_browser_rows()
	return create_UIBox_generic_options({
		back_func = "exit_overlay_menu",
		contents = {
			build_lobby_browser_title_row(),
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.08 },
				nodes = {
					{
						n = G.UIT.C,
						config = {
							id = LOBBY_BROWSER_ROWS_ID,
							align = "tm",
							padding = 0.12,
							r = 0.1,
							minw = 12.8,
							minh = lobby_browser_panel_height(browser_rows),
							colour = G.C.CLEAR,
						},
						nodes = browser_rows,
					},
				},
			},
			build_lobby_browser_notice_row(),
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.08 },
				nodes = {
					build_lobby_browser_footer_button(),
				},
			},
		},
	})
end

function view_model.open_browse_lobbies_overlay()
	BALATRO.set_paused(true)
	BALATRO.open_overlay_menu({
		definition = view_model.create_browse_lobbies_overlay(),
	})
	set_overlay_marker("is_mp_lobby_browser")
	return true
end

function view_model.refresh_browse_lobbies_overlay()
	local overlay = (G and G.OVERLAY_MENU) or G.OVERLAY_MENU
	if not (overlay and overlay.is_mp_lobby_browser) then
		return false
	end
	local rows_container = overlay.get_UIE_by_ID and overlay:get_UIE_by_ID(LOBBY_BROWSER_ROWS_ID) or nil
	if not (rows_container and rows_container.children and rows_container.UIBox and rows_container.UIBox.set_parent_child) then
		if BALATRO.exit_overlay_menu then
			BALATRO.exit_overlay_menu()
		end
		return view_model.open_browse_lobbies_overlay()
	end

	for i = #rows_container.children, 1, -1 do
		rows_container.children[i]:remove()
		table.remove(rows_container.children, i)
	end
	local browser_rows = build_lobby_browser_rows()
	rows_container.config.minh = lobby_browser_panel_height(browser_rows)
	for _, node in ipairs(browser_rows) do
		rows_container.UIBox:set_parent_child(node, rows_container)
	end
	rows_container.UIBox:recalculate()
	return true
end

function view_model.create_join_request_notification(request)
	request = request or {}
	local username = shorten_text(request.username or "Guest", 18)
	update_join_request_text(request)
	return {
		n = G.UIT.ROOT,
		config = {
			id = JOIN_REQUEST_NOTIFICATION_ID,
			align = "cm",
			padding = 0.1,
			r = 0.12,
			minw = 5.7,
			colour = G.C.L_BLACK,
			outline = 1,
			outline_colour = G.C.WHITE,
			line_emboss = 0.5,
			emboss = 0.05,
			shadow = true,
		},
		nodes = {
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.08, maxw = 5.2 },
				nodes = {
					create_text_node(username, 0.42, G.C.GREEN),
					create_text_node(" " .. localize_or_default("k_wants_to_join", "wants to join"), 0.42, G.C.UI.TEXT_LIGHT),
				},
			},
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.02 },
				nodes = {
					{
						n = G.UIT.O,
						config = {
							object = DynaText({
								string = {{ ref_table = request, ref_value = "notice_display" }},
								colours = { G.C.UI.TEXT_LIGHT },
								shadow = true,
								silent = true,
								scale = 0.42,
								pop_in = 0,
							}),
						},
					},
				},
			},
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.06 },
				nodes = {
					create_overlay_button(
						"approve_lobby_join_request_button",
						localize_or_default("b_accept", "Accept"),
						G.C.GREEN,
						"approve_lobby_join_request",
						1.45,
						0.38,
						{ request_id = request.requestId, ref_table = { request_id = request.requestId }, col = true }
					),
					create_overlay_button(
						"deny_lobby_join_request_button",
						localize_or_default("b_deny", "Deny"),
						G.C.RED,
						"deny_lobby_join_request",
						1.35,
						0.38,
						{ request_id = request.requestId, ref_table = { request_id = request.requestId }, col = true }
					),
					create_overlay_button(
						"block_lobby_join_request_button",
						localize_or_default("b_block", "Block"),
						G.C.PURPLE,
						"block_lobby_join_request",
						1.45,
						0.38,
						{ request_id = request.requestId, ref_table = { request_id = request.requestId }, col = true }
					),
				},
			},
		},
	}
end

local function remove_join_request_notification_immediate()
	if G.MP_JOIN_REQUEST_NOTIFICATION_UI then
		G.MP_JOIN_REQUEST_NOTIFICATION_UI:remove()
		G.MP_JOIN_REQUEST_NOTIFICATION_UI = nil
	end
	G.MP_JOIN_REQUEST_NOTIFICATION = nil
	G.MP_JOIN_REQUEST_NOTIFICATION_CLOSING = nil
end

local function collect_live_join_requests()
	local requests = lobby_domain.get_pending_join_requests and lobby_domain.get_pending_join_requests() or {}
	local queued = {}
	for _, request in pairs(requests) do
		if type(request) == "table" and request.requestId then
			if update_join_request_text(request) <= 0 then
				if lobby_domain.remove_join_request then
					lobby_domain.remove_join_request(request.requestId)
				end
			else
				queued[#queued + 1] = request
			end
		end
	end

	table.sort(queued, function(left, right)
		local left_order = tonumber(left.queueOrder) or tonumber(left.expiresAt) or 0
		local right_order = tonumber(right.queueOrder) or tonumber(right.expiresAt) or 0
		return left_order < right_order
	end)

	return queued
end

function view_model.show_next_join_request_notification()
	if G.MP_JOIN_REQUEST_NOTIFICATION_UI or G.MP_JOIN_REQUEST_NOTIFICATION or G.MP_JOIN_REQUEST_NOTIFICATION_CLOSING then
		return false
	end

	local queued = collect_live_join_requests()
	if #queued == 0 then
		return false
	end

	return view_model.open_join_request_notification(queued[1])
end

function view_model.close_join_request_notification(request_id)
	local active_request = G.MP_JOIN_REQUEST_NOTIFICATION
	if active_request and request_id and tostring(active_request.requestId) ~= tostring(request_id) then
		return false
	end

	local notification = G.MP_JOIN_REQUEST_NOTIFICATION_UI
	if not notification then
		G.MP_JOIN_REQUEST_NOTIFICATION = nil
		return false
	end

	G.MP_JOIN_REQUEST_NOTIFICATION_UI = nil
	G.MP_JOIN_REQUEST_NOTIFICATION = nil
	G.MP_JOIN_REQUEST_NOTIFICATION_CLOSING = true
	if notification.alignment and notification.alignment.offset then
		BALATRO.queue_event({
			trigger = "ease",
			timer = "REAL",
			blockable = false,
			blocking = false,
			ref_table = notification.alignment.offset,
			ref_value = "x",
			ease_to = 4.0,
			delay = 0.08,
			func = function(t)
				return t
			end,
		})
		BALATRO.queue_event({
			trigger = "after",
			timer = "REAL",
			blockable = false,
			blocking = false,
			delay = 0.1,
			func = function()
				notification:remove()
				G.MP_JOIN_REQUEST_NOTIFICATION_CLOSING = nil
				view_model.show_next_join_request_notification()
				return true
			end,
		})
	else
		notification:remove()
		G.MP_JOIN_REQUEST_NOTIFICATION_CLOSING = nil
		view_model.show_next_join_request_notification()
	end
	return true
end

function view_model.open_join_request_notification(request)
	if not (request and request.requestId) then
		return false
	end
	if G.MP_JOIN_REQUEST_NOTIFICATION_UI or G.MP_JOIN_REQUEST_NOTIFICATION or G.MP_JOIN_REQUEST_NOTIFICATION_CLOSING then
		return true
	end
	remove_join_request_notification_immediate()
	G.MP_JOIN_REQUEST_NOTIFICATION = request
	G.MP_JOIN_REQUEST_NOTIFICATION_UI = UIBox({
		definition = view_model.create_join_request_notification(request),
		config = {
			align = "cri",
			bond = "Weak",
			offset = { x = 4.0, y = -1.1 },
			major = G.ROOM_ATTACH,
		},
	})
	if G.MP_JOIN_REQUEST_NOTIFICATION_UI and G.MP_JOIN_REQUEST_NOTIFICATION_UI.alignment then
		BALATRO.queue_event({
			trigger = "ease",
			timer = "REAL",
			blockable = false,
			blocking = false,
			ref_table = G.MP_JOIN_REQUEST_NOTIFICATION_UI.alignment.offset,
			ref_value = "x",
			ease_to = -0.15,
			delay = 0.08,
			func = function(t)
				return t
			end,
		})
	end
	return true
end

function view_model.update_join_request_ui()
	local pending_request = get_pending_join_request()
	if pending_request then
		if update_join_request_text(pending_request) <= 0 then
			if lobby_domain.clear_pending_join_request then
				lobby_domain.clear_pending_join_request(pending_request.requestId)
			end
			if MP.UI and MP.UI.refresh_main_menu_multiplayer_buttons then
				MP.UI.refresh_main_menu_multiplayer_buttons()
			end
			view_model.refresh_browse_lobbies_overlay()
		end
	end

	local notification_request = G.MP_JOIN_REQUEST_NOTIFICATION
	if notification_request then
		if update_join_request_text(notification_request) <= 0 then
			if lobby_domain.remove_join_request then
				lobby_domain.remove_join_request(notification_request.requestId)
			end
			view_model.close_join_request_notification(notification_request.requestId)
		end
	elseif not G.MP_JOIN_REQUEST_NOTIFICATION_CLOSING then
		view_model.show_next_join_request_notification()
	end
end

if MP.GAME_UPDATE_CYCLE and MP.GAME_UPDATE_CYCLE.register_after then
	MP.GAME_UPDATE_CYCLE.register_after("mp.ui.join_request_notifications", function()
		view_model.update_join_request_ui()
	end, 90)
	MP.GAME_UPDATE_CYCLE.register_after("mp.ui.browse_lobbies_notice", function()
		view_model.update_browse_lobbies_notice()
	end, 91)
end

function view_model.create_join_lobby_overlay()
	return create_UIBox_generic_options({
		back_func = "exit_overlay_menu",
		contents = {
			{
				n = G.UIT.R,
				config = {
					padding = 0,
					align = "cm",
				},
				nodes = {
					{
						n = G.UIT.R,
						config = {
							padding = 0.5,
							align = "cm",
						},
						nodes = {
							create_text_input({
								w = 4,
								h = 1,
								max_length = 5,
								all_caps = true,
								prompt_text = localize("k_enter_lobby_code"),
								ref_table = MP.LOBBY.setup,
								ref_value = "temp_code",
								extended_corpus = false,
								keyboard_offset = 4,
								minw = 5,
								callback = function()
									MP.ACTIONS.join_lobby(MP.LOBBY.setup.temp_code)
								end,
							}),
						},
					},
				},
			},
		},
	})
end

function view_model.create_weekly_interrupt_overlay()
	return create_UIBox_generic_options({
		back_func = "create_group_lobby",
		contents = {
			{
				n = G.UIT.R,
				config = {
					align = "cm",
					padding = 0.1,
				},
				nodes = {
					{
						n = G.UIT.T,
						config = {
							text = "A new weekly ruleset is available!",
							colour = G.C.UI.TEXT_LIGHT,
							scale = 0.45,
						},
					},
				},
			},
			{
				n = G.UIT.R,
				config = {
					align = "cm",
					padding = 0.2,
				},
				nodes = {
					{
						n = G.UIT.T,
						config = {
							text = localize("k_currently_colon") .. localize("k_weekly_" .. MP.LOBBY.setup.fetched_weekly),
							colour = darken(G.C.UI.TEXT_LIGHT, 0.2),
							scale = 0.35,
						},
					},
				},
			},
			create_play_button("k_sync_locally", G.C.DARK_EDITION, "set_weekly"),
		},
	})
end

G.UIDEF.override_main_menu_play_button = view_model.create_play_options_overlay
G.UIDEF.create_UIBox_join_lobby_button = view_model.create_join_lobby_overlay
G.UIDEF.weekly_interrupt = view_model.create_weekly_interrupt_overlay

-- ============================================================================
-- SECTION 6: MAIN MENU PLAY CONTROLLER & ACTIONS
-- (Consolidated from main_menu_play_controller.lua)
-- ============================================================================

local function refresh_initial_tab_contents()
	local overlay = (G and G.OVERLAY_MENU) or nil
	if not (overlay and overlay.get_UIE_by_ID) then
		return
	end

	local tab_contents = overlay:get_UIE_by_ID("tab_contents")
	local tab_group = overlay:get_UIE_by_ID("tab_shoulders") or overlay:get_UIE_by_ID("no_shoulders")
	local current_tab = tab_group
		and tab_group.config
		and tab_group.config.ref_table
		and tab_group.config.ref_table.current
		and tab_group.config.ref_table.current.v
		or nil
	if not (tab_contents and tab_contents.config and current_tab and current_tab.tab_definition_function) then
		return
	end

	if tab_contents.config.object and tab_contents.config.object.remove then
		tab_contents.config.object:remove()
	end
	tab_contents.config.object = UIBox({
		definition = current_tab.tab_definition_function(current_tab.tab_definition_function_args),
		config = {
			offset = { x = 0, y = 0 },
			parent = tab_contents,
			type = "cm",
		},
	})
	if tab_contents.UIBox and tab_contents.UIBox.recalculate then
		tab_contents.UIBox:recalculate()
	end
end

local function open_paused_overlay(definition, selected_input_id, options)
	BALATRO.set_paused(true)
	BALATRO.open_overlay_menu({
		definition = definition,
	})

	if options and options.refresh_initial_tab_contents then
		refresh_initial_tab_contents()
	end

	if selected_input_id then
		BALATRO.select_overlay_text_input_by_id(selected_input_id)
	end
end

local function clear_singleplayer_selection()
	if lobby_domain.clear_config_selection then
		lobby_domain.clear_config_selection()
	end
end

local function store_join_lobby_code(temp_code)
	if lobby_domain.set_setup_temp_code then
		lobby_domain.set_setup_temp_code(temp_code)
	end
end

local function normalize_join_lobby_code(code)
	return string.sub(string.upper(tostring(code or ""):gsub("[^%a]", "")), 1, 5)
end

local function request_lobby_browser_list(clear_lobbies)
	local main_menu_play_ui = MP.UI and MP.UI.MAIN_MENU_PLAY or {}
	if lobby_domain.set_browser_pending then
		lobby_domain.set_browser_pending(true)
	end
	if clear_lobbies and lobby_domain.set_browser_lobbies then
		lobby_domain.set_browser_lobbies({})
	end
	if clear_lobbies and main_menu_play_ui.set_browse_lobbies_page then
		main_menu_play_ui.set_browse_lobbies_page(1)
	end

	if
		not (main_menu_play_ui.refresh_browse_lobbies_overlay and main_menu_play_ui.refresh_browse_lobbies_overlay())
		and main_menu_play_ui.open_browse_lobbies_overlay
	then
		main_menu_play_ui.open_browse_lobbies_overlay()
	end

	if MP.ACTIONS and MP.ACTIONS.request_lobby_list then
		MP.ACTIONS.request_lobby_list()
	elseif MP.UI and MP.UI.UTILS and MP.UI.UTILS.overlay_message then
		if lobby_domain.set_browser_pending then
			lobby_domain.set_browser_pending(false)
		end
		MP.UI.UTILS.overlay_message("Lobby browsing is not available on this server.")
	end
end

local function get_config_request_id(e)
	local config = e and e.config or {}
	return config.request_id
		or (config.ref_table and config.ref_table.request_id)
		or nil
end

local function respond_lobby_join_request(e, accepted, blocked)
	local request_id = get_config_request_id(e)
	if not request_id then
		return
	end

	if MP.ACTIONS and MP.ACTIONS.respond_lobby_join_request then
		MP.ACTIONS.respond_lobby_join_request(request_id, accepted, blocked)
	end
	if lobby_domain.remove_join_request then
		lobby_domain.remove_join_request(request_id)
	end
	local main_menu_play_ui = MP.UI and MP.UI.MAIN_MENU_PLAY or {}
	local closed_notification = main_menu_play_ui.close_join_request_notification
		and main_menu_play_ui.close_join_request_notification(request_id)
	if BALATRO.exit_overlay_menu and not closed_notification and G.OVERLAY_MENU and G.OVERLAY_MENU.is_mp_join_request then
		BALATRO.exit_overlay_menu()
	end
end

local function cancel_pending_lobby_join_request(request_id)
	local pending_request = lobby_domain.get_pending_join_request and lobby_domain.get_pending_join_request() or nil
	request_id = request_id or (pending_request and pending_request.requestId) or nil
	if not request_id then
		return
	end

	if MP.ACTIONS and MP.ACTIONS.cancel_lobby_join_request then
		MP.ACTIONS.cancel_lobby_join_request(request_id)
	end
	if lobby_domain.clear_pending_join_request then
		lobby_domain.clear_pending_join_request(request_id)
	end

	if MP.UI and MP.UI.refresh_main_menu_multiplayer_buttons then
		MP.UI.refresh_main_menu_multiplayer_buttons()
	end
	local main_menu_play_ui = MP.UI and MP.UI.MAIN_MENU_PLAY or {}
	if main_menu_play_ui.refresh_browse_lobbies_overlay then
		main_menu_play_ui.refresh_browse_lobbies_overlay()
	end
end

local function refresh_main_menu_ui()
	if G.MAIN_MENU_UI then
		G.MAIN_MENU_UI:remove()
	end
	if G.PROFILE_BUTTON then
		G.PROFILE_BUTTON:remove()
	end
	if set_main_menu_UI then
		set_main_menu_UI()
	end
end

local function refresh_main_menu_multiplayer_buttons(select_input_id)
	if MP.UI and MP.UI.refresh_main_menu_multiplayer_buttons then
		return MP.UI.refresh_main_menu_multiplayer_buttons({
			select_text_input_id = select_input_id,
		})
	end

	return refresh_main_menu_ui()
end

local function create_ruleset_selection_overlay(initial_ruleset_key, options)
	if G.UIDEF.ruleset_selection_tabs then
		return G.UIDEF.ruleset_selection_tabs(initial_ruleset_key, options)
	end
	return G.UIDEF.ruleset_selection_options(initial_ruleset_key, options)
end

local function create_gamemode_selection_overlay(initial_gamemode_key, options)
	if G.UIDEF.gamemode_selection_tabs then
		return G.UIDEF.gamemode_selection_tabs(initial_gamemode_key, options)
	end
	return G.UIDEF.gamemode_selection_options(initial_gamemode_key, options)
end

local function open_multiplayer_lobby_creation(lobby_type)
	if lobby_type and lobby_domain.set_lobby_type then
		lobby_domain.set_lobby_type(lobby_type)
	end

	local ruleset_key = lobby_domain.get_creation_ruleset and lobby_domain.get_creation_ruleset()
		or MP.DEFAULT_LOBBY_CREATION_RULESET
	open_paused_overlay(create_ruleset_selection_overlay(ruleset_key), nil, {
		refresh_initial_tab_contents = true,
	})
end

BALATRO.set_ui_function("start_vanilla_sp", function(e)
	clear_singleplayer_selection()
	BALATRO.call_ui_function("setup_run", e)
end)

BALATRO.set_ui_function("play_options", function()
	if (G and G.OVERLAY_MENU) then
		BALATRO.exit_overlay_menu()
	else
		refresh_main_menu_ui()
	end
end)

BALATRO.set_ui_function("resume_match", function()
	local pending_resume, error_message
	if MP.RESUME and MP.RESUME.begin_manual_resume then
		pending_resume, error_message = MP.RESUME.begin_manual_resume()
	end
	if not pending_resume then
		MP.UI.UTILS.overlay_message(error_message or "No saved match was found.")
		return
	end
	if MP.RESUME and MP.RESUME.repair_saved_run_snapshot then
		MP.RESUME.repair_saved_run_snapshot(pending_resume.run_snapshot)
	end

	BALATRO.exit_overlay_menu()

	if MP.LOBBY.client and MP.LOBBY.client.connected then
		MP.ACTIONS.rejoin_lobby(pending_resume.meta.lobby_code, pending_resume.meta.reconnect_token)
	else
		MP.ACTIONS.connect()
	end
end)

BALATRO.set_ui_function("create_group_lobby", function()
	open_multiplayer_lobby_creation(MP.LOBBY_TYPES.FFA)
end)

BALATRO.set_ui_function("return_to_ruleset_selection", function()
	local ruleset_key = lobby_domain.get_creation_ruleset and lobby_domain.get_creation_ruleset()
		or MP.DEFAULT_LOBBY_CREATION_RULESET
	open_paused_overlay(create_ruleset_selection_overlay(ruleset_key, {
		preserve_modifiers = true,
	}), nil, {
		refresh_initial_tab_contents = true,
	})
end)

BALATRO.set_ui_function("select_gamemode", function()
	if MP.ACTIONS and MP.ACTIONS.request_coop_saves then
		MP.ACTIONS.request_coop_saves()
	end
	local gamemode_key = lobby_domain.get_creation_gamemode and lobby_domain.get_creation_gamemode()
		or MP.DEFAULT_LOBBY_CREATION_GAMEMODE
	open_paused_overlay(create_gamemode_selection_overlay(gamemode_key), nil, {
		refresh_initial_tab_contents = true,
	})
end)

BALATRO.set_ui_function("join_lobby", function()
	local main_menu_play_ui = MP.UI and MP.UI.MAIN_MENU_PLAY or {}
	if main_menu_play_ui.set_inline_join_lobby_input_active then
		main_menu_play_ui.set_inline_join_lobby_input_active(true)
	end
	store_join_lobby_code("")
	refresh_main_menu_multiplayer_buttons(
		main_menu_play_ui.get_inline_join_lobby_input_id and main_menu_play_ui.get_inline_join_lobby_input_id()
	)
end)

BALATRO.set_ui_function("submit_inline_join_lobby", function()
	local lobby_code = normalize_join_lobby_code(MP.LOBBY and MP.LOBBY.setup and MP.LOBBY.setup.temp_code or "")
	if lobby_code == "" then
		return
	end

	local main_menu_play_ui = MP.UI and MP.UI.MAIN_MENU_PLAY or {}
	if main_menu_play_ui.set_inline_join_lobby_input_active then
		main_menu_play_ui.set_inline_join_lobby_input_active(false)
	end
	store_join_lobby_code(lobby_code)
	refresh_main_menu_multiplayer_buttons()
	MP.ACTIONS.join_lobby(lobby_code)
end)

BALATRO.set_ui_function("browse_lobbies", function()
	request_lobby_browser_list(true)
end)

BALATRO.set_ui_function("refresh_lobbies", function()
	request_lobby_browser_list(false)
end)

BALATRO.set_ui_function("browse_lobbies_prev_page", function()
	local main_menu_play_ui = MP.UI and MP.UI.MAIN_MENU_PLAY or {}
	if main_menu_play_ui.step_browse_lobbies_page then
		main_menu_play_ui.step_browse_lobbies_page(-1)
	end
end)

BALATRO.set_ui_function("browse_lobbies_next_page", function()
	local main_menu_play_ui = MP.UI and MP.UI.MAIN_MENU_PLAY or {}
	if main_menu_play_ui.step_browse_lobbies_page then
		main_menu_play_ui.step_browse_lobbies_page(1)
	end
end)

BALATRO.set_ui_function("toggle_browse_lobby_names", function()
	local main_menu_play_ui = MP.UI and MP.UI.MAIN_MENU_PLAY or {}
	if main_menu_play_ui.toggle_browse_lobby_names then
		main_menu_play_ui.toggle_browse_lobby_names()
	end
end)

BALATRO.set_ui_function("join_browsed_lobby", function(e)
	local lobby_code = e and e.config and e.config.lobby_code or nil
	if not lobby_code or lobby_code == "" then
		return
	end

	store_join_lobby_code(lobby_code)
	MP.ACTIONS.join_lobby(lobby_code)
end)

BALATRO.set_ui_function("approve_lobby_join_request", function(e)
	respond_lobby_join_request(e, true)
end)

BALATRO.set_ui_function("deny_lobby_join_request", function(e)
	respond_lobby_join_request(e, false)
end)

BALATRO.set_ui_function("block_lobby_join_request", function(e)
	respond_lobby_join_request(e, false, true)
end)

BALATRO.set_ui_function("cancel_lobby_join_request", function(e)
	cancel_pending_lobby_join_request(get_config_request_id(e))
end)

BALATRO.set_ui_function("weekly_interrupt", function()
	if (not MP.LOBBY.config.weekly) or (MP.LOBBY.config.weekly ~= MP.LOBBY.setup.fetched_weekly) then
		BALATRO.set_paused(true)

		BALATRO.open_overlay_menu({
			definition = G.UIDEF.weekly_interrupt(not not MP.LOBBY.config.weekly),
		})
		return true
	end
	return false
end)

BALATRO.set_ui_function("set_weekly", function()
	MP.PLATFORM.SMODS.set_config_value("weekly", MP.LOBBY.setup.fetched_weekly, MP)
	MP.save_current_config()
	MP.PLATFORM.SMODS.restart_game()
end)

BALATRO.set_ui_function("join_from_clipboard", function()
	local paste = MP.UTILS.get_from_clipboard()
	if not paste then
		return
	end

	local temp_code = normalize_join_lobby_code(paste)
	store_join_lobby_code(temp_code)
	MP.ACTIONS.join_lobby(temp_code)
end)

BALATRO.set_ui_function("start_lobby", function()
	BALATRO.set_paused(false)

	local prepared, error_key = lobby_domain.prepare_config_for_creation()
	if not prepared then
		MP.UI.UTILS.overlay_message(localize(error_key == "ruleset_not_found" and "k_ruleset_not_found" or error_key))
		return
	end

	MP.ACTIONS.create_lobby(string.sub(MP.LOBBY.config.gamemode, 13))
	BALATRO.exit_overlay_menu()
end)

for gamemode, _ in pairs(MP.Gamemodes or {}) do
	BALATRO.set_ui_function("force_" .. gamemode, function(e)
		lobby_domain.set_creation_gamemode(gamemode)
		BALATRO.call_ui_function("start_lobby", e)
	end)
end

-- ============================================================================
-- SECTION 7: MAIN MENU SHELL & INTEGRATION HOOKS
-- (Consolidated from main_menu_shell.lua)
-- ============================================================================

local multiplayer_name = (MP.display_name or MP.name) or "Multiplayer"
local multiplayer_version = MP.RUNTIME_POLICY and MP.RUNTIME_POLICY.client and MP.RUNTIME_POLICY.client.version or MP.version or ""

function main_menu.build_multiplayer_version_display(name, version)
	if version == "" then
		return name
	end

	return name .. " " .. version
end

local multiplayer_version_display = main_menu.build_multiplayer_version_display(multiplayer_name, multiplayer_version)

function main_menu.add_version_display()
	UIBox({
		definition = {
			n = G.UIT.ROOT,
			config = {
				align = "cm",
				colour = G.C.UI.TRANSPARENT_DARK,
			},
			nodes = {
				{
					n = G.UIT.T,
					config = {
						scale = 0.3,
						text = multiplayer_version_display,
						colour = G.C.UI.TEXT_LIGHT,
					},
				},
			},
		},
		config = {
			align = "tri",
			bond = "Weak",
			offset = {
				x = 0,
				y = 0.6,
			},
			major = G.ROOM_ATTACH,
		},
	})
end

if MP.HOOKS and MP.HOOKS.register_method_hook then
	MP.HOOKS.register_method_hook(Game, "Game", "main_menu", "mp.ui.main_menu_shell", {
		after = function(ctx)
			local change_context = ctx.args and ctx.args[1]
			if main_menu.add_custom_title_card then
				main_menu.add_custom_title_card(change_context)
			end
			main_menu.add_version_display()
			if main_menu.show_dev_build_warning then
				main_menu.show_dev_build_warning()
			end
		end,
	})
end

local create_UIBox_main_menu_buttons_ref = create_UIBox_main_menu_buttons
local function get_main_menu_primary_button(menu)
	return menu
		and menu.nodes
		and menu.nodes[1]
		and menu.nodes[1].nodes
		and menu.nodes[1].nodes[1]
		and menu.nodes[1].nodes[1].nodes
		and menu.nodes[1].nodes[1].nodes[1]
		and menu.nodes[1].nodes[1].nodes[1].nodes
		and menu.nodes[1].nodes[1].nodes[1].nodes[1]
		or nil
end

local function get_main_menu_button_panel(menu_ui)
	local play_button = menu_ui
		and menu_ui.get_UIE_by_ID
		and menu_ui:get_UIE_by_ID("main_menu_play")
		or nil
	return play_button and play_button.parent and play_button.parent.parent or nil
end

local function remove_multiplayer_main_menu_row()
	if G.MP_MAIN_MENU_BUTTONS_UI then
		G.MP_MAIN_MENU_BUTTONS_UI:remove()
		G.MP_MAIN_MENU_BUTTONS_UI = nil
	end
end

local function add_multiplayer_main_menu_row(options)
	options = options or {}
	remove_multiplayer_main_menu_row()

	if not (G and G.STAGES and G.STAGE == G.STAGES.MAIN_MENU or false) then
		return
	end

	local main_menu_ui = (G and G.MAIN_MENU_UI or nil) or G.MAIN_MENU_UI
	if not main_menu_ui or main_menu_ui.is_mp_lobby_menu then
		return
	end

	local panel = get_main_menu_button_panel(main_menu_ui)
	if not panel then
		return
	end

	local main_menu_play = MP.UI and MP.UI.MAIN_MENU_PLAY or nil
	local row = main_menu_play
		and main_menu_play.create_main_menu_button_row
		and main_menu_play.create_main_menu_button_row()
	if row then
		G.MP_MAIN_MENU_BUTTONS_UI = UIBox({
			definition = {
				n = G.UIT.ROOT,
				config = {
					align = "cm",
					colour = G.C.CLEAR,
				},
				nodes = { row },
			},
			config = {
				align = "tm",
				offset = { x = 0, y = -0.08 },
				major = panel,
				bond = "Weak",
			},
		})
		if options.select_text_input_id then
			local input = G.MP_MAIN_MENU_BUTTONS_UI:get_UIE_by_ID(options.select_text_input_id)
			if input and BALATRO.select_text_input then
				BALATRO.select_text_input(input)
			end
		end
	end
end

function MP.UI.refresh_main_menu_multiplayer_buttons(options)
	return add_multiplayer_main_menu_row(options)
end

---@diagnostic disable-next-line: lowercase-global
function create_UIBox_main_menu_buttons()
	local menu = create_UIBox_main_menu_buttons_ref()
	local play_button = get_main_menu_primary_button(menu)
	if play_button and play_button.config then
		play_button.config.button = "start_vanilla_sp"
	end
	return menu
end

local set_main_menu_UI_ref = set_main_menu_UI
---@diagnostic disable-next-line: lowercase-global
function set_main_menu_UI()
	remove_multiplayer_main_menu_row()
	local ret = set_main_menu_UI_ref()
	add_multiplayer_main_menu_row()
	return ret
end

local function cancel_inline_join_lobby_input()
	local main_menu_play = MP.UI and MP.UI.MAIN_MENU_PLAY or nil
	if not (main_menu_play and main_menu_play.cancel_inline_join_lobby_input) then
		return false
	end

	local cancelled = main_menu_play.cancel_inline_join_lobby_input()
	if cancelled then
		add_multiplayer_main_menu_row()
	end
	return cancelled
end

main_menu.cancel_inline_join_lobby_input = cancel_inline_join_lobby_input

local main_menu_join_input_cancel_wrappers = {}
local function wrap_join_input_cancel_button(name)
	if main_menu_join_input_cancel_wrappers[name] then
		return
	end

	local funcs = BALATRO.ensure_ui_functions and BALATRO.ensure_ui_functions() or G.FUNCS
	local original = funcs and funcs[name] or nil
	if type(original) ~= "function" then
		return
	end

	main_menu_join_input_cancel_wrappers[name] = true
	funcs[name] = function(...)
		cancel_inline_join_lobby_input()
		return original(...)
	end
end

for _, button_name in ipairs({
	"start_vanilla_sp",
	"start_run",
	"setup_run",
	"resume_match",
	"create_group_lobby",
	"browse_lobbies",
	"join_from_clipboard",
	"play_options",
	"reconnect",
	"options",
	"quit",
	"quit_cta",
	"your_collection",
	"mods_button",
	"profile_select",
	"language_selection",
	"go_to_discord",
	"go_to_discord_loc",
	"go_to_twitter",
}) do
	wrap_join_input_cancel_button(button_name)
end

local function queue_screenwipe_alpha_fade(colour)
	BALATRO.queue_event({
		trigger = "ease",
		no_delete = true,
		blockable = false,
		blocking = false,
		timer = "REAL",
		ref_table = colour,
		ref_value = 4,
		ease_to = 0,
		delay = 0.3,
		func = function(t)
			return t
		end,
	})
end

local function queue_screenwipe_after(delay_time, blocking, func)
	BALATRO.queue_event({
		trigger = "after",
		delay = delay_time,
		no_delete = true,
		blocking = blocking,
		timer = "REAL",
		func = func,
	})
end

G.FUNCS.wipe_off = function()
	remove_multiplayer_main_menu_row()
	BALATRO.queue_event({
		no_delete = true,
		func = function()
			delay(0.3)
			if not G.screenwipe then
				return true
			end
			G.screenwipe.children.particles.max = 0
			queue_screenwipe_alpha_fade(G.screenwipe.colours.black)
			queue_screenwipe_alpha_fade(G.screenwipe.colours.white)
			return true
		end,
	})
	queue_screenwipe_after(0.55, false, function()
		if not G.screenwipe then
			return true
		end
		if G.screenwipecard then
			G.screenwipecard:start_dissolve({ G.C.BLACK, G.C.ORANGE, G.C.GOLD, G.C.RED })
		end
		if G.screenwipe:get_UIE_by_ID("text") then
			for _, child in ipairs(G.screenwipe:get_UIE_by_ID("text").children) do
				child.children[1].config.object:pop_out(4)
			end
		end
		return true
	end)
	queue_screenwipe_after(1.1, false, function()
		if not G.screenwipe then
			return true
		end
		G.screenwipe.children.particles:remove()
		G.screenwipe:remove()
		G.screenwipe.children.particles = nil
		G.screenwipe = nil
		G.screenwipecard = nil
		return true
	end)
	queue_screenwipe_after(1.2, true, function()
		return true
	end)
end

