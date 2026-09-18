-- ============================================================================
-- multiplayer/ui/end_game_overlay.lua
-- Consolidated End Game UI: View, View-Model, Deck Inspector, Handlers & Hooks
-- ============================================================================

MP.UI = MP.UI or {}
MP.UI.END_GAME_VIEW_MODEL = MP.UI.END_GAME_VIEW_MODEL or {}

local ui_api = MP.UI
local view_model = MP.UI.END_GAME_VIEW_MODEL
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local load_required_service = MP.UTILS and MP.UTILS.load_required_service

-- ----------------------------------------------------------------------------
-- SECTION 1: End Game View API Service Delegation
-- ----------------------------------------------------------------------------
local END_GAME_VIEW_METHODS = {
	"get_end_game_view_runtime",
	"reset_end_game_view_runtime",
	"get_viewable_players",
	"get_end_game_self_player",
	"get_end_game_standings_participants",
	"capture_end_game_view_players",
	"get_view_target_state",
	"get_target_jokers_label",
	"get_target_deck_label",
	"apply_end_game_summary",
	"get_end_game_view_cache",
	"load_end_game_view_cache",
	"clear_end_game_view_request_error",
	"fail_end_game_view_request",
	"resolve_end_game_view_response_target",
	"apply_end_game_view_response",
	"clear_end_game_target_preview",
	"prefetch_end_game_view_players",
	"request_end_game_view_target",
	"refresh_end_game_view_target_summary",
}

local end_game_view_runtime = (MP.END_GAME_VIEW and MP.END_GAME_VIEW.get_end_game_view_runtime and MP.END_GAME_VIEW)
	or load_required_service(
		"multiplayer/runtime/end_game_runtime.lua",
		END_GAME_VIEW_METHODS,
		"Multiplayer end-game view runtime service is missing.",
		function()
			return MP.END_GAME_VIEW
		end
	)
if not end_game_view_runtime then
	return nil
end

for _, method_name in ipairs(END_GAME_VIEW_METHODS) do
	local name = method_name
	ui_api[name] = function(...)
		return end_game_view_runtime[name](...)
	end
end


-- ----------------------------------------------------------------------------
-- SECTION 2: End Game View Model & Data Preparation
-- ----------------------------------------------------------------------------
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

local function with_phantom_sync_suppressed(callback)
	local content_runtime = MP.CONTENT and MP.CONTENT.RUNTIME or nil
	if content_runtime and content_runtime.with_phantom_sync_suppressed then
		return content_runtime.with_phantom_sync_suppressed(callback)
	end
	return callback()
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

local function get_self_view_player()
	local self_player = MP.UI.get_end_game_self_player and MP.UI.get_end_game_self_player() or nil
	if self_player then return self_player end
	self_player = MP.get_self_lobby_player and MP.get_self_lobby_player() or nil
	if self_player then return self_player end

	local player_id = (G and G.MP_ID or nil)
	if not player_id then return nil end
	return {
		id = player_id,
		username = "You",
	}
end

