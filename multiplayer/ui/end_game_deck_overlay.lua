local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local VIEW_DECK_SCALE = 0.7
local SUIT_ORDER = { "Spades", "Hearts", "Clubs", "Diamonds" }

local function group_nemesis_deck_cards_by_suit()
	local suits = {
		Spades = {},
		Hearts = {},
		Clubs = {},
		Diamonds = {},
	}

	for _, descriptor in ipairs(MP.UI.END_GAME_VIEW_MODEL.get_nemesis_deck_card_descriptors()) do
		local suit_name = descriptor.suit_name
		if suits[suit_name] then
			suits[suit_name][#suits[suit_name] + 1] = descriptor
		end
	end

	for _, suit_cards in pairs(suits) do
		table.sort(suit_cards, function(a, b)
			if a.rank_order ~= b.rank_order then
				return a.rank_order > b.rank_order
			end
			return a.source_index < b.source_index
		end)
	end

	return suits
end

local function emplace_nemesis_deck_card(view_deck, descriptor)
	local card = BALATRO.create_card_object(
		view_deck.T.x + view_deck.T.w / 2,
		view_deck.T.y,
		G.CARD_W * VIEW_DECK_SCALE,
		G.CARD_H * VIEW_DECK_SCALE,
		descriptor.front,
		descriptor.center,
		{}
	)

	if descriptor.edition ~= "none" then
		card:set_edition({ [descriptor.edition] = true }, nil, true)
	end
	if descriptor.seal ~= "none" then
		card:set_seal(descriptor.seal, true)
	end

	card.T.x = view_deck.T.x + view_deck.T.w / 2
	card.T.y = view_deck.T.y
	card:hard_set_T()
	view_deck:emplace(card)
end

local function create_empty_deck_row()
	return {
		n = G.UIT.R,
		config = { align = "cm", minw = 6.5 * G.CARD_W, minh = 0.6 * G.CARD_H, padding = 0.1 },
		nodes = {
			{ n = G.UIT.T, config = { text = "No deck data", colour = G.C.WHITE, scale = 0.45, shadow = true } },
		},
	}
end

local function create_nemesis_deck_rows()
	local deck_tables = {}
	local suits = group_nemesis_deck_cards_by_suit()

	for _, suit_name in ipairs(SUIT_ORDER) do
		local suit_cards = suits[suit_name]
		if suit_cards[1] then
			local view_deck = CardArea(
				G.ROOM.T.x + 0.2 * G.ROOM.T.w / 2,
				G.ROOM.T.h,
				6.5 * G.CARD_W,
				0.6 * G.CARD_H,
				{
					card_limit = #suit_cards,
					type = "title",
					view_deck = true,
					highlight_limit = 0,
					card_w = G.CARD_W * VIEW_DECK_SCALE,
					draw_layers = { "card" },
				}
			)

			deck_tables[#deck_tables + 1] = {
				n = G.UIT.R,
				config = { align = "cm", padding = 0 },
				nodes = {
					{ n = G.UIT.O, config = { object = view_deck } },
				},
			}

			for _, descriptor in ipairs(suit_cards) do
				emplace_nemesis_deck_card(view_deck, descriptor)
			end
		end
	end

	if #deck_tables == 0 then
		deck_tables[1] = create_empty_deck_row()
	end

	return deck_tables
end

function G.UIDEF.view_nemesis_deck()
	G.VIEWING_DECK = true
	return {
		n = G.UIT.ROOT,
		config = { align = "cm", colour = G.C.CLEAR },
		nodes = {
			{ n = G.UIT.R, config = { align = "cm", padding = 0.05 }, nodes = {} },
			{
				n = G.UIT.R,
				config = { align = "cm" },
				nodes = {
					{
						n = G.UIT.C,
						config = { align = "cm", padding = 0.1, r = 0.1, colour = G.C.BLACK, emboss = 0.05 },
						nodes = create_nemesis_deck_rows(),
					},
				},
			},
		},
	}
end

function G.UIDEF.create_UIBox_view_nemesis_deck()
	return create_UIBox_generic_options({
		back_func = "overlay_endgame_menu",
		contents = {
			create_tabs({
				tabs = {
					{
						label = localize("k_nemesis_deck"),
						chosen = true,
						tab_definition_function = G.UIDEF.view_nemesis_deck,
					},
					{
						label = localize("k_your_deck"),
						tab_definition_function = G.UIDEF.view_deck,
					},
				},
				tab_h = 8,
				snap_to_nav = true,
			}),
		},
	})
end

function G.UIDEF.multiplayer_deck()
	return G.UIDEF.challenge_description(
		get_challenge_int_from_id(MP.Rulesets[MP.LOBBY.config.ruleset].challenge_deck),
		nil,
		false
	)
end
