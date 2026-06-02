MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.BALATRO = MP.PLATFORM.BALATRO or {}

local BALATRO = MP.PLATFORM.BALATRO
local get_root = BALATRO.get_root

function BALATRO.open_url(url)
	if love and love.system and love.system.openURL then
		love.system.openURL(url)
		return true
	end

	return false
end

function BALATRO.attention_text(config)
	if attention_text then
		attention_text(config)
		return true
	end

	return false
end

function BALATRO.play_sound(...)
	if play_sound then
		play_sound(...)
		return true
	end

	return false
end

function BALATRO.get_monotonic_time_ms()
	if love and love.timer and love.timer.getTime then
		return love.timer.getTime() * 1000
	end

	return os.clock() * 1000
end

function BALATRO.delay(...)
	if delay then
		return delay(...)
	end
end

function BALATRO.create_buffered_dollars_reward(dollars)
	local game = BALATRO.get_game and BALATRO.get_game() or nil
	if game then
		game.dollar_buffer = (game.dollar_buffer or 0) + dollars
	end

	return {
		dollars = dollars,
		func = function()
			BALATRO.queue_event({
				func = function()
					local current_game = BALATRO.get_game and BALATRO.get_game() or nil
					if current_game then
						current_game.dollar_buffer = 0
					end
					return true
				end,
			})
		end,
	}
end

function BALATRO.unhighlight_hand()
	local hand = BALATRO.get_hand_area and BALATRO.get_hand_area() or nil
	if hand and type(hand.unhighlight_all) == "function" then
		hand:unhighlight_all()
		return true
	end

	return false
end

function BALATRO.update_hand_text(...)
	if update_hand_text then
		return update_hand_text(...)
	end
end

function BALATRO.card_eval_status_text(...)
	if card_eval_status_text then
		return card_eval_status_text(...)
	end
end

function BALATRO.eval_card(...)
	if eval_card then
		return eval_card(...)
	end
	return {}
end

function BALATRO.ease_dollars(...)
	if ease_dollars then
		return ease_dollars(...)
	end
end

function BALATRO.create_dyna_text(config)
	return DynaText(config)
end

function BALATRO.create_animated_sprite(x, y, w, h, atlas, pos)
	return AnimatedSprite(x, y, w, h, atlas, pos)
end

function BALATRO.create_playing_card(config, card_area)
	return create_playing_card(config, card_area, true, true, nil, false)
end

function BALATRO.create_card(...)
	return create_card(...)
end

function BALATRO.create_card_object(...)
	return Card(...)
end

function BALATRO.save_card_area(card_area)
	return card_area and card_area.save and card_area:save() or nil
end

function BALATRO.load_card_area(card_area, save_data)
	return card_area and card_area.load and card_area:load(save_data) or nil
end

function BALATRO.remove_last_playing_card()
	local playing_cards = MP.PLATFORM.BALATRO.get_playing_cards and MP.PLATFORM.BALATRO.get_playing_cards() or nil
	if not playing_cards then
		return nil
	end

	return table.remove(playing_cards, #playing_cards)
end

function BALATRO.get_timer_ante()
	local root = get_root()
	return root and root.timer_ante or nil
end

function BALATRO.set_timer_ante(value)
	local root = get_root()
	if not root then
		return false
	end

	root.timer_ante = value
	return true
end

return BALATRO
