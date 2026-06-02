MP.BLIND_CHOICE_INTERNAL = MP.BLIND_CHOICE_INTERNAL or {}
local INTERNAL = MP.BLIND_CHOICE_INTERNAL
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local teams_domain = MP.DOMAIN and MP.DOMAIN.TEAMS or {}
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}

local function load_missing_blind_choice_module(is_loaded, file_path)
	if is_loaded then
		return true
	end

	return MP.PLATFORM.SMODS.load_mod_file(file_path, { required = true }) ~= nil
end

if not load_missing_blind_choice_module(INTERNAL.get_blind_choice_row_kind_for_row, "multiplayer/ui/blind_choice_rows.lua") then
	return nil
end

if not load_missing_blind_choice_module(INTERNAL.set_ui_text, "multiplayer/ui/blind_choice_text.lua") then
	return nil
end

if not load_missing_blind_choice_module(INTERNAL.finish_unready_blind, "multiplayer/ui/blind_choice_ready.lua") then
	return nil
end

if not load_missing_blind_choice_module(INTERNAL.perform_team_skip, "multiplayer/ui/blind_choice_skip.lua") then
	return nil
end

BALATRO.set_ui_function("pvp_ready_button", function(e)
	local row = INTERNAL.get_blind_choice_row_type(e)
	local blind_on_deck = BALATRO.get_blind_on_deck and BALATRO.get_blind_on_deck() or nil
	local is_current_row = row and blind_on_deck == row
	if is_current_row then
		e.config.button = "mp_toggle_ready"
		e.config.one_press = false
		e.children[1].config.ref_table = MP.GAME
		e.children[1].config.ref_value = "ready_blind_text"
	else
		INTERNAL.restore_blind_select_label(e, row)
	end
	if is_current_row and e.config.button == "mp_toggle_ready" then
		e.config.colour = (MP.GAME.ready_blind and G.C.GREEN) or G.C.RED
	end
end)

BALATRO.set_ui_function("mp_toggle_ready", function(e)
	sendTraceMessage("Toggling Ready", "MULTIPLAYER")
	local row = INTERNAL.get_blind_choice_row_type(e)
	local blind_kind = INTERNAL.get_blind_choice_row_kind_for_row(row)
	local was_readying_pvp_blind = INTERNAL.is_readying_pvp_blind and INTERNAL.is_readying_pvp_blind()
	if not MP.GAME.ready_blind then
		INTERNAL.clear_skip_ready_for_blind_toggle(false)
	end
	local is_ready = match_domain.set_ready_blind_state and match_domain.set_ready_blind_state(not MP.GAME.ready_blind, blind_kind)

	if is_ready then
		MP.ACTIONS.set_location(INTERNAL.get_ready_blind_location(row))
		MP.ACTIONS.ready_blind(e)
	else
		INTERNAL.finish_unready_blind(was_readying_pvp_blind, true)
	end
	INTERNAL.refresh_timer_hud()
end)

