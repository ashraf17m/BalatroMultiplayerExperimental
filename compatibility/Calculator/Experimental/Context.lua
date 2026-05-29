-- Calculator V2 context extraction.

MP = MP or {}
MP.CALCULATOR_V2 = MP.CALCULATOR_V2 or {}

local CALC = MP.CALCULATOR_V2

function CALC.contains_card(cards, card)
	for _, existing in ipairs(cards or {}) do
		if existing == card then return true end
	end
	return false
end

local function copy_card_list(cards)
	local result = {}
	for _, card in ipairs(cards or {}) do
		result[#result + 1] = card
	end
	return result
end

local function sort_cards_by_x(cards)
	table.sort(cards, function(a, b)
		local ax = a and a.T and a.T.x or 0
		local bx = b and b.T and b.T.x or 0
		return ax < bx
	end)
	return cards
end

local function build_held_cards(full_hand)
	local held = {}
	for _, card in ipairs(G.hand and G.hand.cards or {}) do
		if not CALC.contains_card(full_hand, card) then held[#held + 1] = card end
	end
	return held
end

function CALC.build_context()
	if not (G and G.hand and G.hand.highlighted and G.GAME and G.FUNCS and G.FUNCS.get_poker_hand_info) then
		return nil, "game is not in a previewable hand state"
	end

	local full_hand = copy_card_list(G.hand.highlighted)
	if #full_hand == 0 then
		return {
			empty = true,
			full_hand = full_hand,
			scoring_hand = {},
			held_cards = copy_card_list(G.hand.cards),
			jokers = copy_card_list(G.jokers and G.jokers.cards),
			consumeables = copy_card_list(G.consumeables and G.consumeables.cards),
		}
	end

	sort_cards_by_x(full_hand)
	local hand_name, display_name, poker_hands, scoring_hand, non_localized_display = G.FUNCS.get_poker_hand_info(full_hand)
	if not hand_name or not G.GAME.hands or not G.GAME.hands[hand_name] then
		return nil, "could not identify selected poker hand"
	end

	return {
		hand_name = hand_name,
		display_name = display_name,
		non_localized_display = non_localized_display,
		poker_hands = poker_hands or {},
		full_hand = full_hand,
		base_scoring_hand = copy_card_list(scoring_hand or {}),
		scoring_hand = copy_card_list(scoring_hand or {}),
		held_cards = build_held_cards(full_hand),
		jokers = copy_card_list(G.jokers and G.jokers.cards),
		consumeables = copy_card_list(G.consumeables and G.consumeables.cards),
		blind = G.GAME.blind,
	}
end
