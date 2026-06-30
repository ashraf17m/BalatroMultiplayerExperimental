local selector = {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local cocktail_selector_return_context = nil

local function is_cocktail_select(runtime, card)
	if Galdur then
		return Galdur.run_setup
			and card.area == Galdur.run_setup.selected_deck_area
			and card.config.center.key == "b_mp_cocktail"
	else
		return G.GAME.viewed_back
			and G.GAME.viewed_back.effect
			and G.GAME.viewed_back.effect.center.key == "b_mp_cocktail"
			and card.facing == "back"
	end
end

local function get_viewed_back_center()
	local viewed_back = G.GAME and G.GAME.viewed_back or nil
	if viewed_back and viewed_back.effect and viewed_back.effect.center then
		return viewed_back.effect.center
	end

	return viewed_back
end

local function get_center_key(center)
	if center and center.key then
		return center.key
	end
	if BALATRO.get_center_key then
		return BALATRO.get_center_key(center)
	end
	for key, candidate in pairs(G.P_CENTERS or {}) do
		if candidate == center then
			return key
		end
	end
	return nil
end

local function get_current_setup()
	if BALATRO.get_setting_value then
		return BALATRO.get_setting_value("current_setup", nil)
	end
	return G.SETTINGS and G.SETTINGS.current_setup or nil
end

local function set_current_setup(value)
	if value == nil then
		return
	end
	if BALATRO.set_current_setup then
		BALATRO.set_current_setup(value)
	elseif G.SETTINGS then
		G.SETTINGS.current_setup = value
	end
end

local function get_deck_pool()
	local deck_pool = G.P_CENTER_POOLS and G.P_CENTER_POOLS.Back or {}
	if SMODS and SMODS.collection_pool then
		deck_pool = SMODS.collection_pool(deck_pool)
	end
	return deck_pool or {}
end

local function find_deck_pool_index(deck_key, deck_name)
	for index, center in ipairs(get_deck_pool()) do
		if center.key == deck_key or center.name == deck_name then
			return index, center.name
		end
	end
	return nil, deck_name
end

local function snapshot_cocktail_selector_return_context()
	local center = get_viewed_back_center()
	cocktail_selector_return_context = {
		current_setup = get_current_setup(),
		deck_key = get_center_key(center) or "b_mp_cocktail",
		deck_name = center and center.name or nil,
		stake = G.viewed_stake,
		sleeve = G.viewed_sleeve,
		lobby_code = MP.LOBBY and MP.LOBBY.code or nil,
		galdur_page = Galdur and Galdur.run_setup and Galdur.run_setup.current_page or nil,
	}
end

local function remove_lobby_run_setup_seed(context)
	if not (context and context.lobby_code and MP.LOBBY and MP.LOBBY.code == context.lobby_code) then
		return
	end

	if G.OVERLAY_MENU and G.OVERLAY_MENU.get_UIE_by_ID then
		local seed_toggle = G.OVERLAY_MENU:get_UIE_by_ID("run_setup_seed")
		if seed_toggle and seed_toggle.remove then
			seed_toggle:remove()
		end
	end
end

local function restore_cocktail_galdur_state(context)
	if not (Galdur and Galdur.run_setup and Galdur.run_setup.choices) then
		return
	end

	if context.galdur_page then
		Galdur.run_setup.current_page = context.galdur_page
	end
	if G.GAME and G.GAME.viewed_back then
		Galdur.run_setup.choices.deck = G.GAME.viewed_back
	end
	if context.stake then
		Galdur.run_setup.choices.stake = context.stake
	end
end

local function restore_cocktail_selection(context)
	if not context then
		return
	end

	local center = context.deck_key and G.P_CENTERS and G.P_CENTERS[context.deck_key] or nil
	local deck_index, deck_name = find_deck_pool_index(context.deck_key, context.deck_name)
	local galdur_setup = Galdur and Galdur.config and Galdur.config.use and Galdur.run_setup
	if center and galdur_setup and G.GAME then
		if Back and get_deck_from_name and center.name then
			G.GAME.viewed_back = Back(get_deck_from_name(center.name))
		else
			G.GAME.viewed_back = center
		end
	elseif center and deck_index and G.FUNCS and G.FUNCS.change_viewed_back then
		G.FUNCS.change_viewed_back({ to_key = deck_index, to_val = deck_name })
	elseif center and G.GAME and G.GAME.viewed_back and G.GAME.viewed_back.change_to then
		G.GAME.viewed_back:change_to(center)
	elseif center and G.GAME then
		G.GAME.viewed_back = center
	end

	if context.stake then
		if G.FUNCS and G.FUNCS.change_stake then
			G.FUNCS.change_stake({ to_key = context.stake })
		else
			G.viewed_stake = context.stake
		end
	end
	if context.sleeve then
		G.viewed_sleeve = context.sleeve
	end

	restore_cocktail_galdur_state(context)
	set_current_setup(context.current_setup)
end

local function return_from_cocktail_selector(e)
	local context = cocktail_selector_return_context
	set_current_setup(context and context.current_setup)

	if G.FUNCS and G.FUNCS.setup_run then
		G.FUNCS.setup_run(e or { config = {} })
		remove_lobby_run_setup_seed(context)
		restore_cocktail_selection(context)
	else
		if BALATRO.exit_overlay_menu then
			BALATRO.exit_overlay_menu()
		elseif G.FUNCS and G.FUNCS.exit_overlay_menu then
			G.FUNCS.exit_overlay_menu()
		end
	end

	cocktail_selector_return_context = nil
end

local function get_cocktail_deck_selection_state(config_char)
	local selection = tonumber(config_char) or 0
	return {
		highlighted = selection >= 1,
		forced = config_char == "2",
	}
end

local function build_cocktail_selector_state(runtime)
	local decks = runtime.get_decks()
	local deck_count = #decks
	local entries = {}

	for index, deck_key in ipairs(decks) do
		local selection_state = get_cocktail_deck_selection_state(runtime.cfg_readpos(index))
		entries[#entries + 1] = {
			deck_key = deck_key,
			row = math.floor((((index - 1) / deck_count) * 2) + 1),
			highlighted = selection_state.highlighted,
			forced = selection_state.forced,
		}
	end

	return {
		decks = decks,
		entries = entries,
		show_active_decks = runtime.cfg_readpos("show") ~= "H",
	}
end

local function clear_cocktail_selector_areas(runtime)
	local selector_areas = runtime.get_selector_areas()
	for i = 1, #selector_areas do
		selector_areas[i]:remove()
		selector_areas[i] = nil
	end
end

local function create_cocktail_selector_areas(runtime)
	clear_cocktail_selector_areas(runtime)
	for i = 1, 2 do
		runtime.set_select_area(i, CardArea(
			G.ROOM.T.x + 0.2 * G.ROOM.T.w / 1.5,
			G.ROOM.T.h,
			5.3 * G.CARD_W,
			1.03 * G.CARD_H,
			{ card_limit = 5, type = "title", highlight_limit = 999, collection = true }
		))
	end
end

local function populate_cocktail_selector_areas(runtime, selector_state)
	local selector_areas = runtime.get_selector_areas()
	for entry_index, entry in ipairs(selector_state.entries) do
		local center = G.P_CENTERS[entry.deck_key]
		runtime.set_viewed_back(center)
		local card = Card(
			G.ROOM.T.x + 0.2 * G.ROOM.T.w / 2,
			G.ROOM.T.h,
			G.CARD_W,
			G.CARD_H,
			pseudorandom_element(G.P_CARDS),
			G.P_CENTERS.c_base,
			{ playing_card = entry_index, bypass_back = center.pos }
		)
		selector_areas[entry.row]:emplace(card)
		runtime.set_selector_card_state(card, entry.deck_key, entry.highlighted, entry.forced)
	end

	runtime.set_viewed_back(G.P_CENTERS["b_mp_cocktail"])
	runtime.set_show_active_decks(selector_state.show_active_decks)
end

local function build_cocktail_selector_deck_tables(runtime)
	local deck_tables = {}
	local selector_areas = runtime.get_selector_areas()
	for i = 1, #selector_areas do
		deck_tables[i] = {
			n = G.UIT.R,
			config = { align = "cm", padding = 0, no_fill = true },
			nodes = {
				{ n = G.UIT.O, config = { object = selector_areas[i] } },
			},
		}
	end
	return deck_tables
end

local function build_cocktail_selector_text_row(localize_key, scale)
	return {
		n = G.UIT.R,
		config = { align = "cl", padding = 0 },
		nodes = {
			{
				n = G.UIT.T,
				config = { text = localize(localize_key), scale = scale, colour = G.C.WHITE },
			},
		},
	}
end

local function build_cocktail_selector_overlay_definition(runtime, deck_tables)
	return create_UIBox_generic_options({
		back_func = "mp_return_from_cocktail_selector",
		snap_back = true,
		contents = {
			{
				n = G.UIT.R,
				config = {
					padding = 0.0,
					align = "cl",
				},
				nodes = {
					create_toggle({
						id = "show_cocktail_decks",
						label = "Show active decks during run",
						ref_table = MP,
						ref_value = "show_cocktail_decks",
						callback = function(bool)
							runtime.cfg_edit(bool, "show")
						end,
					}),
				},
			},
			{ n = G.UIT.R, config = { align = "cl", padding = 0.4, minh = 0.4 } },
			{
				n = G.UIT.R,
				config = { align = "cm", minw = 2.5, padding = 0.1, r = 0.1, colour = G.C.BLACK, emboss = 0.05 },
				nodes = deck_tables,
			},
			build_cocktail_selector_text_row("k_cocktail_select", 0.48),
			build_cocktail_selector_text_row("k_cocktail_shiftclick", 0.32),
			build_cocktail_selector_text_row("k_cocktail_rightclick", 0.32),
		},
	})
end

local function open_cocktail_selector_overlay(runtime)
	local selector_state = build_cocktail_selector_state(runtime)
	snapshot_cocktail_selector_return_context()
	create_cocktail_selector_areas(runtime)
	populate_cocktail_selector_areas(runtime, selector_state)

	G.FUNCS.overlay_menu({
		definition = build_cocktail_selector_overlay_definition(runtime, build_cocktail_selector_deck_tables(runtime)),
	})
end

local function build_cocktail_edit_badge_text_row(localize_key, scale)
	return {
		n = G.UIT.R,
		config = { align = "cm", maxw = 2 },
		nodes = {
			{
				n = G.UIT.T,
				config = { text = localize(localize_key), scale = scale, colour = G.C.WHITE, shadow = true },
			},
		},
	}
end

local function install_cocktail_card_hooks(runtime)
	MP.HOOKS.register_method_hook(Card, "Card", "click", "mp.cocktail.deck_selector", {
		after = function(ctx, self)
			if G.STAGE == G.STAGES.MAIN_MENU and is_cocktail_select(runtime, self) then
				open_cocktail_selector_overlay(runtime)
			end
		end,
	})

	MP.HOOKS.register_method_hook(Card, "Card", "draw", "mp.cocktail.edit_badge", {
		after = function(ctx, self)
			if G.STAGE == G.STAGES.MAIN_MENU then
				if not self.children.view_deck then
					self.children.view_deck = UIBox({
						definition = {
							n = G.UIT.ROOT,
							config = { align = "cm", padding = 0.1, r = 0.1, colour = G.C.CLEAR },
							nodes = {
								{
									n = G.UIT.R,
									config = {
										align = "cm",
										padding = 0.05,
										r = 0.1,
										colour = adjust_alpha(G.C.BLACK, 0.5),
										func = "set_button_pip",
										focus_args = { button = "triggerright", orientation = "bm", scale = 0.6 },
										button = "deck_info",
									},
									nodes = {
										build_cocktail_edit_badge_text_row("k_edit", 0.48),
										build_cocktail_edit_badge_text_row("k_deck", 0.38),
									},
								},
							},
						},
						config = { align = "cm", offset = { x = 0, y = 0 }, major = self, parent = self },
					})
					self.children.view_deck.states.collide.can = false
				end
				local bool = self.states.hover.is and is_cocktail_select(runtime, self)
				self.children.view_deck.states.visible = bool
			end
		end,
	})

	SMODS.DrawStep({
		key = "mp_cocktail_forced",
		order = 5,
		func = function(self)
			if self.mp_cocktail_forced then self.children.back:draw_shader("foil", nil, self.ARGS.send_to_shader) end
		end,
		conditions = { vortex = false, facing = "back" },
	})

	MP.HOOKS.register_method_hook(Card, "Card", "hover", "mp.cocktail.preview_popup", {
		after = function(ctx, self)
			if self.mp_cocktail_select then
				self.ability_UIBox_table = self:generate_UIBox_ability_table()
				self.config.h_popup = G.UIDEF.card_h_popup(self)
				self.config.h_popup_config = self:align_h_popup()
				Node.hover(self)
			end
		end,
	})

	MP.HOOKS.register_method_hook(Card, "Card", "highlight", "mp.cocktail.highlight_logic", {
		before = function(ctx, self)
			if self.mp_cocktail_select then
				local is_highlighted = ctx.args[1]
				local shift = G.CONTROLLER.held_keys["lshift"] or G.CONTROLLER.held_keys["rshift"]
				if shift and self.mp_cocktail_forced then
					is_highlighted = false
					self.mp_cocktail_forced = false
				elseif self.mp_cocktail_forced then
					is_highlighted = true
					self.mp_cocktail_forced = false
				elseif shift then
					is_highlighted = true
					if runtime.get_forced_num() < 3 then
						self.mp_cocktail_forced = true
						play_sound("foil1", 1.5, 0.3)
					else
						play_sound("timpani", 0.9, 0.7)
						play_sound("timpani", 1.2, 0.7)
					end
				end
				ctx.args[1] = is_highlighted
				runtime.cfg_edit(self.mp_cocktail_forced and 2 or is_highlighted, self.mp_cocktail_select)
			end
		end,
	})
end

local function install_cocktail_area_hooks(runtime)
	MP.HOOKS.register_method_hook(CardArea, "CardArea", "can_highlight", "mp.cocktail.select_can_highlight", {
		before = function(ctx, self)
			local card = ctx.args[1]
			if card.mp_cocktail_select then
				ctx.skip_original = true
				ctx.results = { true, n = 1 }
			end
		end,
	})
end

local function install_cocktail_controller_hooks(runtime)
	MP.HOOKS.register_method_hook(
		Controller,
		"Controller",
		"queue_R_cursor_press",
		"mp.cocktail.bulk_toggle",
		{
			after = function()
				local selector_areas = runtime.get_selector_areas()
				if selector_areas[1] and selector_areas[1].cards then
					local highlight = true
					for i = 1, #selector_areas do
						for j = 1, #selector_areas[i].cards do
							if selector_areas[i].cards[j].highlighted then
								highlight = false
								break
							end
						end
						if not highlight then
							break
						end
					end
					for i = 1, #selector_areas do
						for j = 1, #selector_areas[i].cards do
							runtime.set_selector_card_highlight(selector_areas[i].cards[j], highlight)
						end
					end
					if highlight then
						play_sound("cardSlide1")
					else
						play_sound("cardSlide2", nil, 0.3)
					end
					runtime.cfg_edit(highlight)
				end
			end,
		}
	)
end

function selector.install(runtime)
	if type(runtime) ~= "table" then
		sendWarnMessage("Missing Cocktail deck runtime module.", "MULTIPLAYER")
		return false
	end

	if BALATRO.set_ui_function then
		BALATRO.set_ui_function("mp_return_from_cocktail_selector", return_from_cocktail_selector)
	else
		G.FUNCS.mp_return_from_cocktail_selector = return_from_cocktail_selector
	end
	install_cocktail_card_hooks(runtime)
	install_cocktail_area_hooks(runtime)
	install_cocktail_controller_hooks(runtime)
	return true
end

return selector
