local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function create_nemesis_source_card(descriptor)
	local card = BALATRO.create_card_object(
		-100,
		-100,
		G.CARD_W,
		G.CARD_H,
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

	return card
end

local function create_nemesis_source_cards()
	local cards = {}
	for _, descriptor in ipairs(MP.UI.END_GAME_VIEW_MODEL.get_nemesis_deck_card_descriptors()) do
		cards[#cards + 1] = create_nemesis_source_card(descriptor)
	end
	return cards
end

local function remove_nemesis_source_cards(cards)
	for _, card in ipairs(cards or {}) do
		if card and card.remove then
			pcall(card.remove, card)
		end
	end
end

local function traceback(error_message)
	return debug and debug.traceback and debug.traceback(error_message) or error_message
end

local function build_native_nemesis_deck_view()
	local cards = create_nemesis_source_cards()
	local previous_playing_cards = G.playing_cards
	G.playing_cards = cards

	local ok, view_or_error = xpcall(function()
		return G.UIDEF.view_deck()
	end, traceback)

	G.playing_cards = previous_playing_cards
	remove_nemesis_source_cards(cards)

	if not ok then
		error(view_or_error)
	end

	return view_or_error
end

function G.UIDEF.view_nemesis_deck()
	return build_native_nemesis_deck_view()
end

function G.UIDEF.create_UIBox_view_nemesis_deck()
	local target_deck_label = MP.UI.get_target_deck_label and MP.UI.get_target_deck_label() or localize("k_nemesis_deck")
	return create_UIBox_generic_options({
		back_func = "overlay_endgame_menu",
		contents = {
			create_tabs({
				tabs = {
					{
						label = target_deck_label,
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