function view_model.prepare_screen_state()
	local end_game_view = get_end_game_view_runtime()
	if not end_game_view then
		return {
			runtime = nil,
			players = {},
			self_player = nil,
			target = nil,
			target_index = 1,
			target_options = { "No Players" },
		}
	end

	if end_game_view.jokers_area then
		with_phantom_sync_suppressed(function()
			end_game_view.jokers_area:remove()
		end)
		end_game_view.jokers_area = nil
	end
	end_game_view.loaded_target_id = nil

	end_game_view.jokers_area = CardArea(
		0,
		0,
		5 * G.CARD_W,
		G.CARD_H,
		{ card_limit = (G and G.GAME and G.GAME.starting_params and G.GAME.starting_params.joker_slots or nil) or 5, type = "joker", highlight_limit = 1 }
	)
	end_game_view.jokers_area.mp_end_game_preview = true

	if end_game_view.players == nil and MP.UI.capture_end_game_view_players then
		MP.UI.capture_end_game_view_players()
	end
	if MP.UI.prefetch_end_game_view_players then
		MP.UI.prefetch_end_game_view_players()
	end

	local players, target, target_index = MP.UI.get_view_target_state()
	local self_player = get_self_view_player()

	end_game_view.showing_own_jokers = false
	end_game_view.jokers_text = get_target_jokers_label(target)

	if MP.UI.request_end_game_view_target then
		MP.UI.request_end_game_view_target(target)
	end

	return {
		runtime = end_game_view,
		players = players or {},
		self_player = self_player,
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

function view_model.view_self_profile()
	local self_player = get_self_view_player()
	if not self_player then
		return false
	end

	MP.UI.request_end_game_view_target(self_player)
	return true
end

function view_model.return_to_compare_target()
	local players = MP.UI.get_viewable_players()
	if #players == 0 then
		return false
	end

	local end_game_view = get_end_game_view_runtime()
	local index = end_game_view and end_game_view.target_index or 1
	index = math.min(math.max(tonumber(index) or 1, 1), #players)
	return view_model.change_view_target(index)
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
			local front = (G and G.P_CARDS and G.P_CARDS[front_key]) or nil

			if front then
				if not enhancement or (enhancement ~= "none" and not ((G and G.P_CENTERS and G.P_CENTERS[enhancement]))) then
					enhancement = "none"
				end
				if not edition or (edition ~= "none" and not ((G and G.P_CENTERS and G.P_CENTERS["e_" .. edition]))) then
					edition = "none"
				end
				if not seal or (seal ~= "none" and not ((G and G.P_SEALS and G.P_SEALS[seal] or nil))) then
					seal = "none"
				end

				descriptors[#descriptors + 1] = {
					front = front,
					center = enhancement ~= "none" and (G and G.P_CENTERS and G.P_CENTERS[enhancement] or nil) or (G and G.P_CENTERS and G.P_CENTERS["c_base"] or nil),
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


-- ----------------------------------------------------------------------------
-- SECTION 3: End Game Deck Inspector Overlay
-- ----------------------------------------------------------------------------
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
	local ruleset = MP.current_ruleset and MP.current_ruleset() or MP.Rulesets[MP.LOBBY.config.ruleset]
	return G.UIDEF.challenge_description(
		get_challenge_int_from_id(ruleset.challenge_deck),
		nil,
		false
	)
end


-- ----------------------------------------------------------------------------
-- SECTION 4: End Game Overlay View & UIBox Node Tree
-- ----------------------------------------------------------------------------
local ACTION_BUTTON_WIDTH = 2.15
local ACTION_BUTTON_HEIGHT = 0.7
local ACTION_TEXT_SCALE = 0.42
local TARGET_CYCLE_NAME_WIDTH = 2.4
local TARGET_CYCLE_ARROW_WIDTH = 0.6
local TARGET_CYCLE_GAP = 0.08
local TARGET_CYCLE_TEXT_SCALE = 0.42
local VOUCHER_POPUP_CARD_SCALE = 0.48
local VOUCHER_POPUP_OVERLAP = 0.82
local VOUCHER_POPUP_MAX_PER_ROW = 8
local VOUCHER_POPUP_ROW_GAP = 0.08

local function create_end_game_action_spacer(has_won)
	local width = has_won and 0.4 or 0.5
	return {
		n = G.UIT.C,
		config = {
			maxw = width,
			minw = width,
			minh = 0.7,
			colour = G.C.CLEAR,
			no_fill = false,
		},
	}
end

local function create_end_game_action_text_button(button, text, id, focus_args)
	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.02, colour = G.C.CLEAR },
		nodes = {
			{
				n = G.UIT.R,
				config = {
					id = id,
					button = button,
					align = "cm",
					padding = 0.05,
					colour = G.C.BLUE,
					emboss = 0.1,
					minw = ACTION_BUTTON_WIDTH,
					maxw = ACTION_BUTTON_WIDTH,
					minh = ACTION_BUTTON_HEIGHT,
					maxh = ACTION_BUTTON_HEIGHT,
					r = 0.1,
					shadow = true,
					hover = true,
					can_collide = true,
					focus_args = focus_args,
				},
				nodes = {
					{
						n = G.UIT.O,
						config = {
							object = DynaText({
								string = { text },
								colours = { G.C.UI.TEXT_LIGHT },
								pop_in = 0,
								pop_in_rate = 8,
								reset_pop_in = true,
								shadow = true,
								float = true,
								silent = true,
								bump = true,
								scale = ACTION_TEXT_SCALE,
								maxw = ACTION_BUTTON_WIDTH - 0.1,
								non_recalc = true,
							}),
						},
					},
				},
			},
		},
	}
end

local function create_end_game_action_button(button, label_key, id, focus_args)
	return create_end_game_action_text_button(button, localize(label_key), id, focus_args)
end

local function create_end_game_named_action_button(button, label, id, focus_args)
	local text = tostring(label or "")
	if text == "" then text = "You" end

	return create_end_game_action_text_button(button, text, id, focus_args)
end

local function create_end_game_cycle_gap()
	return {
		n = G.UIT.C,
		config = {
			align = "cm",
			minw = TARGET_CYCLE_GAP,
			maxw = TARGET_CYCLE_GAP,
			colour = G.C.CLEAR,
		},
	}
end

local function create_end_game_target_cycle(screen_state, view_target_index, viewable_players)
	local has_compare_target = #viewable_players > 0
	local cycle_config = {
		options = screen_state.target_options,
		current_option = view_target_index or 1,
		opt_callback = has_compare_target and "change_end_game_view_target" or nil,
	}
	cycle_config.current_option_val = cycle_config.options[cycle_config.current_option]
	local arrows_disabled = #cycle_config.options < 2

	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.02, colour = G.C.CLEAR },
		nodes = {
			{
				n = G.UIT.R,
				config = { id = "end_game_view_target_cycle", align = "cm", colour = G.C.CLEAR, padding = 0 },
				nodes = {
					{
						n = G.UIT.C,
						config = {
							align = "cm",
							r = 0.1,
							minw = TARGET_CYCLE_ARROW_WIDTH,
							maxw = TARGET_CYCLE_ARROW_WIDTH,
							minh = ACTION_BUTTON_HEIGHT,
							maxh = ACTION_BUTTON_HEIGHT,
							hover = not arrows_disabled,
							colour = not arrows_disabled and G.C.BLUE or G.C.BLACK,
							shadow = not arrows_disabled,
							button = not arrows_disabled and "option_cycle" or nil,
							ref_table = cycle_config,
							ref_value = "l",
							focus_args = { type = "none" },
						},
						nodes = {
							{
								n = G.UIT.T,
								config = {
									text = "<",
									scale = TARGET_CYCLE_TEXT_SCALE,
									colour = not arrows_disabled and G.C.UI.TEXT_LIGHT or G.C.UI.TEXT_INACTIVE,
								},
							},
						},
					},
					create_end_game_cycle_gap(),
					{
						n = G.UIT.C,
						config = {
							id = "cycle_main",
							align = "cm",
							minw = TARGET_CYCLE_NAME_WIDTH,
							maxw = TARGET_CYCLE_NAME_WIDTH,
							minh = ACTION_BUTTON_HEIGHT,
							maxh = ACTION_BUTTON_HEIGHT,
							r = 0.1,
							padding = 0.05,
							colour = has_compare_target and G.C.BLUE or G.C.BLACK,
							emboss = 0.1,
							hover = has_compare_target,
							shadow = has_compare_target,
							can_collide = has_compare_target,
							button = has_compare_target and "return_to_end_game_compare_target" or nil,
						},
						nodes = {
							{
								n = G.UIT.O,
								config = {
									object = DynaText({
										string = { { ref_table = cycle_config, ref_value = "current_option_val" } },
										colours = { G.C.UI.TEXT_LIGHT },
										pop_in = 0,
										pop_in_rate = 8,
										reset_pop_in = true,
										shadow = true,
										float = true,
										silent = true,
										bump = true,
										scale = TARGET_CYCLE_TEXT_SCALE,
										maxw = TARGET_CYCLE_NAME_WIDTH - 0.1,
										non_recalc = true,
									}),
								},
							},
						},
					},
					create_end_game_cycle_gap(),
					{
						n = G.UIT.C,
						config = {
							align = "cm",
							r = 0.1,
							minw = TARGET_CYCLE_ARROW_WIDTH,
							maxw = TARGET_CYCLE_ARROW_WIDTH,
							minh = ACTION_BUTTON_HEIGHT,
							maxh = ACTION_BUTTON_HEIGHT,
							hover = not arrows_disabled,
							colour = not arrows_disabled and G.C.BLUE or G.C.BLACK,
							shadow = not arrows_disabled,
							button = not arrows_disabled and "option_cycle" or nil,
							ref_table = cycle_config,
							ref_value = "r",
							focus_args = { type = "none" },
						},
						nodes = {
							{
								n = G.UIT.T,
								config = {
									text = ">",
									scale = TARGET_CYCLE_TEXT_SCALE,
									colour = not arrows_disabled and G.C.UI.TEXT_LIGHT or G.C.UI.TEXT_INACTIVE,
								},
							},
						},
					},
				},
			},
		},
	}
