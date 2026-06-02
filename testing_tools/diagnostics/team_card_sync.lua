MP.SYNC = MP.SYNC or {}

local team_card_sync = MP.SYNC.TEAM_CARD or {}
MP.SYNC.TEAM_CARD = team_card_sync

local diagnostics = team_card_sync.diagnostics or {}
team_card_sync.diagnostics = diagnostics

if diagnostics._loaded then
	return
end
diagnostics._loaded = true

local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() return false end

local function is_enabled()
	return MP.UTILS
		and MP.UTILS.is_runtime_trace_enabled
		and MP.UTILS.is_runtime_trace_enabled()
end

diagnostics.is_enabled = is_enabled

function diagnostics.trace_event(event, fields)
	if not is_enabled() then
		return false
	end

	return trace_runtime_event("team_card_sync." .. tostring(event), fields)
end

local function get_area_name(area)
	if not area then return "none" end
	if area == (BALATRO.get_deck_area and BALATRO.get_deck_area()) then return "deck" end
	if area == (BALATRO.get_hand_area and BALATRO.get_hand_area()) then return "hand" end
	if area == (BALATRO.get_play_area and BALATRO.get_play_area()) then return "play" end
	if area == (BALATRO.get_discard_area and BALATRO.get_discard_area()) then return "discard" end
	if area == (BALATRO.get_jokers_area and BALATRO.get_jokers_area()) then return "jokers" end
	if area == (BALATRO.get_consumeables_area and BALATRO.get_consumeables_area()) then return "consumeables" end
	return tostring(area.config and area.config.type or "unknown")
end

local function is_playing_card_in_deck_list(card)
	local playing_cards = BALATRO.get_playing_cards and BALATRO.get_playing_cards() or nil
	if not playing_cards then
		return false
	end

	for _, playing_card in ipairs(playing_cards) do
		if playing_card == card then
			return true
		end
	end

	return false
end

local function is_sync_active()
	return team_card_sync.is_sync_active and team_card_sync.is_sync_active()
end

local function is_applying_remote_change()
	local value = team_card_sync.is_applying_remote_change
	if type(value) == "function" then
		return value()
	end
	return value
end

local function add_fields(target, fields)
	if type(fields) ~= "table" then
		return target
	end

	for key, value in pairs(fields) do
		target[key] = value
	end
	return target
end

function diagnostics.card_fields(card, area)
	if not is_enabled() then
		return nil
	end

	return {
		area = get_area_name(area or (card and card.area)),
		card_id = card and card.mp_card_id or "nil",
		playing_card = card and card.playing_card or "nil",
		ability_set = card and card.ability and card.ability.set or "nil",
		synced = not not (card and card.mp_synced_as_added),
		pending = not not (card and card.mp_team_card_add_sync_pending),
		in_playing_cards = is_playing_card_in_deck_list(card),
		removed = not not (card and card.removed),
		destroyed = not not (card and card.destroyed),
		shattered = not not (card and card.shattered),
		dissolve = not not (card and card.dissolve),
		active = is_sync_active(),
		applying_remote = not not is_applying_remote_change(),
		suspended = not not MP.TEAM_CARD_SUSPENDED,
		initializing = not not MP.TEAM_CARD_INITIALIZING,
	}
end

function diagnostics.trace_card(event, card, area, fields)
	if not is_enabled() then
		return false
	end

	return diagnostics.trace_event(event, add_fields(diagnostics.card_fields(card, area) or {}, fields))
end

function diagnostics.install_observer_hooks()
	if not is_enabled() or diagnostics._observer_hooks_installed then
		return false
	end
	if not (MP.HOOKS and Card and team_card_sync.is_syncable_playing_card) then
		return false
	end

	diagnostics._observer_hooks_installed = true
	MP.HOOKS.register_method_hook(Card, "Card", "add_to_deck", "mp.team_card_sync.diagnostics.add_to_deck", {
		after = function(ctx, self)
			if MP.CALCULATOR_V2 and MP.CALCULATOR_V2.dry_run_active then return end
			if not team_card_sync.is_syncable_playing_card(self) then return end

			diagnostics.trace_card("add_to_deck_observed", self)
		end,
	})
	return true
end
