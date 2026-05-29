local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function use_standings_hud()
	return (MP.is_ffa_mode and MP.is_ffa_mode()) or (MP.is_teams_mode and MP.is_teams_mode())
end

function MP.UI.update_primary_opponent_blind_name(pop_in)
	if not (MP and MP.LOBBY and MP.LOBBY.code and BALATRO.get_hud_blind and BALATRO.get_hud_blind() and MP.is_pvp_boss and MP.is_pvp_boss()) then
		return false
	end

	if use_standings_hud() then
		return false
	end

	local blind_name = BALATRO.get_hud_blind_element_by_id("HUD_blind_name")
	if not blind_name then
		return false
	end

	return BALATRO.set_text_object_ref(
		blind_name,
		MP.get_primary_opponent_lobby_player() or {},
		"username",
		pop_in
	)
end

function MP.UI.reapply_active_multiplayer_blind_ui()
	if not (MP and MP.LOBBY and MP.LOBBY.code and BALATRO.is_run_stage and BALATRO.is_run_stage()
		and BALATRO.get_current_blind and BALATRO.get_current_blind() and BALATRO.get_hud_blind and BALATRO.get_hud_blind()) then
		return false
	end

	if not (MP.is_pvp_boss and MP.is_pvp_boss()) then
		if MP.UI.reset_blind_HUD then
			MP.UI.reset_blind_HUD()
		end
		return true
	end

	local standings_hud = use_standings_hud()
	if standings_hud then
		BALATRO.set_current_blind_floating_icon_hidden(true)
	end

	if MP.UI.update_blind_HUD then
		MP.UI.update_blind_HUD()
	end

	if standings_hud then
		if MP.UI.refresh_player_list then
			MP.UI.refresh_player_list()
		end
	else
		MP.UI.update_primary_opponent_blind_name(false)
	end

	BALATRO.recalculate_hud_blind()

	return true
end

function MP.UI.update_blind_HUD()
	if MP.LOBBY.code then
		local standings_hud = use_standings_hud()
		if standings_hud then
			if MP.is_pvp_boss() then
				BALATRO.set_current_blind_floating_icon_hidden(true)
				if MP.UI.create_unified_player_list then
					MP.UI.create_unified_player_list()
				end
			else
				if MP.UI.remove_player_list then
					MP.UI.remove_player_list(true)
				end
			end
		else
			if not MP.is_pvp_boss() then
				if MP.UI.reset_blind_HUD then MP.UI.reset_blind_HUD() end
				return
			end

			BALATRO.set_hud_blind_visible(false)

			BALATRO.queue_event({
				trigger = "after",
				delay = 0.3,
				blockable = false,
				func = function()
					local proxy = MP.get_primary_enemy_state and MP.get_primary_enemy_state() or MP.GAME.empty_enemy
					local blind_count = BALATRO.get_hud_blind_element_by_id("HUD_blind_count")
					if blind_count then
						BALATRO.set_text_ref_node(blind_count, proxy, "score_text", "multiplayer_blind_chip_UI_scale")
					end

					local hud_blind_panel = BALATRO.get_hud_blind_element_by_id("HUD_blind")
					if hud_blind_panel then
						hud_blind_panel.states.visible = true
						BALATRO.set_hud_blind_panel_labels(localize("k_enemy_score"), localize("k_enemy_hands"))
					end

					local dollars = BALATRO.get_hud_blind_element_by_id("dollars_to_be_earned")
					BALATRO.set_text_object_ref(dollars, proxy, "hands")

					BALATRO.set_hud_blind_visible(true)
					return true
				end,
			})
		end

		if BALATRO.get_current_blind_key and BALATRO.get_current_blind_key() == "bl_mp_nemesis" then
			BALATRO.apply_multiplayer_blind_sprite(MP.UTILS.get_pvp_blind_key())
		end
	end
end

function MP.UI.reset_blind_HUD()
	if MP.LOBBY.code then
		if MP.UI.remove_player_list then
			MP.UI.remove_player_list(true)
		end

		if BALATRO.get_current_blind_key and BALATRO.get_current_blind_key() ~= "bl_mp_nemesis" then
			local native_chips = get_blind_amount(BALATRO.get_ante()) * (BALATRO.get_current_blind_mult() or 0) * (BALATRO.get_starting_ante_scaling() or 1)
			if MP.is_coop_blind and MP.is_coop_blind() and MP.scale_coop_blind_amount then
				native_chips = MP.scale_coop_blind_amount(native_chips)
			end
			BALATRO.set_current_blind_score(native_chips, number_format(native_chips))
		end

		if BALATRO.get_hud_blind and BALATRO.get_hud_blind() then
			BALATRO.set_hud_blind_visible(true)
			local blind_name = BALATRO.get_hud_blind_element_by_id("HUD_blind_name")
			BALATRO.set_text_object_ref(blind_name, BALATRO.get_current_blind(), "loc_name")

			local blind_count = BALATRO.get_hud_blind_element_by_id("HUD_blind_count")
			if blind_count then
				BALATRO.set_text_ref_node(blind_count, BALATRO.get_current_blind(), "chip_text", "blind_chip_UI_scale")
				BALATRO.call_ui_function("blind_chip_UI_scale", blind_count)
			end

			BALATRO.set_hud_blind_panel_labels(localize("ph_blind_score_at_least"), localize("ph_blind_reward"))

			local dollars = BALATRO.get_hud_blind_element_by_id("dollars_to_be_earned")
			BALATRO.set_text_object_ref(dollars, BALATRO.get_current_round(), "dollars_to_be_earned")
		end
	end
end
BALATRO.set_ui_function("multiplayer_blind_chip_UI_scale", function(e)
	local enemy_view = MP.get_primary_enemy_state and MP.get_primary_enemy_state()
	if not enemy_view then return end
	local new_score_text = MP.INSANE_INT.to_string(enemy_view.score)
	if BALATRO.get_current_blind and BALATRO.get_current_blind() and enemy_view.score and enemy_view.score_text ~= new_score_text then
		if not MP.INSANE_INT.greater_than(enemy_view.score, MP.INSANE_INT.create(0, G.E_SWITCH_POINT, 0)) then
			e.config.scale = scale_number(enemy_view.score.coefficient, 0.7, 100000)
		end
		enemy_view.score_text = new_score_text
	end
end)

function MP.UI.juice_up_pvp_hud()
	if MP.is_pvp_boss() then
		local is_ffa = MP.is_ffa_mode and MP.is_ffa_mode()

		if not is_ffa then
			local blind_count = BALATRO.get_hud_blind_element_by_id("HUD_blind_count")
			if blind_count then blind_count:juice_up() end
		end
		local dollars = BALATRO.get_hud_blind_element_by_id("dollars_to_be_earned")
		if dollars then dollars:juice_up() end
	end
end