local blind_choice_handler_ref = BALATRO.get_ui_function("blind_choice_handler")
BALATRO.set_ui_function("blind_choice_handler", function(e)
	blind_choice_handler_ref(e)

	local blind_on_deck = BALATRO.get_blind_on_deck and BALATRO.get_blind_on_deck() or nil
	if not MP.LOBBY.code or not e or not e.config or not blind_on_deck or e.config.ref_table.run_info then
		return
	end

	local row = e.config.id
	if row ~= blind_on_deck then
		INTERNAL.restore_blind_select_label(e, row)
		local blind_state = BALATRO.get_blind_state and BALATRO.get_blind_state(row) or nil
		if blind_state == "Skipped" or blind_state == "Defeated" then
			local tag = e.UIBox and e.UIBox:get_UIE_by_ID("tag_" .. row)
			local tag_container = e.UIBox and e.UIBox:get_UIE_by_ID("tag_container")
			local button = tag and tag.children and tag.children[2]
			if button then
				button.config.button = nil
				button.config.hover = false
				button.config.colour = G.C.UI.BACKGROUND_INACTIVE
				if button.children and button.children[1] and button.children[1].config then
					button.children[1].config.colour = G.C.UI.TEXT_INACTIVE
				end
			end
			if tag and tag.config then
				tag.config.outline_colour = G.C.UI.BACKGROUND_INACTIVE
			end
			if tag_container and tag_container.children then
				local heading = tag_container.children[1]
				local skip_button = tag_container.children[2]
				if skip_button and skip_button.set_role then
					skip_button:set_role({ xy_bond = "Weak" })
					skip_button:align(0, 10)
				end
				if heading and heading.set_role then
					heading:set_role({ xy_bond = "Weak" })
					heading:align(0, 10)
				end
			end
		end
	end
	if row ~= blind_on_deck or not INTERNAL.is_team_skip_ready_row(row) then
		return
	end

	local tag = e.UIBox and e.UIBox:get_UIE_by_ID("tag_" .. row)
	local button = tag and tag.children and tag.children[2]
	if not button or not button.children or not button.children[1] then
		return
	end

	local is_ready = MP.GAME.skip_ready_blind_row == row
	button.config.one_press = false
	button.config.colour = is_ready and G.C.GREEN or G.C.RED
	if is_ready then
		local ready_count, total_count = INTERNAL.get_team_skip_ready_progress(row)
		INTERNAL.set_ui_text(button.children[1], tostring(ready_count) .. "/" .. tostring(total_count))
	else
		INTERNAL.set_ui_text(button.children[1], localize("b_skip_blind"))
	end
	button.children[1].config.colour = G.C.UI.TEXT_LIGHT
	tag.config.outline_colour = adjust_alpha(is_ready and G.C.GREEN or G.C.BLUE, 0.5)
end)

local can_play_ref = BALATRO.get_ui_function("can_play")
BALATRO.set_ui_function("can_play", function(e)
	if (BALATRO.get_hands_left and BALATRO.get_hands_left() or 0) <= 0 then
		e.config.colour = G.C.UI.BACKGROUND_INACTIVE
		e.config.button = nil
	else
		can_play_ref(e)
	end
end)

local can_open_ref = BALATRO.get_ui_function("can_open")
BALATRO.set_ui_function("can_open", function(e)
	if MP.GAME.ready_blind then
		e.config.colour = G.C.UI.BACKGROUND_INACTIVE
		e.config.button = nil
		return
	end
	can_open_ref(e)
end)

local select_blind_ref = BALATRO.get_ui_function("select_blind")
BALATRO.set_ui_function("select_blind", function(e)
	if match_domain.prepare_blind_selection then
		match_domain.prepare_blind_selection()
	end
	INTERNAL.clear_skip_ready_state()
	if teams_domain.reset_round_score_state then
		teams_domain.reset_round_score_state()
	end
	if teams_domain.recalculate_state then
		teams_domain.recalculate_state()
	end
	select_blind_ref(e)
	if MP.LOBBY.code then
		local is_cooperative_blind = (teams_domain.is_cooperative_blind and teams_domain.is_cooperative_blind())
			or (MP.is_coop_blind and MP.is_coop_blind())
		if not is_cooperative_blind then
			MP.ACTIONS.play_hand(0, BALATRO.get_round_reset_value and BALATRO.get_round_reset_value("hands", nil) or nil)
		end
		MP.ACTIONS.new_round()
		MP.ACTIONS.set_location("loc_playing-" .. (e.config.ref_table.key or e.config.ref_table.name))
		if MP.UI.hide_enemy_location then
			MP.UI.hide_enemy_location()
		end
	end
end)

BALATRO.set_ui_function("skip_blind", function(e)
	local row = INTERNAL.get_blind_choice_row_type(e) or (BALATRO.get_blind_on_deck and BALATRO.get_blind_on_deck() or nil)
	if INTERNAL.is_team_skip_ready_row(row) then
		if MP.GAME.skip_ready_blind_row == row then
			INTERNAL.clear_skip_ready_for_blind_toggle(true)
		else
			INTERNAL.clear_ready_blind_for_skip_toggle()
			if match_domain.set_skip_ready_blind_row then
				match_domain.set_skip_ready_blind_row(row)
			end
			MP.ACTIONS.set_location("loc_ready_to_skip_for_team_row-" .. row)
			MP.ACTIONS.ready_skip_blind(row)
		end
		return
	end
	INTERNAL.perform_actual_skip(e)
end)

return INTERNAL
