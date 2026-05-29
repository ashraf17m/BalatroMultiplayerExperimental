local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

BALATRO.set_ui_function("open_kofi", function()
	BALATRO.open_url("https://ko-fi.com/virtualized")
end)

BALATRO.set_ui_function("continue_in_singleplayer", function()
	if MP.RESUME and MP.RESUME.clear_saved_resume then
		MP.RESUME.clear_saved_resume()
	end

	if MP.CONNECTION_SESSION and MP.CONNECTION_SESSION.clear_local_lobby_session then
		MP.CONNECTION_SESSION.clear_local_lobby_session({
			clear_reconnect = false,
		})
	end
	MP.ACTIONS.leave_lobby()
	BALATRO.continue_in_singleplayer_run()
end)

BALATRO.set_ui_function("overlay_endgame_menu", function()
	BALATRO.open_overlay_menu({
		definition = MP.GAME.won and create_UIBox_win() or create_UIBox_game_over(),
		config = { no_esc = true },
	})
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
				local jimbo_words = MP.GAME.won and "wq_" .. math.random(1, 7) or "lq_" .. math.random(1, 10)
				Jimbo:add_speech_bubble(jimbo_words, nil, { quip = true })
				Jimbo:say_stuff(5)
			end
			return true
		end,
	})
end)

BALATRO.set_ui_function("mp_cycle_view_target", function()
	MP.UI.END_GAME_VIEW_MODEL.cycle_view_target()
end)

BALATRO.set_ui_function("change_end_game_view_target", function(args)
	MP.UI.END_GAME_VIEW_MODEL.change_view_target(args.to_key)
end)

BALATRO.set_ui_function("toggle_players_jokers", function()
	MP.UI.END_GAME_VIEW_MODEL.toggle_players_jokers()
end)

BALATRO.set_ui_function("view_nemesis_deck", function()
	MP.UI.END_GAME_VIEW_MODEL.open_nemesis_deck_overlay()
end)
