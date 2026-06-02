MP.UI = MP.UI or {}
MP.UI.END_GAME_VIEW_MODEL = MP.UI.END_GAME_VIEW_MODEL or {}

local view_model = MP.UI.END_GAME_VIEW_MODEL
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local SUIT_NAME_BY_CODE = {
	S = "Spades",
	H = "Hearts",
	C = "Clubs",
	D = "Diamonds",
}

local RANK_ORDER_BY_VALUE = {
	["2"] = 2,
	["3"] = 3,
	["4"] = 4,
	["5"] = 5,
	["6"] = 6,
	["7"] = 7,
	["8"] = 8,
	["9"] = 9,
	["10"] = 10,
	Jack = 10.1,
	Queen = 10.2,
	King = 10.3,
	Ace = 11.4,
}

local function get_end_game_view_runtime()
	return MP.UI.get_end_game_view_runtime and MP.UI.get_end_game_view_runtime() or nil
end

local function build_target_options(players)
	local options = {}
	for _, player in ipairs(players or {}) do
		options[#options + 1] = player.username
	end
	if #options == 0 then
		options = { "No Players" }
	end
	return options
end

local function get_target_jokers_label(target)
	if MP.UI.get_target_jokers_label then
		return MP.UI.get_target_jokers_label(target)
	end
	return localize("k_enemy_jokers")
end

function view_model.prepare_screen_state()
	local end_game_view = get_end_game_view_runtime()
	if not end_game_view then
		return {
			runtime = nil,
			players = {},
			target = nil,
			target_index = 1,
			target_options = { "No Players" },
		}
	end

	if end_game_view.jokers_area then
		end_game_view.jokers_area:remove()
		end_game_view.jokers_area = nil
	end

	end_game_view.jokers_area = CardArea(
		0,
		0,
		5 * G.CARD_W,
		G.CARD_H,
		{ card_limit = BALATRO.get_starting_joker_slots and BALATRO.get_starting_joker_slots() or 5, type = "joker", highlight_limit = 1 }
	)

	if end_game_view.players == nil and MP.UI.capture_end_game_view_players then
		MP.UI.capture_end_game_view_players()
	end
	if MP.UI.prefetch_end_game_view_players then
		MP.UI.prefetch_end_game_view_players()
	end

	local players, target, target_index = MP.UI.get_view_target_state()

	end_game_view.showing_own_jokers = false
	end_game_view.jokers_text = get_target_jokers_label(target)

	if MP.UI.request_end_game_view_target then
		MP.UI.request_end_game_view_target(target)
	end

	return {
		runtime = end_game_view,
		players = players or {},
		target = target,
		target_index = target_index or 1,
		target_options = build_target_options(players),
	}
end

function view_model.change_view_target(index)
	local players = MP.UI.get_viewable_players()
	local target = players[index]
	if not target then
		return false
	end

	local end_game_view = get_end_game_view_runtime()
	if not end_game_view then
		return false
	end

	end_game_view.target_index = index
	MP.UI.request_end_game_view_target(target)
	return true
end

function view_model.toggle_players_jokers()
	local end_game_view = get_end_game_view_runtime()
	if not (end_game_view and G.jokers and end_game_view.jokers_area) then
		return false
	end

	if end_game_view.jokers_area.cards then
		for _, card in pairs(end_game_view.jokers_area.cards) do
			card.added_to_deck = false
		end
	end

	if not end_game_view.showing_own_jokers then
		local your_jokers_save = copy_table(G.jokers:save())
		end_game_view.jokers_area:load(your_jokers_save)
		end_game_view.showing_own_jokers = true
		end_game_view.jokers_text = localize("k_your_jokers")
		return true
	end

	if end_game_view.jokers_received then
		G.FUNCS.load_end_game_jokers()
	else
		if end_game_view.jokers_area.cards then
			remove_all(end_game_view.jokers_area.cards)
		end
		end_game_view.jokers_area.cards = {}
		if end_game_view.end_game_jokers_error_message then
			end_game_view.showing_own_jokers = false
			end_game_view.jokers_text = get_target_jokers_label() .. " (Unavailable)"
			MP.UI.UTILS.overlay_message(end_game_view.end_game_jokers_error_message)
			return false
		end
	end

	end_game_view.showing_own_jokers = false
	end_game_view.jokers_text = get_target_jokers_label()
	return true
end

function view_model.open_nemesis_deck_overlay()
	if BALATRO.set_paused then
		BALATRO.set_paused(true)
	end

	local end_game_view = get_end_game_view_runtime()
	if not end_game_view then
		return false
	end

	if end_game_view.nemesis_deck_error_message and not end_game_view.nemesis_deck_received then
		MP.UI.UTILS.overlay_message(end_game_view.nemesis_deck_error_message)
		return false
	end

	if G.deck_preview then
		G.deck_preview:remove()
		G.deck_preview = nil
	end

	G.FUNCS.overlay_menu({
		definition = G.UIDEF.create_UIBox_view_nemesis_deck(),
	})
	if G.OVERLAY_MENU then
		G.OVERLAY_MENU.is_mp_end_game_deck_view = true
	end

	return true
end

function view_model.get_nemesis_deck_card_descriptors()
	local end_game_view = get_end_game_view_runtime()
	if
		not end_game_view
		or not end_game_view.nemesis_deck_string
		or end_game_view.nemesis_deck_string == ""
		or not (MP.LOBBY and MP.LOBBY.code)
	then
		return {}
	end

	local descriptors = {}
	for source_index, card_str in ipairs(MP.UTILS.string_split(end_game_view.nemesis_deck_string, ";")) do
		if card_str ~= "" then
			local card_params = MP.UTILS.string_split(card_str, "-")
			local suit = card_params[1]
			local rank = card_params[2]
			local enhancement = card_params[3]
			local edition = card_params[4]
			local seal = card_params[5]
			local front_key = tostring(suit) .. "_" .. tostring(rank)
			local front = BALATRO.get_card_front and BALATRO.get_card_front(front_key) or nil

			if front then
				if not enhancement or (enhancement ~= "none" and not (BALATRO.get_center and BALATRO.get_center(enhancement))) then
					enhancement = "none"
				end
				if not edition or (edition ~= "none" and not (BALATRO.get_center and BALATRO.get_center("e_" .. edition))) then
					edition = "none"
				end
				if not seal or (seal ~= "none" and not (BALATRO.get_seal and BALATRO.get_seal(seal))) then
					seal = "none"
				end

				descriptors[#descriptors + 1] = {
					front = front,
					center = enhancement ~= "none" and BALATRO.get_center(enhancement) or BALATRO.get_center("c_base"),
					edition = edition,
					seal = seal,
					suit_name = SUIT_NAME_BY_CODE[tostring(suit)] or front.suit,
					rank_order = RANK_ORDER_BY_VALUE[front.value] or tonumber(front.value) or 0,
					source_index = source_index,
				}
			end
		end
	end

	return descriptors
end
