MP.RECORDER = MP.RECORDER or {}

local json = require("json")
local RECORDER = MP.RECORDER

RECORDER.is_recording = false
RECORDER.step_index = 0

local function json_num(v)
	if type(v) == "number" then
		return v
	end
	if type(v) == "string" then
		return tonumber(v) or 0
	end
	if v == nil then
		return 0
	end
	if to_number then
		local ok, n = pcall(to_number, v)
		if ok and n ~= nil then
			return tonumber(n) or n
		end
	end
	return tonumber(tostring(v)) or 0
end

function RECORDER.reset()
	RECORDER.step_index = 0
	RECORDER.is_recording = true
end

function RECORDER.stop()
	RECORDER.is_recording = false
end

function RECORDER.capture_checkpoint()
	local game = G and G.GAME or nil
	local current_round = game and game.current_round or nil
	local round_resets = game and game.round_resets or nil

	return {
		chips = tostring(game and game.chips or 0),
		dollars = tonumber(game and game.dollars or 0),
		ante = tonumber(round_resets and round_resets.ante or 1),
		round = tonumber(game and game.round or 1),
		hands_left = tonumber(current_round and current_round.hands_left or 0),
		discards_left = tonumber(current_round and current_round.discards_left or 0),
	}
end

-- Pool / shop-roll inputs the spectator's simulation must share with this
-- client for seeded draws to land on identical cards. Captured once at run
-- start (streamed inside START_RUN) and refreshed in deep snapshots.
function RECORDER.capture_sim_inputs()
	if not (G and G.GAME) then
		return nil
	end

	local inputs = {}

	if G.GAME.used_jokers then
		local used = {}
		for k, v in pairs(G.GAME.used_jokers) do
			if v then
				used[tostring(k)] = true
			end
		end
		inputs.used_jokers = used
	end
	inputs.joker_rate = tonumber(G.GAME.joker_rate)
	inputs.tarot_rate = tonumber(G.GAME.tarot_rate)
	inputs.planet_rate = tonumber(G.GAME.planet_rate)
	inputs.spectral_rate = tonumber(G.GAME.spectral_rate)
	inputs.playing_card_rate = tonumber(G.GAME.playing_card_rate)
	inputs.edition_rate = tonumber(G.GAME.edition_rate)
	if G.GAME.shop then
		inputs.shop_joker_max = tonumber(G.GAME.shop.joker_max)
	end
	if G.GAME.banned_keys then
		local banned = {}
		for k, v in pairs(G.GAME.banned_keys) do
			if v then
				banned[tostring(k)] = true
			end
		end
		inputs.banned_keys = banned
	end
	if G.GAME.pool_flags then
		local flags = {}
		for k, v in pairs(G.GAME.pool_flags) do
			if type(v) == "boolean" then
				flags[tostring(k)] = v
			end
		end
		inputs.pool_flags = flags
	end
	local modifiers = G.GAME.modifiers or {}
	inputs.enable_eternals_in_shop = not not modifiers.enable_eternals_in_shop
	inputs.enable_perishables_in_shop = not not modifiers.enable_perishables_in_shop
	inputs.enable_rentals_in_shop = not not modifiers.enable_rentals_in_shop
	-- Collection unlocks change which commons are in the rarity pool.
	-- Same cdt/rarity roll + a different pool = a different joker.
	local locked = {}
	local joker_pool = G.P_CENTER_POOLS and G.P_CENTER_POOLS.Joker
	if type(joker_pool) == "table" then
		for _, center in ipairs(joker_pool) do
			if center and center.key and center.unlocked == false then
				locked[center.key] = true
			end
		end
	end
	inputs.locked_jokers = locked

	return inputs
end