end

local function create_end_game_stat_gap(row)
	return {
		n = row and G.UIT.R or G.UIT.C,
		config = row
			and { align = "cm", minh = 0.08, maxh = 0.08, colour = G.C.CLEAR }
			or { align = "cm", minw = 0.08, maxw = 0.08, colour = G.C.CLEAR },
		nodes = {},
	}
end

local function resolve_voucher_center_key(value)
	local raw_key = tostring(value or "")
	if raw_key == "" then return nil end

	if G.P_CENTERS and G.P_CENTERS[raw_key] then
		return raw_key
	end

	local prefixed_key = raw_key:sub(1, 2) == "v_" and raw_key or "v_" .. raw_key
	if G.P_CENTERS and G.P_CENTERS[prefixed_key] then
		return prefixed_key
	end

	local lower_key = raw_key:lower()
	for center_key, center in pairs(G.P_CENTERS or {}) do
		if center and center.set == "Voucher" then
			local center_name = tostring(center.name or "")
			local center_label = tostring(center.label or "")
			if center_name == raw_key or center_label == raw_key then
				return center_key
			end
			if center_name:lower() == lower_key or center_label:lower() == lower_key then
				return center_key
			end
		end
	end

	return nil
end

local function get_valid_voucher_keys(vouchers)
	local keys = {}
	for _, key in ipairs(vouchers or {}) do
		local resolved_key = resolve_voucher_center_key(key)
		if resolved_key then keys[#keys + 1] = resolved_key end
	end
	return keys
end

local function get_voucher_card_dimensions()
	local card_w = G.CARD_W * VOUCHER_POPUP_CARD_SCALE
	local card_h = G.CARD_H * VOUCHER_POPUP_CARD_SCALE
	return card_w, card_h
end

local function get_voucher_row_width(voucher_count)
	local card_w = G.CARD_W * VOUCHER_POPUP_CARD_SCALE
	return card_w + math.max(voucher_count - 1, 0) * card_w * VOUCHER_POPUP_OVERLAP
end

local function get_voucher_popup_dimensions(voucher_count)
	local _, card_h = get_voucher_card_dimensions()
	local row_count = math.max(math.ceil(math.max(voucher_count, 1) / VOUCHER_POPUP_MAX_PER_ROW), 1)
	local widest_row_count = math.min(math.max(voucher_count, 1), VOUCHER_POPUP_MAX_PER_ROW)
	local width = get_voucher_row_width(widest_row_count)
	local height = row_count * card_h + math.max(row_count - 1, 0) * VOUCHER_POPUP_ROW_GAP
	return width, height
end

local function get_voucher_popup_rows(vouchers)
	local valid_vouchers = get_valid_voucher_keys(vouchers)
	local rows = {}

	for index, key in ipairs(valid_vouchers) do
		local row_index = math.floor((index - 1) / VOUCHER_POPUP_MAX_PER_ROW) + 1
		rows[row_index] = rows[row_index] or {}
		rows[row_index][#rows[row_index] + 1] = key
	end

	return rows, valid_vouchers
end

local function create_end_game_mp_stat_row(id, label_key, value, text_colour, args)
	args = args or {}
	local value_text = tostring(value or "")
	local ref_table = args.ref_table
	local ref_value = args.ref_value
	local value_scale = args.value_scale or math.max(0.32, math.min(0.5, 0.62 - 0.018 * #value_text))
	local label_width = args.label_width or 2.9
	local value_width = args.value_width or 1
	local value_maxw = args.value_maxw or math.max(value_width - 0.05, 0.95)
	local value_nodes = {}
	for _, node in ipairs(args.value_prefix_nodes or {}) do
		value_nodes[#value_nodes + 1] = node
	end
	value_nodes[#value_nodes + 1] = {
		n = G.UIT.O,
		config = {
			object = DynaText({
				string = { ref_table and ref_value and { ref_table = ref_table, ref_value = ref_value } or value_text },
				colours = { text_colour or G.C.FILTER },
				shadow = true,
				float = true,
				scale = value_scale,
				maxw = value_maxw,
			}),
		},
	}
	local row_config = {
		align = "cm",
		padding = 0.05,
		r = 0.1,
		colour = darken(G.C.JOKER_GREY, 0.1),
		emboss = 0.05,
		id = id,
	}

	return {
		n = G.UIT.R,
		config = row_config,
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm", padding = 0.02, minw = label_width, maxw = label_width },
				nodes = {
					{
						n = G.UIT.T,
						config = {
							text = localize(label_key),
							scale = 0.4,
							maxw = math.max(label_width - 0.1, 0.9),
							colour = G.C.UI.TEXT_LIGHT,
							shadow = true,
						},
					},
				},
			},
			{
				n = G.UIT.C,
				config = { align = "cr" },
				nodes = {
					{
						n = G.UIT.C,
						config = {
							align = "cm",
							minh = 0.5,
							r = 0.1,
							minw = value_width,
							maxw = value_width,
							colour = G.C.BLACK,
							emboss = 0.05,
						},
						nodes = {
							{
								n = G.UIT.C,
								config = { align = "cm", padding = 0.05, r = 0.1, minw = value_width, maxw = value_width },
								nodes = value_nodes,
							},
						},
					},
				},
			},
		},
	}
end

local function create_end_game_summary_stat_row(score, display, text_colour, args)
	args = args or {}
	local label_key = args.label_key or "ph_score_" .. score
	return create_end_game_mp_stat_row(score, label_key, display and display[score] or "", text_colour, {
		ref_table = display,
		ref_value = score,
		label_width = args.label_width,
		value_width = args.value_width,
		value_scale = args.value_scale,
		value_maxw = args.value_maxw,
		value_prefix_nodes = args.value_prefix_nodes,
	})
end

local function create_end_game_chip_prefix_node()
	local chip_sprite = Sprite(0, 0, 0.3, 0.3, G.ASSET_ATLAS["ui_" .. (G.SETTINGS.colourblind_option and 2 or 1)], { x = 0, y = 0 })
	chip_sprite.states.drag.can = false
	return {
		n = G.UIT.C,
		config = { align = "cm", padding = 0.02 },
		nodes = {
			{ n = G.UIT.O, config = { w = 0.3, h = 0.3, object = chip_sprite } },
		},
	}
end

local function create_end_game_voucher_card_area(vouchers)
	local valid_vouchers = get_valid_voucher_keys(vouchers)
	local card_w, card_h = get_voucher_card_dimensions()
	local width = get_voucher_row_width(#valid_vouchers)
	local card_area = CardArea(
		0,
		0,
		width,
		card_h,
		{
			card_limit = math.max(#valid_vouchers, 1),
			type = "title",
			highlight_limit = 0,
			card_w = card_w,
		}
	)

	for _, key in ipairs(valid_vouchers) do
		local center = G.P_CENTERS[key]
		local card = Card(
			card_area.T.x + card_area.T.w / 2,
			card_area.T.y,
			card_w,
			card_h,
			G.P_CARDS.empty,
			center,
			{ bypass_discovery_center = true, bypass_discovery_ui = true }
		)
		card.states.drag.can = false
		card.states.click.can = false
		card.states.hover.can = false
		card.states.collide.can = false
		card:hard_set_T()
		card_area:emplace(card)
	end

	return card_area
end

local function create_end_game_voucher_popup_definition(vouchers)
	local voucher_rows, valid_vouchers = get_voucher_popup_rows(vouchers)
	local width, height = get_voucher_popup_dimensions(#valid_vouchers)
	local _, card_h = get_voucher_card_dimensions()
	local row_nodes = {}

	if #voucher_rows == 0 then voucher_rows[1] = {} end

	for row_index, row_vouchers in ipairs(voucher_rows) do
		row_nodes[#row_nodes + 1] = {
			n = G.UIT.R,
			config = { align = "cm", padding = 0.01, colour = G.C.CLEAR, minw = width, minh = card_h },
			nodes = {
				{ n = G.UIT.O, config = { object = create_end_game_voucher_card_area(row_vouchers) } },
			},
		}

		if row_index < #voucher_rows then
			row_nodes[#row_nodes + 1] = {
				n = G.UIT.R,
				config = { align = "cm", colour = G.C.CLEAR, minw = width, minh = VOUCHER_POPUP_ROW_GAP, maxh = VOUCHER_POPUP_ROW_GAP },
				nodes = {},
			}
		end
	end

	return {
		n = G.UIT.ROOT,
		config = {
			align = "cm",
			padding = 0.08,
			r = 0.12,
			minw = width + 0.16,
			minh = height + 0.16,
			colour = darken(G.C.JOKER_GREY, 0.1),
			outline = 1.5,
			outline_colour = G.C.WHITE,
			line_emboss = 0.5,
			emboss = 0.05,
		},
		nodes = row_nodes,
	}
end

local function close_end_game_voucher_popup(anchor)
	local closed = false
	if anchor and anchor.children and anchor.children.h_popup then
		anchor.children.h_popup:remove()
		anchor.children.h_popup = nil
		closed = true
	end

	if anchor and anchor.config then
		anchor.config.h_popup = nil
		anchor.config.h_popup_config = nil
	end

	if G and G.mp_end_game_voucher_ui then
		if G.mp_end_game_voucher_ui.remove then G.mp_end_game_voucher_ui:remove() end
		G.mp_end_game_voucher_ui = nil
		G.mp_end_game_voucher_ui_anchor = nil
		closed = true
	end

	return closed
end

local function open_end_game_voucher_popup(anchor)
	local vouchers = anchor and anchor.config and anchor.config.mp_vouchers_bought or {}
	if not (anchor and UIBox and #get_valid_voucher_keys(vouchers) > 0) then
		close_end_game_voucher_popup(anchor)
		return false
	end

	if anchor.children and anchor.children.h_popup then return true end

	anchor.config.h_popup = create_end_game_voucher_popup_definition(vouchers)
	anchor.config.h_popup_config = {
		align = anchor.T.y > G.ROOM.T.h / 2 and "tm" or "bm",
		offset = { x = 0, y = anchor.T.y > G.ROOM.T.h / 2 and -0.12 or 0.12 },
		parent = anchor,
	}
	if Node and Node.hover then
		Node.hover(anchor)
	end
	return true
end

BALATRO.set_ui_function("mp_setup_end_game_voucher_popup", function(e)
	if not (e and e.config) then return end
	e.config.func = nil
	if e.config.mp_voucher_popup_installed then return end
	e.config.mp_voucher_popup_installed = true
	e.config.hover = true
	e.config.force_focus = true

	if e.states then
		if e.states.collide then e.states.collide.can = true end
		if e.states.hover then e.states.hover.can = true end
	end

	local old_hover = e.hover
	function e:hover(...)
		if old_hover then old_hover(self, ...) end
		open_end_game_voucher_popup(self)
	end

	local old_stop_hover = e.stop_hover
	function e:stop_hover(...)
		if old_stop_hover then old_stop_hover(self, ...) end
		close_end_game_voucher_popup(self)
	end

	local old_remove = e.remove
	function e:remove(...)
		close_end_game_voucher_popup(self)
		if old_remove then old_remove(self, ...) end
	end
end)

BALATRO.set_ui_function("mp_copy_end_game_seed", function()
	local end_game_view = MP.UI and MP.UI.get_end_game_view_runtime and MP.UI.get_end_game_view_runtime() or nil
	local seed = end_game_view
		and end_game_view.summary_display
		and end_game_view.summary_display.seed
		or G.GAME and G.GAME.pseudorandom and G.GAME.pseudorandom.seed
		or ""
	if G.F_LOCAL_CLIPBOARD then
		G.CLIPBOARD = seed
	else
		love.system.setClipboardText(seed)
	end
end)

local function create_end_game_vouchers_stat_row(display)
	local vouchers = display and display.vouchers_bought or {}
	local row = create_end_game_mp_stat_row(
		"mp_vouchers_bought",
		"k_mp_end_vouchers_bought",
		display and display.vouchers_bought_count or number_format(#get_valid_voucher_keys(vouchers)),
		G.C.SECONDARY_SET and G.C.SECONDARY_SET.Voucher or G.C.PURPLE,
		{
			ref_table = display,
			ref_value = "vouchers_bought_count",
		}
	)
	row.config.func = "mp_setup_end_game_voucher_popup"
	row.config.insta_func = true
	row.config.hover = true
	row.config.can_collide = true
	row.config.force_focus = true
	row.config.mp_vouchers_bought = vouchers
	return row
end

local function create_end_game_secondary_stats(display)
	return {
		n = G.UIT.R,
		config = { align = "cm" },
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm" },
				nodes = {
					create_end_game_summary_stat_row("cards_purchased", display, G.C.MONEY),
					create_end_game_stat_gap(true),
					create_end_game_vouchers_stat_row(display),
					create_end_game_stat_gap(true),
					create_end_game_summary_stat_row("times_rerolled", display, G.C.GREEN),
					create_end_game_stat_gap(true),
					create_end_game_mp_stat_row(
						"mp_total_money_spent",
						"k_mp_end_total_spend",
						display and display.total_money_spent or localize("$") .. "0",
						G.C.MONEY,
						{
							ref_table = display,
							ref_value = "total_money_spent",
						}
					),
				},
			},
			create_end_game_stat_gap(false),
			{
				n = G.UIT.C,
				config = { align = "cm" },
				nodes = {
					create_end_game_summary_stat_row("furthest_ante", display, G.C.FILTER, { label_key = "k_ante", label_width = 1.9 }),
					create_end_game_stat_gap(true),
					create_end_game_summary_stat_row("furthest_round", display, G.C.FILTER, { label_key = "k_round", label_width = 1.9 }),
					create_end_game_stat_gap(true),
					create_end_game_mp_stat_row(
						"mp_reroll_money_spent",
						"k_mp_end_reroll_spend",
						display and display.reroll_money_spent or localize("$") .. "0",
						G.C.GREEN,
						{
							ref_table = display,
							ref_value = "reroll_money_spent",
						}
					),
				},
			},
		},
	}
end

local function create_end_game_kofi_button()
	return {
		n = G.UIT.R,
		config = {
			id = "ko-fi_button",
			align = "cm",
			padding = 0.1,
			r = 0.1,
			hover = true,
			colour = HEX("72A5F2"),
			button = "open_kofi",
			shadow = true,
			minw = 4.8,
			maxw = 4.8,
		},
		nodes = {
			{
				n = G.UIT.R,
				config = {
					align = "cm",
					padding = 0,
					no_fill = true,
					maxw = 4.7,
				},
				nodes = {
					{
						n = G.UIT.O,
						config = {
							object = DynaText({
								string = { localize("b_mp_kofi_button") },
								colours = { G.C.UI.TEXT_LIGHT },
								shadow = true,
								float = true,
								silent = true,
								scale = 0.32,
								maxw = 4.6,
								non_recalc = true,
							}),
						},
					},
				},
			},
		},
	}
end

local function get_end_game_screen_style(has_won)
	local result = MP.GAME and MP.GAME.end_game_result
	local is_abandoned = result == "abandoned" or result == "alone"
	if is_abandoned or result == "ended" then
		return {
			win_like = false,
			title = result == "ended" and "MATCH ENDED" or "MATCH ABANDONED",
			title_colour = G.C.BLUE,
			background_colour = G.C.BLUE,
			background_alpha = 0.55,
			panel_colour = nil,
			outline_colour = nil,
			spacing = 2,
			rotate = false,
		}
	end

	if has_won then
		return {
			win_like = true,
			title = localize("ph_you_win"),
			title_colour = G.C.EDITION,
			background_colour = G.C.GREEN,
			background_alpha = 0.5,
			panel_colour = G.C.BLACK,
			outline_colour = G.C.EDITION,
			spacing = 10,
			rotate = true,
		}
	end

	return {
		win_like = false,
		title = localize("ph_game_over"),
		title_colour = G.C.RED,
		background_colour = G.C.RED,
		background_alpha = 0.8,
		panel_colour = nil,
		outline_colour = nil,
		spacing = nil,
		rotate = nil,
	}
end

function MP.UI.create_UIBox_mp_game_end(has_won)
	local screen_state = MP.UI.END_GAME_VIEW_MODEL.prepare_screen_state()
	local end_game_view = screen_state.runtime
	local viewable_players = screen_state.players
	local view_target_index = screen_state.target_index
	local summary_display = end_game_view and end_game_view.summary_display or {}
	local screen_style = get_end_game_screen_style(has_won)
	local is_coop_win = not not (screen_style.win_like and MP.is_coop_run and MP.is_coop_run())

	if is_coop_win and MP.GAME then
		MP.GAME.is_coop_ante8_win = true
	end

	if BALATRO.set_paused and not is_coop_win then
		BALATRO.set_paused(false)
	end

	local eased_bg_colour = copy_table(screen_style.background_colour)
	eased_bg_colour[4] = 0
	ease_value(eased_bg_colour, 4, screen_style.background_alpha, nil, nil, true)

	local t = create_UIBox_generic_options({
		padding = 0,
		bg_colour = eased_bg_colour,
		colour = screen_style.panel_colour,
		outline_colour = screen_style.outline_colour,
		no_back = true,
		no_esc = screen_style.win_like,
		contents = {
			{
				n = G.UIT.R,
				config = { align = "cm" },
				nodes = {
					{
						n = G.UIT.O,
						config = {
							object = DynaText({
								string = { screen_style.title },
								colours = { screen_style.title_colour },
								shadow = true,
								float = true,
								spacing = screen_style.spacing,
								rotate = screen_style.rotate,
								scale = 1.5,
								pop_in = 0.4,
								maxw = 6.5,
							}),
						},
					},
				},
			},
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.15 },
				nodes = {
					{
						n = G.UIT.C,
						config = { align = "cm" },
						nodes = {
							{
								n = G.UIT.R,
								config = { align = "cm", padding = 0.08 },
								nodes = {
									{
										n = G.UIT.T,
										config = {
											ref_table = end_game_view,
											ref_value = "jokers_text",
											scale = 0.8,
											maxw = 5,
											shadow = true,
										},
									},
								},
							},
							{
								n = G.UIT.R,
								config = { align = "cm", padding = 0.08 },
								nodes = {
									{ n = G.UIT.O, config = { object = end_game_view.jokers_area } },
								},
							},
							{
								n = G.UIT.R,
								config = { align = "cm", padding = 0.08 },
								nodes = {
									create_end_game_action_spacer(screen_style.win_like),
									create_end_game_named_action_button(
										"view_self_end_game_profile",
										screen_state.self_player and screen_state.self_player.username or "You",
										"view_self_end_game_profile_button"
									),
									create_end_game_target_cycle(screen_state, view_target_index, viewable_players),
									create_end_game_action_button(
										"view_nemesis_deck",
										"b_view_nemesis_deck",
										"view_nemesis_deck_button",
										screen_style.win_like and { nav = "wide" } or nil
									),
									create_end_game_action_spacer(screen_style.win_like),
								},
							},
							{
								n = G.UIT.R,
								config = { align = "cm" },
								nodes = {
									{
										n = G.UIT.C,
										config = { align = "cm", padding = 0.08 },
										nodes = {
											create_end_game_summary_stat_row("hand", summary_display, G.C.RED, {
												label_width = 3.5,
												value_width = 3.5,
												value_scale = 0.52,
												value_maxw = 3.2,
												value_prefix_nodes = { create_end_game_chip_prefix_node() },
											}),
											create_end_game_summary_stat_row("poker_hand", summary_display, G.C.WHITE, {
												label_width = 3.5,
												value_width = 3.5,
												value_scale = 0.45,
												value_maxw = 3.2,
											}),
											create_end_game_secondary_stats(summary_display),
											create_end_game_stat_gap(true),
											create_end_game_kofi_button(),
										},
									},
									{
										n = G.UIT.C,
										config = { align = "tr", padding = 0.08 },
										nodes = {
											create_end_game_summary_stat_row("seed", summary_display, G.C.WHITE, {
												label_key = "k_seed",
												label_width = 1.9,
												value_width = 1.9,
												value_scale = 0.45,
												value_maxw = 1.8,
											}),
											UIBox_button({
												id = "copy_seed_button",
												button = "mp_copy_end_game_seed",
												label = { localize("b_copy") },
												colour = G.C.BLUE,
												scale = 0.3,
												minw = 2.3,
												minh = 0.4,
											}),
											{
												n = G.UIT.R,
												config = { align = "cm", minh = 0.4, minw = 0.1 },
												nodes = {},
											},
											(not screen_style.win_like and MP.is_mp_or_ghost and MP.is_mp_or_ghost()) and UIBox_button({
												id = "mp_spectate_match_button",
												button = "mp_spectate_match",
												label = { localize("b_spectate_match") },
												colour = G.C.BLUE,
												minw = 2.5,
												maxw = 2.5,
												minh = 0.8,
												focus_args = { nav = "wide" },
											}) or nil,
											is_coop_win and UIBox_button({
												id = "mp_endless_mode_button",
												button = "mp_end_game_endless_mode",
												label = { localize("b_endless") },
												colour = G.C.BLUE,
												minw = 2.5,
												maxw = 2.5,
												minh = 1,
												focus_args = { nav = "wide", snap_to = true },
											}) or nil,
											UIBox_button({
												id = "from_game_won",
												button = "mp_end_game_return_to_lobby",
												label = { localize("b_return_lobby") },
												minw = 2.5,
												maxw = 2.5,
												minh = 1,
												focus_args = { nav = "wide", snap_to = not is_coop_win },
											}),
											UIBox_button({
												button = "mp_end_game_leave_lobby",
												label = { localize("b_leave_lobby") },
												minw = 2.5,
												maxw = 2.5,
												minh = 1,
												focus_args = { nav = "wide" },
											}),
										},
									},
								},
							},
						},
					},
				},
			},
		},
	})

	t.nodes[1] = {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.1 },
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm", padding = 2 },
				nodes = {
					{
						n = G.UIT.O,
						config = {
							padding = 0,
							id = "jimbo_spot",
							object = Moveable(0, 0, G.CARD_W * 1.1, G.CARD_H * 1.1),
						},
					},
				},
			},
			{ n = G.UIT.C, config = { align = "cm", padding = 0.1 }, nodes = { t.nodes[1] } },
		},
	}

	if screen_style.win_like then t.config.id = "you_win_UI" end

	return t
end

local function handle_spectate_match(e)
	local spectatable = (MP.SPECTATOR and MP.SPECTATOR.get_spectatable_players)
		and MP.SPECTATOR.get_spectatable_players()
		or {}
	if #spectatable == 0 then
		return
	end

	local target = nil
	if MP.UI and MP.UI.get_view_target_state then
		local _, view_target = MP.UI.get_view_target_state()
		if view_target and view_target.id then
			for _, p in ipairs(spectatable) do
				if p.id == view_target.id then
					target = p
					break
				end
			end
		end
	end
	target = target or spectatable[1]
	if not target then
		return
	end

	if G.FUNCS and G.FUNCS.exit_overlay_menu then
		G.FUNCS.exit_overlay_menu()
	elseif G.OVERLAY_MENU then
		pcall(function()
			G.OVERLAY_MENU:remove()
		end)
		G.OVERLAY_MENU = nil
	end

	if G and G.SETTINGS then
		G.SETTINGS.paused = false
	end
	if BALATRO and BALATRO.set_paused then
		BALATRO.set_paused(false)
	end

	if MP.SPECTATOR and MP.SPECTATOR.set_lobby_role then
		MP.SPECTATOR.set_lobby_role("spectator")
	end
	if MP.ACTIONS and MP.ACTIONS.spectator_set_role then
		MP.ACTIONS.spectator_set_role("spectator")
	end

	if MP.GAME then
		MP.GAME.won = false
		MP.GAME.end_game_result = nil
		MP.GAME.round_failed = false
		MP.GAME.round_loss_processed = false
	end

	if MP.SPECTATOR and MP.SPECTATOR.start_spectating then
		MP.SPECTATOR.start_spectating(target.id, target.username)
		if MP.ACTIONS and MP.ACTIONS.spectator_request_snapshot then
			MP.ACTIONS.spectator_request_snapshot(target.id)
		end
	end
end

G.FUNCS = G.FUNCS or {}
G.FUNCS.mp_spectate_match = handle_spectate_match

if BALATRO.set_ui_function then
	BALATRO.set_ui_function("mp_spectate_match", handle_spectate_match)
end


-- ----------------------------------------------------------------------------
-- SECTION 5: End Game Button Controllers & Quips
-- ----------------------------------------------------------------------------
local ABANDONED_JIMBO_QUIP_KEY = "mp_abandoned_1"
local ABANDONED_JIMBO_FALLBACK_FONT = "6"

local function fallback_text_part(text)
	return {
		strings = { text },
		control = { f = ABANDONED_JIMBO_FALLBACK_FONT },
	}
end

local function text_part(text)
	return {
		strings = { text },
		control = {},
	}
end

local function create_abandoned_jimbo_parsed_line()
	-- The default Balatro English font does not include these Unicode punctuation glyphs.
	return {
		text_part("So"),
		fallback_text_part("…"),
		text_part(" it"),
		fallback_text_part("’"),
		text_part("s just you and me"),
	}
end

local function ensure_abandoned_jimbo_quip()
	if not (G and G.localization) then
		return ABANDONED_JIMBO_QUIP_KEY
	end

	G.localization.quips_parsed = G.localization.quips_parsed or {}
	G.localization.quips_parsed[ABANDONED_JIMBO_QUIP_KEY] = {
		multi_line = true,
		create_abandoned_jimbo_parsed_line(),
	}

	return ABANDONED_JIMBO_QUIP_KEY
end

BALATRO.set_ui_function("open_kofi", function()
	BALATRO.open_url("https://ko-fi.com/virtualized")
end)

BALATRO.set_ui_function("overlay_endgame_menu", function()
	local result = MP.GAME and MP.GAME.end_game_result
	local is_abandoned = result == "abandoned" or result == "alone"
	local is_win = MP.GAME and (MP.GAME.won or MP.GAME.is_coop_ante8_win)
	BALATRO.open_overlay_menu({
		definition = is_win and create_UIBox_win() or create_UIBox_game_over(),
		config = { no_esc = true },
	})
	if G and G.OVERLAY_MENU then
		G.OVERLAY_MENU.is_mp_end_game_overlay = true
		G.OVERLAY_MENU.mp_end_game_result = result
	end
	BALATRO.queue_event({
		trigger = "after",
		delay = 2.5,
		blocking = false,
		func = function()
			if BALATRO.get_overlay_element_by_id("jimbo_spot") then
				local Jimbo = Card_Character({ x = 0, y = 5 })
				local spot = BALATRO.get_overlay_element_by_id("jimbo_spot")
				MP.UI.UTILS.replace_config_object(spot, Jimbo, {
					recalculate_object = false,
					recalculate_ui_box = false,
				})
				Jimbo.ui_object_updated = true
				if is_abandoned then
					Jimbo:add_speech_bubble(ensure_abandoned_jimbo_quip(), nil, { quip = true })
				else
					local jimbo_words = is_win and "wq_" .. math.random(1, 7) or "lq_" .. math.random(1, 10)
					Jimbo:add_speech_bubble(jimbo_words, nil, { quip = true })
				end
				Jimbo:say_stuff(5)
			end
			return true
		end,
	})
end)

BALATRO.set_ui_function("change_end_game_view_target", function(args)
	MP.UI.END_GAME_VIEW_MODEL.change_view_target(args.to_key)
end)

BALATRO.set_ui_function("view_self_end_game_profile", function()
	MP.UI.END_GAME_VIEW_MODEL.view_self_profile()
end)

BALATRO.set_ui_function("return_to_end_game_compare_target", function()
	MP.UI.END_GAME_VIEW_MODEL.return_to_compare_target()
end)

BALATRO.set_ui_function("view_nemesis_deck", function()
	MP.UI.END_GAME_VIEW_MODEL.open_nemesis_deck_overlay()
end)


-- ----------------------------------------------------------------------------
-- SECTION 6: Game Over & Win Screen Hooks
-- ----------------------------------------------------------------------------
local create_UIBox_game_over_ref = create_UIBox_game_over
function create_UIBox_game_over()
	if not MP.LOBBY.code then return create_UIBox_game_over_ref() end
	return MP.UI.create_UIBox_mp_game_end(false)
end

local create_UIBox_win_ref = create_UIBox_win
function create_UIBox_win()
	if not MP.LOBBY.code then return create_UIBox_win_ref() end
	return MP.UI.create_UIBox_mp_game_end(true)
end

local exit_overlay_menu_ref = G.FUNCS.exit_overlay_menu
---@diagnostic disable-next-line: duplicate-set-field
function G.FUNCS:exit_overlay_menu()
	if G.OVERLAY_MENU and G.OVERLAY_MENU.is_mp_end_game_deck_view then
		exit_overlay_menu_ref(self)
		G.FUNCS.overlay_endgame_menu()
		return
	end

	if G.OVERLAY_MENU and G.OVERLAY_MENU:get_UIE_by_ID("username_input_box") ~= nil then
		MP.UTILS.save_username(MP.LOBBY.client.username)
	end

	exit_overlay_menu_ref(self)
end

local mods_button_ref = G.FUNCS.mods_button
function G.FUNCS.mods_button(arg_736_0)
	if G.OVERLAY_MENU and G.OVERLAY_MENU:get_UIE_by_ID("username_input_box") ~= nil then
		MP.UTILS.save_username(MP.LOBBY.client.username)
	end

	mods_button_ref(arg_736_0)
end

