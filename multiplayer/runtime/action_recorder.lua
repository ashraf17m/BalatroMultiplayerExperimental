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
	RECORDER.eval_context = nil
end

function RECORDER.stop()
	RECORDER.is_recording = false
	RECORDER.eval_context = nil
end

-- evaluate_round consumes Investment (Tag:yep removes it) and Blind:defeat
-- eventually set_blind(nil). A snapshot taken on the cash-out screen would
-- otherwise miss the tag row and the "score at least / $reward" row.
function RECORDER.capture_eval_context()
	if not (G and G.GAME) then
		return
	end
	if MP.SPECTATOR and MP.SPECTATOR.is_spectating then
		return
	end
	local tags = {}
	if G.GAME.tags then
		for _, tag in ipairs(G.GAME.tags) do
			if tag and tag.key then
				tags[#tags + 1] = { key = tag.key, triggered = not not tag.triggered }
			end
		end
	end
	local last = G.GAME.last_blind or {}
	local blind = G.GAME.blind
	local blind_chips = blind and json_num(blind.chips) or nil
	local chip_text = blind and blind.chip_text or nil
	local is_pvp = (blind and (blind.pvp or (blind.config and blind.config.blind and blind.config.blind.key == "bl_mp_nemesis") or blind.name == "bl_mp_nemesis"))
		or (MP.is_pvp_boss and MP.is_pvp_boss())
		or (MP.is_pvp and MP.is_pvp())
		or (MP.GAME and (MP.GAME.end_pvp or MP.GAME.pvp))
	if is_pvp and (not chip_text or chip_text == "0" or chip_text == "") and MP.UI and MP.UI.get_pvp_score_to_beat then
		local pvp_int, pvp_text = MP.UI.get_pvp_score_to_beat()
		if pvp_text and pvp_text ~= "" and pvp_text ~= "0" then
			chip_text = pvp_text
			if (not blind_chips or blind_chips == 0) and pvp_int and MP.INSANE_INT then
				blind_chips = MP.INSANE_INT.to_safe_number(pvp_int)
			elseif (not blind_chips or blind_chips == 0) and pvp_text then
				local num = tonumber((string.gsub(tostring(pvp_text), ",", "")))
				if num then blind_chips = num end
			end
		end
	end
	RECORDER.eval_context = {
		round = json_num(G.GAME.round),
		dollars = json_num(G.GAME.dollars),
		tags = tags,
		last_blind_boss = not not last.boss,
		last_blind_name = last.name,
		blind_dollars = blind and json_num(blind.dollars) or nil,
		blind_chips = blind_chips,
		chip_text = chip_text,
	}
end

function RECORDER.clear_eval_context()
	RECORDER.eval_context = nil
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
	inputs.first_shop_buffoon = not not (G.GAME and G.GAME.first_shop_buffoon)
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
					sort_id = card.sort_id,
				}
			end
		end
	end

	local phantoms = {}
	if MP.shared and MP.shared.cards then
		for _, card in ipairs(MP.shared.cards) do
			if card and card.edition and card.edition.type == "mp_phantom" then
				local center_key = (card.config and card.config.center and card.config.center.key)
					or (card.config and card.config.center_key)
				if center_key then
					phantoms[#phantoms + 1] = {
						key = center_key,
						playerId = card.mp_phantom_player_id,
					}
				end
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
					sort_id = card.sort_id,
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
				sort_id = card.sort_id,
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
					sort_id = card.sort_id,
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
					sort_id = card.sort_id,
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
					sort_id = card.sort_id,
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
				sort_id = card.sort_id,
			}
		end
	end

	local opened_booster = SMODS and SMODS.OPENED_BOOSTER or nil
	local opened_booster_key = nil
	local opened_pack_extra = nil
	if opened_booster then
		opened_booster_key = (opened_booster.config and opened_booster.config.center and opened_booster.config.center.key)
			or (opened_booster.config and opened_booster.config.center_key)
			or opened_booster.key
		if opened_booster.ability then
			opened_pack_extra = tonumber(opened_booster.ability.extra)
		end
	end
	local pack_size = tonumber(G.GAME.pack_size)
	if not pack_size or pack_size < 1 then
		pack_size = opened_pack_extra
	end
	if not pack_size or pack_size < 1 then
		pack_size = #pack_cards
	end
	-- SMODS.OPENED_BOOSTER survives after skip_booster. Sending it on a
	-- PvP/shop snapshot makes the spectator rebuild the last pack type.
	local pack_open = G.STATES and (
		G.STATE == G.STATES.TAROT_PACK
		or G.STATE == G.STATES.SPECTRAL_PACK
		or G.STATE == G.STATES.STANDARD_PACK
		or G.STATE == G.STATES.BUFFOON_PACK
		or G.STATE == G.STATES.PLANET_PACK
		or G.STATE == G.STATES.SMODS_BOOSTER_OPENED
	)
	if not pack_open then
		opened_booster_key = nil
		pack_cards = {}
		pack_size = 0
	end

	local resets = G.GAME.round_resets or {}
	local hands = {}
	if G.GAME and G.GAME.hands then
		for hand_name, hand_data in pairs(G.GAME.hands) do
			hands[hand_name] = {
				level = tonumber(hand_data.level) or 1,
				order = tonumber(hand_data.order) or 1,
				played = tonumber(hand_data.played) or 0,
				played_this_round = tonumber(hand_data.played_this_round) or 0,
				chips = json_num(hand_data.chips),
				mult = json_num(hand_data.mult),
				s_chips = json_num(hand_data.s_chips),
				s_mult = json_num(hand_data.s_mult),
				l_chips = json_num(hand_data.l_chips),
				l_mult = json_num(hand_data.l_mult),
				visible = not not hand_data.visible,
			}
		end
	end

	local board_state = {
		step = RECORDER.step_index,
		state = G.STATE,
		dollars = json_num(G.GAME.dollars),
		chips = json_num(G.GAME.chips),
		-- Vanilla HUD uses ante_disp; blind chip amounts use blind_ante
		-- (see create_UIBox_blind_choice / get_blind_amount). tonumber()
		-- drops Talisman bignums, so json_num is required.
		ante = (resets.ante ~= nil) and json_num(resets.ante) or 1,
		blind_ante = ((resets.blind_ante or resets.ante) ~= nil) and json_num(resets.blind_ante or resets.ante) or 1,
		ante_disp = resets.ante_disp and tostring(resets.ante_disp) or nil,
		ante_scaling = json_num(G.GAME.starting_params and G.GAME.starting_params.ante_scaling),
		round = json_num(G.GAME.round),
		hands = hands,
		base_hands = tonumber(resets.hands) or 4,
		base_discards = tonumber(resets.discards) or 3,
		consumeable_slots = (G.consumeables and G.consumeables.config and G.consumeables.config.card_limit) or 2,
		probabilities_normal = (G.GAME and G.GAME.probabilities and tonumber(G.GAME.probabilities.normal)) or 1,
		discount_percent = (G.GAME and tonumber(G.GAME.discount_percent)) or 0,
		interest_cap = (G.GAME and tonumber(G.GAME.interest_cap)) or 25,
		last_tarot_planet = (G.GAME and G.GAME.last_tarot_planet) or nil,
		hands_left = tonumber(G.GAME.current_round and G.GAME.current_round.hands_left or 4),
		hands_played = tonumber(G.GAME.current_round and G.GAME.current_round.hands_played or 0),
		discards_left = tonumber(G.GAME.current_round and G.GAME.current_round.discards_left or 4),
		hands_sub = tonumber(G.GAME.current_round and G.GAME.current_round.hands_sub or 0),
		discards_sub = tonumber(G.GAME.current_round and G.GAME.current_round.discards_sub or 0),
		jokers = jokers,
		phantoms = phantoms,
		consumeables = consumeables,
		hand = hand,
		shop_cards = shop_cards,
		pack_cards = pack_cards,
		pack_choices = tonumber(G.GAME.pack_choices or 1),
		pack_size = pack_size,
		opened_booster_key = opened_booster_key,
		pack_interrupt = G.GAME.PACK_INTERRUPT
			or (G.shop and G.STATES.SHOP)
			or (G.blind_select and G.STATES.BLIND_SELECT),
		blind = blind,
		last_blind = G.GAME.last_blind and {
			boss = not not G.GAME.last_blind.boss,
			name = G.GAME.last_blind.name,
		} or nil,
		eval_pre = RECORDER.eval_context,
		end_pvp = not not (MP.GAME and MP.GAME.end_pvp),
		blind_on_deck = G.GAME.blind_on_deck,
		blind_choices = G.GAME.round_resets and G.GAME.round_resets.blind_choices,
		blind_tags = G.GAME.round_resets and G.GAME.round_resets.blind_tags,
		pvp_blind_choices = G.GAME.round_resets and G.GAME.round_resets.pvp_blind_choices,
		blind_states = G.GAME.round_resets and G.GAME.round_resets.blind_states,
		location = MP.GAME and MP.GAME.location,
		lives = tonumber(MP.GAME and MP.GAME.lives),
		timer = tonumber(MP.GAME and MP.GAME.timer),
		nemesis_timer_started = not not (MP.GAME and MP.GAME.nemesis_timer_started),
		comeback_bonus = tonumber(MP.GAME and MP.GAME.comeback_bonus) or 0,
		comeback_bonus_given = not not (MP.GAME and MP.GAME.comeback_bonus_given),
		comeback_eval_pending = not not (
			(MP.GAME and MP.GAME.comeback_eval_pending)
			or (MP.GAME and MP.GAME.comeback_bonus_given == false and (tonumber(MP.GAME.comeback_bonus) or 0) > 0)
		),
		round_failed = not not (MP.GAME and MP.GAME.round_failed),
		deck_size = G.deck and G.deck.cards and #G.deck.cards or 52,
		reroll_cost = tonumber(G.GAME.reroll_cost or 0),
		first_shop_buffoon = not not (G.GAME and G.GAME.first_shop_buffoon),
		sort_id = G.sort_id and tonumber(G.sort_id) or nil,
	}
	local enemy = MP.GAME and MP.GAME.enemy
	if enemy then
		board_state.pvp_enemy = {
			score_text = tostring(enemy.score_text or "0"),
			hands = tonumber(enemy.hands),
			username = enemy.username,
		}
	end

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
					sort_id = card.sort_id,
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
					sort_id = card.sort_id,
				}
			end
		end
		board_state.discard = discard

		local tags = {}
		if G.GAME.tags then
			for _, tag in ipairs(G.GAME.tags) do
				if tag and tag.key then
					tags[#tags + 1] = { key = tag.key, triggered = not not tag.triggered }
				end
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
		local hand_cfg = G.hand and G.hand.config
		local hand_limits = hand_cfg and hand_cfg.card_limits
		board_state.hand_size = (hand_cfg and hand_cfg.card_limit) or nil
		board_state.hand_size_base = hand_limits and tonumber(hand_limits.base) or nil
		board_state.hand_size_mod = hand_limits and tonumber(hand_limits.mod) or nil
		board_state.temp_handsize = G.GAME.round_resets and tonumber(G.GAME.round_resets.temp_handsize) or nil
		if G.GAME.current_round then
			board_state.round_special_cards = {
				ancient_card = G.GAME.current_round.ancient_card,
				idol_card = G.GAME.current_round.idol_card,
				mail_card = G.GAME.current_round.mail_card,
				castle_card = G.GAME.current_round.castle_card,
			}
		end
		if G.GAME.orbital_choices then
			board_state.orbital_choices = G.GAME.orbital_choices
		end
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

	if MP.TESTING and MP.TESTING.log_spectator then
		local detail = string.format("#%d", step)
		if action_type == "DISCARD" or action_type == "PLAY_HAND" then
			local c_idx = {}
			if type(payload) == "table" and type(payload.cards) == "table" then
				for _, ci in ipairs(payload.cards) do c_idx[#c_idx + 1] = tostring(ci) end
			end
			detail = string.format("#%d [%s] hand=%d deck=%d", step, table.concat(c_idx, ","),
				(G and G.hand and G.hand.cards and #G.hand.cards) or 0,
				(G and G.deck and G.deck.cards and #G.deck.cards) or 0)
		elseif action_type == "SELECT_BLIND" or action_type == "SKIP_BLIND" then
			detail = string.format("#%d blind=%s", step, tostring(payload and (payload.key or payload.blind_row) or ""))
		end
		MP.TESTING.log_spectator("REC", action_type, detail)
	end
end

function RECORDER.handle_spectator_request_snapshot(payload)
	if not payload or not payload.spectatorPlayerId then
		return
	end
	if not RECORDER.is_recording or (MP.SPECTATOR and MP.SPECTATOR.is_spectating) then
		return
	end

	local spec_short = tostring(payload.spectatorPlayerId):sub(1, 8)
	if MP.TESTING and MP.TESTING.log_spectator then
		MP.TESTING.log_spectator("SNAP", "req", "from=" .. spec_short)
	end

	local function serve()
		local board_state = RECORDER.capture_live_board_state(true)
		if not board_state then
			return true
		end

		local ok, json_data = pcall(json.encode, board_state)
		if ok and json_data and MP.ACTIONS and MP.ACTIONS.spectator_provide_snapshot then
			local self_id = (G and G.MP_ID or "")
			MP.ACTIONS.spectator_provide_snapshot(payload.spectatorPlayerId, self_id, json_data)
			if MP.TESTING and MP.TESTING.log_spectator then
				local h_count = (board_state.hand and #board_state.hand) or 0
				local d_count = (board_state.deck and #board_state.deck) or 0
				local disc_left = board_state.discards_left or "?"
				MP.TESTING.log_spectator("SNAP", "serve", string.format("to=%s step=%s st=%s hand=%d deck=%d disc=%s",
					spec_short, tostring(board_state.step or ""), tostring(board_state.state or ""),
					h_count, d_count, tostring(disc_left)))
			end
		end
		return true
	end

	local function is_open_pack_state()
		if not (G and G.STATES) then
			return false
		end
		local s = G.STATE
		return s == G.STATES.TAROT_PACK
			or s == G.STATES.PLANET_PACK
			or s == G.STATES.SPECTRAL_PACK
			or s == G.STATES.STANDARD_PACK
			or s == G.STATES.BUFFOON_PACK
			or s == G.STATES.SMODS_BOOSTER_OPENED
	end

	local function pack_cards_ready()
		local n = G.pack_cards and G.pack_cards.cards and #G.pack_cards.cards or 0
		if n <= 0 then
			return false
		end
		local want = tonumber(G.GAME and G.GAME.pack_size)
		local opened = SMODS and SMODS.OPENED_BOOSTER
		if opened and opened.ability and opened.ability.extra then
			want = want or tonumber(opened.ability.extra)
		end
		if want and want > 0 then
			return n >= want
		end
		return true
	end

	local function count_e_manager_events()
		local queues = G and G.E_MANAGER and G.E_MANAGER.queues
		if type(queues) ~= "table" then
			return 0
		end
		local total = 0
		for k, q in pairs(queues) do
			if k ~= "ambient" and k ~= "particles" and type(q) == "table" then
				total = total + #q
			end
		end
		return total
	end

	-- Shop: wait until the offer row exists (same as before).
	-- Pack / skip-into-pack: Card:open sets STATE immediately, but cards
	-- are only emplaced after pack_cards.VT.y is on-screen. Serving before
	-- that captures an empty pack; the spectator then rebuilds chrome with
	-- no cards (the "blank skip pack").
	local function snapshot_board_ready(attempts)
		if not G then
			return true
		end
		-- Mid-scoring / card drawing: cards are in G.play rather than G.hand,
		-- and scoring animation events are in progress. Serving here would capture
		-- an incomplete hand and trap the spectator in HAND_PLAYED with no events.
		if G.STATES and (G.STATE == G.STATES.HAND_PLAYED or G.STATE == G.STATES.DRAW_TO_HAND) then
			return false
		end
		if SMODS and SMODS.cards_to_draw and SMODS.cards_to_draw > 0 then
			return false
		end
		if G.play and G.play.cards and #G.play.cards > 0 then
			return false
		end
		if is_open_pack_state() then
			return pack_cards_ready()
		end
		if G.STATES and G.STATE == G.STATES.ROUND_EVAL then
			return RECORDER.eval_context ~= nil
		end
		if G.CONTROLLER and G.CONTROLLER.locks and G.CONTROLLER.locks.skip_blind then
			return false
		end
		if G.STATE == G.STATES.SHOP then
			if attempts and attempts >= 4 then
				return true
			end
			if G.shop_jokers and G.shop_jokers.cards and #G.shop_jokers.cards > 0 then
				return true
			end
			return count_e_manager_events() == 0
		end
		return true
	end

	if snapshot_board_ready(0) then
		return serve()
	end

	if MP.TESTING and MP.TESTING.log_spectator then
		MP.TESTING.log_spectator("SNAP", "hold", string.format("st=%s hand=%d play=%d",
			tostring(G and G.STATE or ""),
			(G and G.hand and G.hand.cards and #G.hand.cards) or 0,
			(G and G.play and G.play.cards and #G.play.cards) or 0))
	end

	local balatro = MP.PLATFORM and MP.PLATFORM.BALATRO or nil
	if not (balatro and balatro.queue_event) then
		return serve()
	end

	local attempts = 0
	local start_time = os.clock()
	balatro.queue_event({
		trigger = "after",
		delay = 0.05,
		func = function()
			attempts = attempts + 1
			if snapshot_board_ready(attempts) then
				return serve()
			end
			if attempts % 30 == 0 and MP.TESTING and MP.TESTING.log_spectator then
				MP.TESTING.log_spectator("SNAP", "wait", string.format("try=%d st=%s hand=%d",
					attempts, tostring(G and G.STATE or ""),
					(G and G.hand and G.hand.cards and #G.hand.cards) or 0))
			end
			-- Never serve an incomplete board mid-scoring, mid-draw, or mid-pack.
			-- Wait until scoring/drawing finishes and snapshot_board_ready() is true.
			-- If elapsed real time exceeds 15 seconds (unrecoverable engine hang), abort cleanly without serving.
			local elapsed = os.clock() - start_time
			if elapsed > 15 then
				if MP.TESTING and MP.TESTING.log_spectator then
					MP.TESTING.log_spectator("SNAP", "timeout_abort", string.format("st=%s elapsed=%.1fs",
						tostring(G and G.STATE or ""), elapsed))
				end
				return true
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
	RECORDER.eval_context = nil
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

function RECORDER.record_buy_and_use(area_type, index, card_key, edition, targets)
	targets = targets or {}
	RECORDER.record_action("BUY_AND_USE", {
		area = area_type or "shop_jokers",
		index = index,
		card_key = card_key,
		edition = edition,
		target_area = targets.target_area or "hand",
		target_indices = targets.target_indices or {},
		target_ids = targets.target_ids or {},
	})
end

function RECORDER.record_buy_booster(index, card_key)
	RECORDER.record_action("BUY_BOOSTER", {
		index = index,
		card_key = card_key,
	})
end

function RECORDER.record_select_pack_card(index, card_key, targets)
	targets = targets or {}
	RECORDER.record_action("SELECT_PACK_CARD", {
		index = index,
		card_key = card_key,
		target_area = targets.target_area or "hand",
		target_indices = targets.target_indices or {},
		target_ids = targets.target_ids or {},
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

function RECORDER.record_end_pvp(lost, pvp_timer_lost)
	RECORDER.record_action("END_PVP", {
		lost = not not lost,
		pvp_timer_lost = not not pvp_timer_lost,
		lives = tonumber(MP.GAME and MP.GAME.lives),
	})
end

function RECORDER.record_cash_out()
	RECORDER.record_action("CASH_OUT", {})
	RECORDER.eval_context = nil
end

function RECORDER.record_use_card(area_type, index, target_indices, target_area, card_key, target_ids)
	RECORDER.record_action("USE_CARD", {
		area = area_type,
		index = index,
		card_key = card_key,
		target_indices = target_indices or {},
		target_area = target_area or "hand",
		target_ids = target_ids or {},
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
