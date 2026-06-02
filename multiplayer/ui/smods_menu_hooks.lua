local current_mod = MP.PLATFORM and MP.PLATFORM.SMODS and MP.PLATFORM.SMODS.get_current_mod
	and MP.PLATFORM.SMODS.get_current_mod() or MP
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

current_mod.credits_tab = MP.UI.create_credits_tab

current_mod.config_tab = MP.UI.create_config_tab

current_mod.extra_tabs = MP.UI.create_extra_tabs

BALATRO.set_ui_function("bmp_discord", function(e)
	BALATRO.open_url("https://discord.gg/gEemz4ptuF")
end)

BALATRO.set_ui_function("bmp_github", function(e)
	BALATRO.open_url("https://github.com/Balatro-Multiplayer/BalatroMultiplayer/")
end)

BALATRO.set_ui_function("change_blind_col", function(args)
	local blind_col = MP.UTILS.save_blind_col(args.to_val)
	local sprite = BALATRO.get_overlay_element_by_id("blind_col_changer_sprite")
	local next_sprite = BALATRO.create_animated_sprite(
		0,
		0,
		1.4,
		1.4,
		BALATRO.get_animation_atlas("mp_player_blind_col"),
		BALATRO.get_blind_def(MP.UTILS.blind_col_numtokey(blind_col)).pos
	)
	MP.UI.UTILS.replace_config_object(sprite, next_sprite, {
		recalculate_object = false,
		recalculate_ui_box = false,
	})
	next_sprite:define_draw_steps({
		{ shader = "dissolve", shadow_height = 0.05 },
		{ shader = "dissolve" },
	})
	BALATRO.recalculate_ui(sprite)
	local option = BALATRO.get_overlay_element_by_id("blind_col_changer_option")
	option.children[1].children[1].config.text =
		localize({ type = "name_text", key = MP.UTILS.blind_col_numtokey(blind_col), set = "Blind" })
	BALATRO.recalculate_ui(option)
end)

BALATRO.set_ui_function("mp_change_timersfx", function(args)
	MP.PLATFORM.SMODS.set_config_value("timersfx", args.to_key)
	MP.save_current_config()
end)

BALATRO.set_ui_function("mp_change_score_calculator_backend", function(args)
	MP.PLATFORM.SMODS.set_config_value("calculator.backend", args.to_key)
	MP.save_current_config()

	local overlay = BALATRO.get_overlay_menu()
	local option_row = BALATRO.get_overlay_element_by_id("score_calculator_backend")
	local cycle_main = option_row and overlay and overlay.get_UIE_by_ID
		and overlay:get_UIE_by_ID("cycle_main", option_row) or nil
	if cycle_main and cycle_main.config and MP.UI and type(MP.UI.get_score_calculator_backend_tooltip) == "function" then
		cycle_main.config.on_demand_tooltip = {
			text = MP.UI.get_score_calculator_backend_tooltip(args.to_key),
		}
	end

	if MP and MP.CALCULATOR_V2 and type(MP.CALCULATOR_V2.invalidate_cache) == "function" then
		MP.CALCULATOR_V2.invalidate_cache()
	end
	if MP.COMPATIBILITY and MP.COMPATIBILITY.PREVIEW then
		MP.COMPATIBILITY.PREVIEW.refresh_after_score_calculator_backend_change(args.to_key)
	end
end)
