MP.UI = MP.UI or {}
MP.UI.MAIN_MENU = MP.UI.MAIN_MENU or {}

local main_menu = MP.UI.MAIN_MENU
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

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
		delay = 0.06 * (BALATRO.get_game_speed and BALATRO.get_game_speed() or 1),
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
