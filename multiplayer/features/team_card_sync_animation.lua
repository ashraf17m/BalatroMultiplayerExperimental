MP.SYNC = MP.SYNC or {}

local team_card_sync = MP.SYNC.TEAM_CARD or {}
MP.SYNC.TEAM_CARD = team_card_sync

if team_card_sync._animation_loaded then
	return
end
team_card_sync._animation_loaded = true

local BALATRO = MP.PLATFORM.BALATRO

local require_snapshot_api = assert(team_card_sync.require_snapshot_api, "Team card sync snapshot API missing: require_snapshot_api")
local get_card_by_id = require_snapshot_api("get_card_by_id")

local function apply_remote_team_card_changes_now(changes, options)
	if team_card_sync.apply_remote_changes_now then
		return team_card_sync.apply_remote_changes_now(changes, options)
	end

	return 0
end

local function is_card_in_play_area(card)
	return team_card_sync.is_card_in_play_area and team_card_sync.is_card_in_play_area(card)
end

local function is_live_card(card)
	return card and not (card.removed or card.destroyed or card.shattered or card.dissolve)
end

local function refresh_card_sprites_after_remote_animation(card)
	if not card then
		return
	end
	if card.config and card.config.center and type(card.set_sprites) == "function" then
		card:set_sprites(card.config.center)
	end
	if card.ability and type(card.should_hide_front) == "function" then
		card.front_hidden = card:should_hide_front()
	end
end

local function queue_card_flip_event(card, delay_seconds, sound_key, sound_percent, sound_volume)
	return BALATRO.queue_event({
		trigger = "after",
		delay = delay_seconds,
		func = function()
			if is_live_card(card) and type(card.flip) == "function" then
				card:flip()
				BALATRO.play_sound(sound_key, sound_percent, sound_volume)
				if card.juice_up then
					card:juice_up(0.3, 0.3)
				end
				if sound_key == "tarot2" then
					refresh_card_sprites_after_remote_animation(card)
				end
			end
			return true
		end,
	})
end

local function collect_played_hand_animation_cards(changes)
	local cards = {}
	local seen = {}
	local has_played_card_change = false

	for _, change in ipairs(changes) do
		local card = get_card_by_id(change.card_id)
		if is_card_in_play_area(card) then
			has_played_card_change = true
			if change.action_type ~= "removed" and not seen[card] then
				seen[card] = true
				cards[#cards + 1] = card
			end
		end
	end

	return cards, has_played_card_change
end

local function queue_remote_play_flush_apply(changes)
	BALATRO.queue_event({
		trigger = "after",
		delay = 0.1,
		func = function()
			apply_remote_team_card_changes_now(changes, {
				force = true,
				from_play_flush = true,
			})
			return true
		end,
	})
end

local function queue_unhighlight_after_remote_animation()
	BALATRO.queue_event({
		trigger = "after",
		delay = 0.2,
		func = function()
			BALATRO.unhighlight_hand()
			return true
		end,
	})
end

local function queue_animation_complete(on_complete)
	BALATRO.queue_event({
		trigger = "after",
		delay = 0,
		func = function()
			if type(on_complete) == "function" then
				on_complete()
			end
			return true
		end,
	})
end

function team_card_sync.queue_played_hand_remote_change_animation(changes, on_complete)
	if not BALATRO.queue_event then
		return false
	end

	local cards_to_flip, has_played_card_change = collect_played_hand_animation_cards(changes)
	if not has_played_card_change then
		return false
	end

	for i = 1, #cards_to_flip do
		local percent = 1.15 - (i - 0.999) / (#cards_to_flip - 0.998) * 0.3
		queue_card_flip_event(cards_to_flip[i], 0.15, "card1", percent)
	end

	if #cards_to_flip > 0 then
		BALATRO.delay(0.2)
	end

	queue_remote_play_flush_apply(changes)

	for i = 1, #cards_to_flip do
		local percent = 0.85 + (i - 0.999) / (#cards_to_flip - 0.998) * 0.3
		queue_card_flip_event(cards_to_flip[i], 0.15, "tarot2", percent, 0.6)
	end

	queue_unhighlight_after_remote_animation()
	BALATRO.delay(0.5)
	queue_animation_complete(on_complete)
	return true
end