function RECORDER.capture_live_board_state(deep)
	if not (G and G.GAME) then
		return nil
	end

	local jokers = {}
	if G.jokers and G.jokers.cards then
		for _, card in ipairs(G.jokers.cards) do
			local center_key = (card.config and card.config.center and card.config.center.key)
				or (card.config and card.config.center_key)
				or (card.ability and card.ability.name)
			if center_key then
				jokers[#jokers + 1] = {
					key = center_key,
					edition = card.edition and (card.edition.key or card.edition.type),
					eternal = not not (card.ability and card.ability.eternal),
					pinned = not not card.pinned,
					rental = not not (card.ability and card.ability.rental),
					perishable = not not (card.ability and card.ability.perishable),
					sell_cost = card.sell_cost or 0,
					extra = card.ability and card.ability.extra,
					mult = card.ability and card.ability.mult,
					h_mult = card.ability and card.ability.h_mult,
					h_chips = card.ability and card.ability.h_chips,
					x_mult = card.ability and card.ability.x_mult,
					hands_played = card.ability and card.ability.hands_played,
					discards_used = card.ability and card.ability.discards_used,
				}
			end
		end
	end

	local consumeables = {}
	if G.consumeables and G.consumeables.cards then
		for _, card in ipairs(G.consumeables.cards) do
			local center_key = (card.config and card.config.center and card.config.center.key)
				or (card.config and card.config.center_key)
				or (card.ability and card.ability.name)
			if center_key then
				consumeables[#consumeables + 1] = {
					key = center_key,
					edition = card.edition and (card.edition.key or card.edition.type),
					sell_cost = card.sell_cost or 0,
				}
			end
		end
	end

	local hand = {}
	if G.hand and G.hand.cards then
		for _, card in ipairs(G.hand.cards) do
			local base = card.base or {}
			local center_key = (card.config and card.config.center and card.config.center.key)
				or (card.config and card.config.center_key)
			hand[#hand + 1] = {
				suit = base.suit or "Spades",
				value = base.value or "Ace",
				id = base.id or 14,
				nominal = base.nominal or 11,
				center_key = (center_key ~= "c_base" and center_key) or nil,
				edition = card.edition and (card.edition.key or card.edition.type),
				seal = card.seal,
				debuff = not not card.debuff,
				mp_card_id = card.mp_card_id and tostring(card.mp_card_id) or nil,
			}
		end
	end

	local shop_cards = {}
	if G.shop_jokers and G.shop_jokers.cards then
		for idx, card in ipairs(G.shop_jokers.cards) do
			local center_key = (card.config and card.config.center and card.config.center.key)
				or (card.config and card.config.center_key)
			if center_key then
				shop_cards[#shop_cards + 1] = {
					area = "shop_jokers",
					index = idx,
					key = center_key,
					edition = card.edition and (card.edition.key or card.edition.type),
					cost = card.cost,
				}
			end
		end
	end
	if G.shop_vouchers and G.shop_vouchers.cards then
		for idx, card in ipairs(G.shop_vouchers.cards) do
			local center_key = (card.config and card.config.center and card.config.center.key)
				or (card.config and card.config.center_key)
			if center_key then
				shop_cards[#shop_cards + 1] = {
					area = "shop_vouchers",
					index = idx,
					key = center_key,
					cost = card.cost,
				}
			end
		end
	end
	if G.shop_booster and G.shop_booster.cards then
		for idx, card in ipairs(G.shop_booster.cards) do
			local center_key = (card.config and card.config.center and card.config.center.key)
				or (card.config and card.config.center_key)
			if center_key then
				shop_cards[#shop_cards + 1] = {
					area = "shop_booster",
					index = idx,
					key = center_key,
					cost = card.cost,
				}
			end
		end
	end

	local blind = nil
	if G.GAME.blind then
		local def = G.GAME.blind.config and G.GAME.blind.config.blind
		local key = G.GAME.blind.key or (type(def) == "table" and def.key) or nil
		if not key and G.GAME.round_resets and G.GAME.round_resets.blind then
			key = G.GAME.round_resets.blind.key
		end
		if not key and G.GAME.blind_on_deck and G.GAME.round_resets and G.GAME.round_resets.blind_choices then
			key = G.GAME.round_resets.blind_choices[G.GAME.blind_on_deck]
		end
		-- After Blind:defeat(), chips/chip_text are 0. Omit those so the
		-- spectator recomputes from P_BLINDS instead of painting "Score at least 0".
		local chips = json_num(G.GAME.blind.chips)
		local chip_text = G.GAME.blind.chip_text
		if chips == 0 then
			chips = nil
		end
		if chip_text == "0" or chip_text == "" then
			chip_text = nil
		end
		local dollars = json_num(G.GAME.blind.dollars)
		if dollars == 0 then
			dollars = nil
		end
		blind = {
			key = key,
			name = G.GAME.blind.name,
			chips = chips,
			chip_text = chip_text,
			dollars = dollars,
		debuff = G.GAME.blind.debuff,
		disabled = G.GAME.blind.disabled,
		boss = G.GAME.blind.boss,
		blind_on_deck = G.GAME.blind_on_deck,
	}
	end

	-- Pack contents (when a booster is open): the target's real rolls, so
	-- spectators never see locally-generated pack cards.
	local pack_cards = {}
	if G.pack_cards and G.pack_cards.cards then
		for _, card in ipairs(G.pack_cards.cards) do
			local base = card.base or {}
			local center_key = (card.config and card.config.center and card.config.center.key)
				or (card.config and card.config.center_key)
			pack_cards[#pack_cards + 1] = {
				key = center_key,
				suit = base.suit,
				value = base.value,
				edition = card.edition and (card.edition.key or card.edition.type),
				seal = card.seal,
				cost = card.cost,
			}
		end
	end

	local board_state = {
		step = RECORDER.step_index,
		state = G.STATE,
		dollars = json_num(G.GAME.dollars),
		chips = json_num(G.GAME.chips),
		ante = tonumber(G.GAME.round_resets and G.GAME.round_resets.ante or 1),
		round = tonumber(G.GAME.round or 1),
		hands_left = tonumber(G.GAME.current_round and G.GAME.current_round.hands_left or 4),
		hands_played = tonumber(G.GAME.current_round and G.GAME.current_round.hands_played or 0),
		discards_left = tonumber(G.GAME.current_round and G.GAME.current_round.discards_left or 4),
		hands_sub = tonumber(G.GAME.current_round and G.GAME.current_round.hands_sub or 0),
		discards_sub = tonumber(G.GAME.current_round and G.GAME.current_round.discards_sub or 0),
		jokers = jokers,
		consumeables = consumeables,
		hand = hand,
		shop_cards = shop_cards,
		pack_cards = pack_cards,
		pack_choices = tonumber(G.GAME.pack_choices or 1),
		pack_size = tonumber(G.GAME.pack_size or (#pack_cards > 0 and #pack_cards or 0)),
		opened_booster_key = (SMODS and SMODS.OPENED_BOOSTER and (
			(SMODS.OPENED_BOOSTER.config and SMODS.OPENED_BOOSTER.config.center and SMODS.OPENED_BOOSTER.config.center.key)
			or SMODS.OPENED_BOOSTER.config and SMODS.OPENED_BOOSTER.config.center_key
		)) or nil,
		blind = blind,
		blind_on_deck = G.GAME.blind_on_deck,
		blind_choices = G.GAME.round_resets and G.GAME.round_resets.blind_choices,
		pvp_blind_choices = G.GAME.round_resets and G.GAME.round_resets.pvp_blind_choices,
		blind_states = G.GAME.round_resets and G.GAME.round_resets.blind_states,
		location = MP.GAME and MP.GAME.location,
		lives = tonumber(MP.GAME and MP.GAME.lives),
		comeback_bonus = tonumber(MP.GAME and MP.GAME.comeback_bonus) or 0,
		comeback_bonus_given = not not (MP.GAME and MP.GAME.comeback_bonus_given),
		comeback_eval_pending = not not (
			(MP.GAME and MP.GAME.comeback_eval_pending)
			or (MP.GAME and MP.GAME.comeback_bonus_given == false and (tonumber(MP.GAME.comeback_bonus) or 0) > 0)
		),
		round_failed = not not (MP.GAME and MP.GAME.round_failed),
		deck_size = G.deck and G.deck.cards and #G.deck.cards or 52,
		reroll_cost = tonumber(G.GAME.reroll_cost or 0),
	}

	-- Deep fields are only captured for full snapshot requests.
	if deep then
		local deck = {}		if G.deck and G.deck.cards then
			for _, card in ipairs(G.deck.cards) do
				local base = card.base or {}
				local center_key = (card.config and card.config.center and card.config.center.key)
					or (card.config and card.config.center_key)
				deck[#deck + 1] = {
					suit = base.suit,
					value = base.value,
					center_key = (center_key ~= "c_base" and center_key) or nil,
					edition = card.edition and (card.edition.key or card.edition.type),
					seal = card.seal,
					mp_card_id = card.mp_card_id and tostring(card.mp_card_id) or nil,
				}
			end
		end
		board_state.deck = deck

		local discard = {}
		if G.discard and G.discard.cards then
			for _, card in ipairs(G.discard.cards) do
				local base = card.base or {}
				local center_key = (card.config and card.config.center and card.config.center.key)
					or (card.config and card.config.center_key)
				discard[#discard + 1] = {
					suit = base.suit,
					value = base.value,
					center_key = (center_key ~= "c_base" and center_key) or nil,
					edition = card.edition and (card.edition.key or card.edition.type),
					seal = card.seal,
					mp_card_id = card.mp_card_id and tostring(card.mp_card_id) or nil,
				}
			end
		end
		board_state.discard = discard

		local tags = {}
		if G.GAME.tags then
			for _, tag in ipairs(G.GAME.tags) do
				tags[#tags + 1] = { key = tag.key }
			end
		end
		board_state.tags = tags
		board_state.vouchers_used = G.GAME.used_vouchers or {}
		-- Booster slot consumption: vanilla update_shop respawns shop packs
		-- from this map, so a stale copy drifts booster offers after switches.
		if G.GAME.current_round and G.GAME.current_round.used_packs then
			local used_packs = {}
			for pack_pos, pack_key in pairs(G.GAME.current_round.used_packs) do
				used_packs[tostring(pack_pos)] = tostring(pack_key)
			end
			board_state.used_packs = used_packs
		end
		board_state.joker_slots = (G.jokers and G.jokers.config and G.jokers.config.card_limit) or nil
		board_state.hand_size = (G.hand and G.hand.config and G.hand.config.card_limit) or nil
		if G.GAME.pseudorandom then
			local rng = {}
			for k, v in pairs(G.GAME.pseudorandom) do
				if type(v) == "number" then
					-- %.17g is the standard round-trip-safe format for IEEE 754
					-- doubles: 17 significant digits uniquely identify any double.
					-- JSON transmits strings byte-for-byte; numbers can shift by
					-- 1 ulp through the JS serialization layer.
					rng[k] = string.format("%.17g", v)
				elseif type(v) == "string" then
					rng[k] = v
				end
			end
			board_state.pseudorandom = rng
		end
		local sim_inputs = RECORDER.capture_sim_inputs()
		if sim_inputs then
			for input_key, input_value in pairs(sim_inputs) do
				board_state[input_key] = input_value
			end
		end
	end

	return board_state
end

function RECORDER.record_action(action_type, payload)
	if not RECORDER.is_recording then
		return
	end
	if not (MP.LOBBY and MP.LOBBY.code) then
		return
	end
	if MP.SPECTATOR and MP.SPECTATOR.is_spectating then
		return
	end

	RECORDER.step_index = RECORDER.step_index + 1
	local step = RECORDER.step_index

	-- Stream only the action name and vanilla inputs (indices). Never shop
	-- contents, hand, or deck. REROLL_SHOP stays type+step with empty data.
	local action_entry = {
		step = step,
		type = action_type,
		data = payload or {},
	}

	local ok, json_data = pcall(json.encode, action_entry)
	if ok and json_data and MP.ACTIONS and MP.ACTIONS.spectator_action_stream then
		MP.ACTIONS.spectator_action_stream(json_data, step)
	end
	if not ok then
		return
	end
	if MP.TESTING and MP.TESTING.RNG_TRACER and MP.TESTING.RNG_TRACER.active then
		local mods = G and G.GAME and G.GAME.modifiers
		MP.TESTING.RNG_TRACER.act("T", step, action_type, string.format(
			"stake=%s et=%s per=%s jr=%s tr=%s pr=%s sr=%s pcr=%s",
			tostring(G and G.GAME and G.GAME.stake),
			tostring(mods and mods.enable_eternals_in_shop),
			tostring(mods and mods.enable_perishables_in_shop),
			tostring(G and G.GAME and G.GAME.joker_rate),
			tostring(G and G.GAME and G.GAME.tarot_rate),
			tostring(G and G.GAME and G.GAME.planet_rate),
			tostring(G and G.GAME and G.GAME.spectral_rate),
			tostring(G and G.GAME and G.GAME.playing_card_rate)
		))
	end
end

function RECORDER.handle_spectator_request_snapshot(payload)
	if not payload or not payload.spectatorPlayerId then
		return
	end
	if not RECORDER.is_recording or (MP.SPECTATOR and MP.SPECTATOR.is_spectating) then
		return
	end

	local function serve()
		local board_state = RECORDER.capture_live_board_state(true)
		if not board_state then
			return true
		end

		if MP.TESTING and MP.TESTING.log_spectator then
			local shop_keys = {}
			for _, item in ipairs(board_state.shop_cards or {}) do
				shop_keys[#shop_keys + 1] = tostring(item.key)
					.. (item.edition and ("+" .. tostring(item.edition)) or "")
			end
			local cons_keys = {}
			for _, item in ipairs(board_state.consumeables or {}) do
				cons_keys[#cons_keys + 1] = tostring(item.key)
					.. (item.edition and ("+" .. tostring(item.edition)) or "")
			end
			MP.TESTING.log_spectator("SNAP", "provide", string.format(
				"to=%s step=%d shop=[%s] cons=[%s]",
				tostring(payload.spectatorPlayerId):sub(1, 8),
				RECORDER.step_index,
				table.concat(shop_keys, ", "),
				table.concat(cons_keys, ", ")
			))
		end

		local ok, json_data = pcall(json.encode, board_state)
		if ok and json_data and MP.ACTIONS and MP.ACTIONS.spectator_provide_snapshot then
			local self_id = (MP.PLATFORM and MP.PLATFORM.BALATRO and MP.PLATFORM.BALATRO.get_player_id and MP.PLATFORM.BALATRO.get_player_id()) or ""
			MP.ACTIONS.spectator_provide_snapshot(payload.spectatorPlayerId, self_id, json_data)
		end
		return true
	end

	-- Shop-entry window: vanilla fills a new shop's cards inside a delayed,
	-- slide-gated event (Game:update_shop gates on |T.y - VT.y| < 3).
	-- Serving mid-window captures an empty/partial shop row that nothing
	-- downstream corrects, so wait for the same slide-completion signal
	-- before capturing. Additionally, wait for the E_MANAGER queue to drain
	-- so the snapshot's RNG state and its step field are synchronized: the
	-- step field tracks recorded actions, but the RNG reflects event-chain
	-- completions, and capturing between those two moments produces a
	-- snapshot whose RNG is ahead of (or behind) its own step marker.
	if not (G and G.STATE == G.STATES.SHOP) then
		return serve()
	end
	local balatro = MP.PLATFORM and MP.PLATFORM.BALATRO or nil
	if not (balatro and balatro.queue_event) then
		return serve()
	end

	local attempts = 0
	balatro.queue_event({
		trigger = "after",
		delay = 0.05,
		func = function()
			attempts = attempts + 1
			if not (G and G.STATE == G.STATES.SHOP) then
				return serve()
			end
			local events_pending = G.E_MANAGER and type(G.E_MANAGER.queue) == "table" and #G.E_MANAGER.queue > 0
			if not events_pending then
				return serve()
			end
			if attempts > 120 then
				return serve()
			end
			return false
		end,
	})
end

-- Helper functions to record specific actions

function RECORDER.record_start_run(run_info)
	local data = run_info or {}
	-- Stream the pool / shop-roll inputs with the very first action so the
	-- spectator's simulation rolls identical cards without needing a
	-- snapshot. Snapshots stay reserved for switching watched players.
	local sim_inputs = RECORDER.capture_sim_inputs()
	if sim_inputs then
		data.sim_inputs = sim_inputs
	end
	RECORDER.record_action("START_RUN", data)
end

function RECORDER.record_play_hand(card_indices)
	RECORDER.record_action("PLAY_HAND", {
		cards = card_indices or {},
	})
end

function RECORDER.record_discard(card_indices)
	RECORDER.record_action("DISCARD", {
		cards = card_indices or {},
	})
end

function RECORDER.record_select_blind(blind_info)
	local data = {}
	if type(blind_info) == "table" then
		data.key = blind_info.key
		data.name = blind_info.name
		data.blind_row = blind_info.blind_row
	else
		data.blind_row = blind_info
	end
	RECORDER.record_action("SELECT_BLIND", data)
end

function RECORDER.record_skip_blind(blind_info)
	local data = {}
	if type(blind_info) == "table" then
		data.key = blind_info.key
		data.name = blind_info.name
		data.blind_row = blind_info.blind_row
	else
		data.blind_row = blind_info
	end
	RECORDER.record_action("SKIP_BLIND", data)
end

function RECORDER.record_buy_card(area_type, index, card_key, edition)
	RECORDER.record_action("BUY_CARD", {
		area = area_type or "shop_jokers",
		index = index,
		card_key = card_key,
		edition = edition,
	})
end

function RECORDER.record_buy_and_use(area_type, index, card_key, edition)
	RECORDER.record_action("BUY_AND_USE", {
		area = area_type or "shop_jokers",
		index = index,
		card_key = card_key,
		edition = edition,
	})
end

function RECORDER.record_buy_booster(index, card_key)
	RECORDER.record_action("BUY_BOOSTER", {
		index = index,
		card_key = card_key,
	})
end

function RECORDER.record_select_pack_card(index)
	RECORDER.record_action("SELECT_PACK_CARD", {
		index = index,
	})
end

function RECORDER.record_skip_pack()
	RECORDER.record_action("SKIP_PACK", {})
end

function RECORDER.record_reroll_shop()
	RECORDER.record_action("REROLL_SHOP", {})
end

function RECORDER.record_toggle_shop()
	RECORDER.record_action("TOGGLE_SHOP", {})
end

function RECORDER.record_cash_out()
	RECORDER.record_action("CASH_OUT", {})
end

function RECORDER.record_use_card(area_type, index, target_indices, target_area, card_key)
	RECORDER.record_action("USE_CARD", {
		area = area_type,
		index = index,
		card_key = card_key,
		target_indices = target_indices or {},
		target_area = target_area or "hand",
	})
end

function RECORDER.record_sell_card(area_type, index)
	RECORDER.record_action("SELL_CARD", {
		area = area_type,
		index = index,
	})
end

function RECORDER.record_reorder_cards(area_type, order_indices)
	RECORDER.record_action("REORDER_CARDS", {
		area = area_type,
		order = order_indices or {},
	})
end

function RECORDER.record_reroll_boss()
	RECORDER.record_action("REROLL_BOSS", {})
end

function RECORDER.record_sort_hand(mode)
	RECORDER.record_action("SORT_HAND", {
		mode = (mode == "value") and "value" or "suit",
	})
end

return RECORDER
