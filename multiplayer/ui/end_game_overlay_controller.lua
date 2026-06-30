local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
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
	BALATRO.open_overlay_menu({
		definition = MP.GAME.won and create_UIBox_win() or create_UIBox_game_over(),
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
					local jimbo_words = MP.GAME.won and "wq_" .. math.random(1, 7) or "lq_" .. math.random(1, 10)
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
