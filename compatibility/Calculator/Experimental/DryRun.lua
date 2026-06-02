-- Calculator V2 dry-run helpers.
--
-- These helpers let V2 execute Balatro's real pre-play mechanics, such as
-- boss-blind card removal, while the state guard owns restoration.

MP = MP or {}
MP.CALCULATOR_V2 = MP.CALCULATOR_V2 or {}

local CALC = MP.CALCULATOR_V2

local function noop_ui_element()
	return {
		juice_up = function() return true end,
		remove = function() return true end,
		config = {
			object = {
				pop_out = function() return true end,
			},
		},
	}
end

local function event_func(event)
	if type(event) ~= "table" then return nil end
	if type(event.func) == "function" then return event.func end
	if type(event.config) == "table" and type(event.config.func) == "function" then return event.config.func end
	return nil
end

local function install_dry_hud_blind(replacements)
	if not G then return end

	local original_hud_blind = G.HUD_blind
	local original_get_uie = original_hud_blind and original_hud_blind.get_UIE_by_ID
	replacements[#replacements + 1] = function()
		if original_hud_blind then original_hud_blind.get_UIE_by_ID = original_get_uie end
		G.HUD_blind = original_hud_blind
	end

	if original_hud_blind and type(original_get_uie) == "function" then
		original_hud_blind.get_UIE_by_ID = function(self, id)
			local ok, result = pcall(original_get_uie, self, id)
			if ok and result then return result end
			return noop_ui_element()
		end
	else
		G.HUD_blind = {
			get_UIE_by_ID = function() return noop_ui_element() end,
		}
	end
end

local function install_dry_blind_visuals(replacements)
	local blind = G and G.GAME and G.GAME.blind
	if not blind then return end

	local original_juice_up = blind.juice_up
	if type(original_juice_up) == "function" then
		replacements[#replacements + 1] = function() blind.juice_up = original_juice_up end
		blind.juice_up = function() return true end
	end
end

local function install_dry_event_manager(replacements)
	if not (G and G.E_MANAGER and type(G.E_MANAGER.add_event) == "function") then return end

	local original_add_event = G.E_MANAGER.add_event
	local previous_flush = CALC.flush_dry_events
	local dry_events = {}
	local dry_event_head = 1
	replacements[#replacements + 1] = function()
		G.E_MANAGER.add_event = original_add_event
		CALC.flush_dry_events = previous_flush
	end

	G.E_MANAGER.add_event = function(_, event)
		if CALC.dry_run_queue_events then
			dry_events[#dry_events + 1] = event
		end
		return event
	end

	CALC.flush_dry_events = function(limit)
		limit = limit or 80
		local processed = 0
		while dry_event_head <= #dry_events do
			processed = processed + 1
			if processed > limit then
				return nil, "dry event limit reached"
			end

			local func = event_func(dry_events[dry_event_head])
			dry_event_head = dry_event_head + 1
			if func then
				local ok, err = pcall(func)
				if not ok then
					return nil, err
				end
			end
		end
		dry_events = {}
		dry_event_head = 1
		return true
	end
end

local function remove_card_from_area(area, card)
	if not card then return nil end

	local cards = area and area.cards
	if type(cards) == "table" then
		for index = #cards, 1, -1 do
			if cards[index] == card then
				table.remove(cards, index)
				break
			end
		end
	end
	return card
end

local function set_area_ranks(area)
	if not (area and type(area.cards) == "table") then return end
	for index, card in ipairs(area.cards) do card.rank = index end
end

local function emplace_card_in_area(area, card)
	if not area or not card then return end

	if type(area.cards) == "table" then area.cards[#area.cards + 1] = card end
	card.area = area
	card.parent = area
	card.layered_parallax = area.layered_parallax
	set_area_ranks(area)
end

local function install_dry_draw_card(replacements)
	if type(draw_card) ~= "function" then return end

	local original_draw_card = draw_card
	replacements[#replacements + 1] = function() draw_card = original_draw_card end
	draw_card = function(from, to, _, _, _, card)
		if card then
			local moved = remove_card_from_area(from, card)
			emplace_card_in_area(to, moved)
			return moved
		end

		local cards = from and from.cards
		local moved = cards and cards[#cards] or nil
		if moved then
			remove_card_from_area(from, moved)
			emplace_card_in_area(to, moved)
		end
		return moved
	end
end

local function install_dry_card_area_highlight_methods(replacements)
	if not CardArea then return end

	local original_add_to_highlighted = CardArea.add_to_highlighted
	local original_remove_from_highlighted = CardArea.remove_from_highlighted
	local original_unhighlight_all = CardArea.unhighlight_all
	replacements[#replacements + 1] = function()
		CardArea.add_to_highlighted = original_add_to_highlighted
		CardArea.remove_from_highlighted = original_remove_from_highlighted
		CardArea.unhighlight_all = original_unhighlight_all
	end

	CardArea.add_to_highlighted = function(self, card)
		if not (self and card and type(self.highlighted) == "table") then return end
		for _, highlighted_card in ipairs(self.highlighted) do
			if highlighted_card == card then return true end
		end
		self.highlighted[#self.highlighted + 1] = card
		card.highlighted = true
		return true
	end

	CardArea.remove_from_highlighted = function(self, card)
		if not (self and card and type(self.highlighted) == "table") then return end
		for index = #self.highlighted, 1, -1 do
			if self.highlighted[index] == card then table.remove(self.highlighted, index) end
		end
		card.highlighted = false
		return true
	end

	CardArea.unhighlight_all = function(self)
		if not (self and type(self.highlighted) == "table") then return end
		for index = #self.highlighted, 1, -1 do
			local card = self.highlighted[index]
			if card then card.highlighted = false end
			table.remove(self.highlighted, index)
		end
		return true
	end
end

local function install_card_method(owner, name, replacement, replacements)
	if not owner or type(owner[name]) ~= "function" then return end

	local original = owner[name]
	replacements[#replacements + 1] = function() owner[name] = original end
	owner[name] = replacement
end

local function install_dry_card_removal_methods(replacements)
	install_card_method(Card, "start_dissolve", function(self)
		self.destroyed = true
		return true
	end, replacements)

	install_card_method(Card, "shatter", function(self)
		self.shattered = true
		self.destroyed = true
		return true
	end, replacements)
end

function CALC.install_dry_runtime(replacements)
	install_dry_hud_blind(replacements)
	install_dry_blind_visuals(replacements)
	install_dry_event_manager(replacements)
	install_dry_card_area_highlight_methods(replacements)
	install_dry_draw_card(replacements)
	install_dry_card_removal_methods(replacements)
end

function CALC.run_pre_score_effects()
	if not (G and G.GAME and G.GAME.blind and type(G.GAME.blind.press_play) == "function") then
		return true
	end

	local previous_queue = CALC.dry_run_queue_events
	CALC.dry_run_queue_events = true
	local ok, err = pcall(G.GAME.blind.press_play, G.GAME.blind)
	local flush_ok, flush_err = true, nil
	if ok and type(CALC.flush_dry_events) == "function" then
		flush_ok, flush_err = CALC.flush_dry_events(120)
	end
	CALC.dry_run_queue_events = previous_queue

	if not ok then
		return nil, "blind pre-play failed: " .. tostring(err)
	end
	if not flush_ok then
		return nil, "blind pre-play events failed: " .. tostring(flush_err)
	end
	return true
end
