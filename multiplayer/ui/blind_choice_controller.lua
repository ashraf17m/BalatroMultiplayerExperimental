MP.BLIND_CHOICE_INTERNAL = MP.BLIND_CHOICE_INTERNAL or {}
local INTERNAL = MP.BLIND_CHOICE_INTERNAL
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

if not INTERNAL.get_blind_choice_row_kind_for_row then
	local loaded = MP.PLATFORM.SMODS.load_mod_file("multiplayer/ui/blind_choice_rows.lua", { required = true })
	if loaded == nil then return nil end
end

if not INTERNAL.set_ui_text then
	local loaded = MP.PLATFORM.SMODS.load_mod_file("multiplayer/ui/blind_choice_text.lua", { required = true })
	if loaded == nil then return nil end
end

if not INTERNAL.finish_unready_blind then
	local loaded = MP.PLATFORM.SMODS.load_mod_file("multiplayer/ui/blind_choice_ready.lua", { required = true })
	if loaded == nil then return nil end
end

if not MP.perform_team_skip then
	local loaded = MP.PLATFORM.SMODS.load_mod_file("multiplayer/ui/blind_choice_skip.lua", { required = true })
	if loaded == nil then return nil end
end

BALATRO.set_ui_function("pvp_ready_button", function(e)
	local row = MP.get_blind_choice_row_type(e)
	local is_current_row = row and G.GAME and G.GAME.blind_on_deck == row
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
	local row = MP.get_blind_choice_row_type(e)
	local blind_kind = INTERNAL.get_blind_choice_row_kind_for_row(row)
	local was_readying_pvp_blind = MP.is_readying_pvp_blind and MP.is_readying_pvp_blind()
	if not MP.GAME.ready_blind then
		INTERNAL.clear_skip_ready_for_blind_toggle(false)
	end
	local is_ready = MP.set_match_ready_blind_state and MP.set_match_ready_blind_state(not MP.GAME.ready_blind, blind_kind)

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

	if not MP.LOBBY.code or not e or not e.config or not G.GAME or not G.GAME.blind_on_deck or e.config.ref_table.run_info then
		return
	end

	local row = e.config.id
	if row ~= G.GAME.blind_on_deck then
		INTERNAL.restore_blind_select_label(e, row)
		local blind_state = G.GAME.round_resets
			and G.GAME.round_resets.blind_states
			and G.GAME.round_resets.blind_states[row]
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
	if row ~= G.GAME.blind_on_deck or not INTERNAL.is_team_skip_ready_row(row) then
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
	if G.GAME.current_round.hands_left <= 0 then
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
	if MP.prepare_match_blind_selection then
		MP.prepare_match_blind_selection()
	end
	MP.clear_skip_ready_state()
	MP.reset_round_score_state()
	MP.recalculate_team_state()
	select_blind_ref(e)
	if MP.LOBBY.code then
		local is_cooperative_blind = (MP.is_team_cooperative_blind and MP.is_team_cooperative_blind())
			or (MP.is_coop_blind and MP.is_coop_blind())
		if not is_cooperative_blind then
			MP.ACTIONS.play_hand(0, G.GAME.round_resets.hands)
		end
		MP.ACTIONS.new_round()
		MP.ACTIONS.set_location("loc_playing-" .. (e.config.ref_table.key or e.config.ref_table.name))
		if MP.UI.hide_enemy_location then
			MP.UI.hide_enemy_location()
		end
	end
end)

BALATRO.set_ui_function("skip_blind", function(e)
	local row = MP.get_blind_choice_row_type(e) or (G.GAME and G.GAME.blind_on_deck)
	if INTERNAL.is_team_skip_ready_row(row) then
		if MP.GAME.skip_ready_blind_row == row then
			INTERNAL.clear_skip_ready_for_blind_toggle(true)
		else
			INTERNAL.clear_ready_blind_for_skip_toggle()
			if MP.set_match_skip_ready_blind_row then
				MP.set_match_skip_ready_blind_row(row)
			end
			MP.ACTIONS.set_location("loc_ready_to_skip_for_team_row-" .. row)
			MP.ACTIONS.ready_skip_blind(row)
		end
		return
	end
	INTERNAL.perform_actual_skip(e)
end)

return INTERNAL
