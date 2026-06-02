-- Calculator V2 state guard.
--
-- Native scoring helpers can touch game state because Balatro's calculation
-- functions were written for the real play path. The guard snapshots the small
-- set of mutable state V2 intentionally exposes, suppresses visible side
-- effects, then restores everything after the preview attempt.

MP = MP or {}
MP.CALCULATOR_V2 = MP.CALCULATOR_V2 or {}

local CALC = MP.CALCULATOR_V2

local function preserve_metatable(source, target)
	local metatable = getmetatable(source)
	if metatable then pcall(setmetatable, target, metatable) end
	return target
end

local function deep_copy(value, seen)
	if type(value) ~= "table" then return value end
	seen = seen or {}
	if seen[value] then return seen[value] end
	local result = {}
	seen[value] = result
	for k, v in pairs(value) do
		if type(v) ~= "function" and type(v) ~= "userdata" and type(v) ~= "thread" then
			result[deep_copy(k, seen)] = deep_copy(v, seen)
		else
			result[k] = v
		end
	end
	return preserve_metatable(value, result)
end

local function restore_table(target, snapshot)
	if type(target) ~= "table" or type(snapshot) ~= "table" then return snapshot end
	for key in pairs(target) do target[key] = nil end
	for key, value in pairs(snapshot) do target[key] = value end
	return preserve_metatable(snapshot, target)
end

local function snapshot_current_hand_state(game)
	local current_round = game and game.current_round
	if type(current_round) ~= "table" or type(current_round.current_hand) ~= "table" then return nil end
	return {
		ref = current_round.current_hand,
		state = deep_copy(current_round.current_hand),
	}
end

local function restore_current_hand_state(game, snapshot)
	if not snapshot or type(game.current_round) ~= "table" or type(snapshot.ref) ~= "table" then return end
	game.current_round.current_hand = snapshot.ref
	restore_table(snapshot.ref, snapshot.state)
end

local function copy_array_refs(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for index, item in ipairs(value) do result[index] = item end
	return result
end

local function copy_key_values(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in pairs(value) do result[key] = item end
	return result
end

local function restore_key_values(target, snapshot)
	if type(target) ~= "table" or type(snapshot) ~= "table" then return snapshot end
	for key in pairs(target) do target[key] = nil end
	for key, value in pairs(snapshot) do target[key] = value end
	return target
end

local function snapshot_table_fields(target, fields, copy_fields)
	if type(target) ~= "table" then return nil end

	local snapshot = {
		target = target,
		fields = fields,
		values = {},
		present = {},
		copy_fields = copy_fields or {},
	}

	for _, field in ipairs(fields) do
		local value = target[field]
		if value ~= nil then
			snapshot.present[field] = true
			snapshot.values[field] = snapshot.copy_fields[field] and deep_copy(value) or value
		end
	end

	return snapshot
end

local function restore_table_fields(snapshot)
	if not snapshot or type(snapshot.target) ~= "table" then return end

	local target = snapshot.target
	for _, field in ipairs(snapshot.fields or {}) do
		if snapshot.present[field] then
			local value = snapshot.values[field]
			if snapshot.copy_fields[field] and type(value) == "table" and type(target[field]) == "table" then
				restore_table(target[field], value)
			else
				target[field] = value
			end
		else
			target[field] = nil
		end
	end
end

local function snapshot_multiplayer_money_state()
	return MP and snapshot_table_fields(MP.GAME, { "real_money", "applying_remote_money" }) or nil
end

local function install_noop_mp_function(name, restore_callbacks)
	if not (MP and type(MP[name]) == "function") then return end

	local original = MP[name]
	restore_callbacks[#restore_callbacks + 1] = function()
		MP[name] = original
	end
	MP[name] = function()
		return true
	end
end

local function snapshot_card(card)
	return {
		config_ref = card.config,
		config = copy_key_values(card.config),
		ability_ref = card.ability,
		ability = deep_copy(card.ability),
		edition_ref = card.edition,
		edition = deep_copy(card.edition),
		base_ref = card.base,
		base = deep_copy(card.base),
		t_ref = card.T,
		t = deep_copy(card.T),
		vt_ref = card.VT,
		vt = deep_copy(card.VT),
		pinch_ref = card.pinch,
		pinch = deep_copy(card.pinch),
		facing = card.facing,
		sprite_facing = card.sprite_facing,
		flipping = card.flipping,
		sell_cost_label = card.sell_cost_label,
		debuff = card.debuff,
		seal = card.seal,
		destroyed = card.destroyed,
		shattered = card.shattered,
		vampired = card.vampired,
		getting_sliced = card.getting_sliced,
		lucky_trigger = deep_copy(card.lucky_trigger),
		highlighted = card.highlighted,
		area = card.area,
		parent = card.parent,
		layered_parallax_ref = card.layered_parallax,
		layered_parallax = deep_copy(card.layered_parallax),
		rank = card.rank,
		sort_id = card.sort_id,
		unique_val = card.unique_val,
		ID = card.ID,
	}
end

local function restore_card(card, snapshot)
	card.config = restore_key_values(snapshot.config_ref, snapshot.config)
	card.ability = restore_table(snapshot.ability_ref, snapshot.ability)
	card.edition = snapshot.edition and restore_table(snapshot.edition_ref or {}, snapshot.edition) or nil
	card.base = restore_table(snapshot.base_ref, snapshot.base)
	card.T = restore_table(snapshot.t_ref, snapshot.t)
	card.VT = restore_table(snapshot.vt_ref, snapshot.vt)
	card.pinch = restore_table(snapshot.pinch_ref, snapshot.pinch)
	card.facing = snapshot.facing
	card.sprite_facing = snapshot.sprite_facing
	card.flipping = snapshot.flipping
	card.sell_cost_label = snapshot.sell_cost_label
	card.debuff = snapshot.debuff
	card.seal = snapshot.seal
	card.destroyed = snapshot.destroyed
	card.shattered = snapshot.shattered
	card.vampired = snapshot.vampired
	card.getting_sliced = snapshot.getting_sliced
	card.lucky_trigger = snapshot.lucky_trigger
	card.highlighted = snapshot.highlighted
	card.area = snapshot.area
	card.parent = snapshot.parent
	card.layered_parallax = snapshot.layered_parallax_ref or snapshot.layered_parallax
	card.rank = snapshot.rank
	card.sort_id = snapshot.sort_id
	card.unique_val = snapshot.unique_val
	card.ID = snapshot.ID
end

local function collect_cards(ctx)
	local seen = {}
	local cards = {}
	local function add(card)
		if card and not seen[card] then
			seen[card] = true
			cards[#cards + 1] = card
		end
	end

	for _, card in ipairs(ctx.full_hand or {}) do add(card) end
	for _, card in ipairs(ctx.base_scoring_hand or {}) do add(card) end
	for _, card in ipairs(ctx.scoring_hand or {}) do add(card) end
	for _, card in ipairs(ctx.held_cards or {}) do add(card) end
	for _, card in ipairs(ctx.jokers or {}) do add(card) end
	for _, card in ipairs(ctx.consumeables or {}) do add(card) end
	return cards
end

local function set_area_cards(area, cards)
	if area then area.cards = cards end
end

local function snapshot_area_cards(...)
	local snapshots = {}
	for _, area in ipairs({ ... }) do
		if area and type(area.cards) == "table" then
			snapshots[#snapshots + 1] = {
				area = area,
				cards = copy_array_refs(area.cards),
			}
		end
	end
	return snapshots
end

local function restore_area_cards(snapshots)
	for _, snapshot in ipairs(snapshots or {}) do
		snapshot.area.cards = copy_array_refs(snapshot.cards)
	end
end

local function install_noop_global(name, replacements)
	local original = _G[name]
	replacements[#replacements + 1] = function() _G[name] = original end
	_G[name] = function() end
end

local function snapshot_controller_state()
	local controller = G and G.CONTROLLER
	if not controller then return nil end

	return {
		interrupt_ref = controller.interrupt,
		interrupt = copy_key_values(controller.interrupt),
		focused_ref = controller.focused,
		focused = copy_key_values(controller.focused),
		dragging_ref = controller.dragging,
		dragging = copy_key_values(controller.dragging),
		hovering_ref = controller.hovering,
		hovering = copy_key_values(controller.hovering),
		released_on_ref = controller.released_on,
		released_on = copy_key_values(controller.released_on),
		cursor_down_ref = controller.cursor_down,
		cursor_down = copy_key_values(controller.cursor_down),
		cursor_up_ref = controller.cursor_up,
		cursor_up = copy_key_values(controller.cursor_up),
		cursor_hover_ref = controller.cursor_hover,
		cursor_hover = copy_key_values(controller.cursor_hover),
		cardarea_context_ref = controller.cardarea_context,
		cardarea_context = copy_key_values(controller.cardarea_context),
		snap_cursor_to = controller.snap_cursor_to,
		locked = controller.locked,
		card_area_focus_reset = copy_key_values(G.card_area_focus_reset),
		boss_throw_hand = G.boss_throw_hand,
	}
end

local function restore_controller_state(snapshot)
	local controller = G and G.CONTROLLER
	if not snapshot or not controller then return end

	controller.interrupt = restore_key_values(snapshot.interrupt_ref, snapshot.interrupt)
	controller.focused = restore_key_values(snapshot.focused_ref, snapshot.focused)
	controller.dragging = restore_key_values(snapshot.dragging_ref, snapshot.dragging)
	controller.hovering = restore_key_values(snapshot.hovering_ref, snapshot.hovering)
	controller.released_on = restore_key_values(snapshot.released_on_ref, snapshot.released_on)
	controller.cursor_down = restore_key_values(snapshot.cursor_down_ref, snapshot.cursor_down)
	controller.cursor_up = restore_key_values(snapshot.cursor_up_ref, snapshot.cursor_up)
	controller.cursor_hover = restore_key_values(snapshot.cursor_hover_ref, snapshot.cursor_hover)
	controller.cardarea_context = restore_key_values(snapshot.cardarea_context_ref, snapshot.cardarea_context)
	controller.snap_cursor_to = snapshot.snap_cursor_to
	controller.locked = snapshot.locked
	G.card_area_focus_reset = snapshot.card_area_focus_reset and copy_key_values(snapshot.card_area_focus_reset) or nil
	G.boss_throw_hand = snapshot.boss_throw_hand
end

local function install_state_only_update_hand_text(replacements)
	local original = _G.update_hand_text
	replacements[#replacements + 1] = function() _G.update_hand_text = original end
	_G.update_hand_text = function(config, vals)
		config = config or {}
		vals = vals or {}
		local current_hand = G and G.GAME and G.GAME.current_round and G.GAME.current_round.current_hand
		if type(current_hand) ~= "table" then return end

		local reset_only_score_param = false
		if SMODS and SMODS.Scoring_Parameters then
			local score_param_count = 0
			local non_score_param_count = 0
			local all_score_params_are_defaults = true
			local score_param_resets_current = false
			for name, value in pairs(vals) do
				local parameter = SMODS.Scoring_Parameters[name]
				if parameter and value then
					score_param_count = score_param_count + 1
					if value ~= parameter.default_value then
						all_score_params_are_defaults = false
					elseif parameter.current ~= parameter.default_value then
						score_param_resets_current = true
					end
				elseif name ~= "StatusText" and value then
					non_score_param_count = non_score_param_count + 1
				end
			end
			reset_only_score_param = score_param_count == 1
				and non_score_param_count == 0
				and vals.StatusText == nil
				and all_score_params_are_defaults
				and score_param_resets_current
				and config.delay == 0
				and not config.immediate

			for name, parameter in pairs(SMODS.Scoring_Parameters) do
				if vals[name] then
					current_hand[name] = vals[name]
					if not reset_only_score_param then parameter.current = vals[name] end
				end
			end
		else
			if vals.chips then current_hand.chips = vals.chips end
			if vals.mult then current_hand.mult = vals.mult end
		end

		if vals.handname then current_hand.handname = vals.handname end
		if vals.chip_total then current_hand.chip_total = vals.chip_total end
	end
end

local function install_noop_action_table(actions, replacements)
	if type(actions) ~= "table" then return end

	local originals = {}
	for key, value in pairs(actions) do
		if type(value) == "function" then
			originals[key] = value
			actions[key] = function() return true end
		end
	end

	replacements[#replacements + 1] = function()
		for key, value in pairs(originals) do actions[key] = value end
	end
end

local function install_state_only_scoring_calculation(replacements)
	if not SMODS then return end

	local original_set_scoring_calculation = SMODS.set_scoring_calculation
	local original_refresh_score_ui_list = SMODS.refresh_score_UI_list
	local original_scoring_ui_func = G and G.FUNCS and G.FUNCS.SMODS_scoring_calculation_function

	replacements[#replacements + 1] = function()
		SMODS.set_scoring_calculation = original_set_scoring_calculation
		SMODS.refresh_score_UI_list = original_refresh_score_ui_list
		if G and G.FUNCS then
			G.FUNCS.SMODS_scoring_calculation_function = original_scoring_ui_func
		end
	end

	SMODS.refresh_score_UI_list = function() end
	if G and G.FUNCS then
		G.FUNCS.SMODS_scoring_calculation_function = function() end
	end

	SMODS.set_scoring_calculation = function(key)
		if not (G and G.GAME and SMODS.Scoring_Calculations and SMODS.Scoring_Calculations[key]) then return end
		G.GAME.current_scoring_calculation_key = key
		if key == "talisman_hyper" then
			G.GAME.hyper_operator = G.GAME.hyper_operator or 2
		end

		local ok, scoring_calculation = pcall(function()
			return SMODS.Scoring_Calculations[key]:new()
		end)
		if ok and scoring_calculation then
			G.GAME.current_scoring_calculation = scoring_calculation
		end
	end
end

local function snapshot_smods_state()
	if not SMODS then return nil end
	local scoring_parameters = {}
	for key, parameter in pairs(SMODS.Scoring_Parameters or {}) do
		scoring_parameters[key] = parameter.current
	end
	return {
		no_resolve = SMODS.no_resolve,
		displayed_hand = SMODS.displayed_hand,
		displaying_scoring = SMODS.displaying_scoring,
		current_evaluated_object = SMODS.current_evaluated_object,
		context_stack = copy_array_refs(SMODS.context_stack),
		last_hand = SMODS.last_hand,
		last_hand_oneshot = SMODS.last_hand_oneshot,
		post_prob = copy_key_values(SMODS.post_prob),
		calculation_controls = copy_key_values(SMODS.Calculation_Controls),
		scoring_parameters = scoring_parameters,
	}
end

local function restore_smods_state(snapshot)
	if not SMODS or not snapshot then return end
	SMODS.no_resolve = snapshot.no_resolve
	SMODS.displayed_hand = snapshot.displayed_hand
	SMODS.displaying_scoring = snapshot.displaying_scoring
	SMODS.current_evaluated_object = snapshot.current_evaluated_object
	SMODS.context_stack = copy_array_refs(snapshot.context_stack)
	SMODS.last_hand = snapshot.last_hand
	SMODS.last_hand_oneshot = snapshot.last_hand_oneshot
	SMODS.post_prob = copy_key_values(snapshot.post_prob)
	SMODS.Calculation_Controls = copy_key_values(snapshot.calculation_controls)
	for key, current in pairs(snapshot.scoring_parameters or {}) do
		if SMODS.Scoring_Parameters and SMODS.Scoring_Parameters[key] then
			SMODS.Scoring_Parameters[key].current = current
		end
	end
end

local function scoring_coroutine_thread(scoring_coroutine)
	if type(scoring_coroutine) == "thread" then return scoring_coroutine, "thread" end
	if type(scoring_coroutine) == "table" and type(scoring_coroutine.coroutine) == "thread" then
		return scoring_coroutine.coroutine, "state_table"
	end
	return nil, "unsupported scoring coroutine shape: " .. type(scoring_coroutine)
end

local function scoring_coroutine_status(scoring_coroutine)
	local thread, shape = scoring_coroutine_thread(scoring_coroutine)
	if not thread then return nil, shape end
	return coroutine.status(thread), nil, shape
end

local function resume_scoring_coroutine(scoring_coroutine)
	local thread, shape = scoring_coroutine_thread(scoring_coroutine)
	if not thread then return nil, shape end

	if shape == "state_table"
		and Talisman
		and Talisman.scoring_coroutine == scoring_coroutine
		and Talisman.coroutine
		and type(Talisman.coroutine.resume) == "function"
	then
		local ok, result = pcall(Talisman.coroutine.resume)
		if ok then return result ~= false, result == false and "scoring coroutine returned false" or nil end
		return nil, result
	end

	local ok, result = coroutine.resume(thread)
	if ok then return true end
	return nil, result
end

local function clear_scoring_coroutine(scoring_coroutine)
	if Talisman
		and Talisman.scoring_coroutine == scoring_coroutine
		and Talisman.coroutine
		and type(Talisman.coroutine.clear_state) == "function"
	then
		local ok = pcall(Talisman.coroutine.clear_state)
		if ok then return end
	end

	if G then G.SCORING_COROUTINE = nil end
	if Talisman and Talisman.scoring_coroutine == scoring_coroutine then
		Talisman.scoring_coroutine = nil
	end
end

local function snapshot_talisman_scoring_state()
	if not G then return nil end
	local state = {
		scoring_coroutine = G.SCORING_COROUTINE,
		last_scoring_yield = G.LAST_SCORING_YIELD,
		card_calc_counts = G.CARD_CALC_COUNTS,
		current_scoring_card = G.CURRENT_SCORING_CARD,
		scoring_text = G.SCORING_TEXT,
		scoring_text_values = G.scoring_text,
		current_calc_time = G.CURRENT_CALC_TIME,
	}
	if Talisman then
		state.talisman = {
			scoring_state = Talisman.scoring_state,
			calculating_joker = Talisman.calculating_joker,
			calculating_score = Talisman.calculating_score,
			calculating_card = Talisman.calculating_card,
			dollar_update = Talisman.dollar_update,
			scoring_coroutine = Talisman.scoring_coroutine,
			temp_dollar_update = Talisman.temp_dollar_update,
			temp_uht_config = Talisman.temp_uht_config,
			temp_uht_vals = Talisman.temp_uht_vals,
		}
		if Talisman.coroutine then
			state.talisman.coroutine_aborted = Talisman.coroutine.aborted
		end
		if Talisman.current_calc then
			state.talisman.current_calc = {
				score = Talisman.current_calc.score,
				joker = Talisman.current_calc.joker,
				card = Talisman.current_calc.card,
			}
		end
	end
	return state
end

local function restore_talisman_scoring_state(snapshot)
	if not (snapshot and G) then return end
	G.SCORING_COROUTINE = snapshot.scoring_coroutine
	G.LAST_SCORING_YIELD = snapshot.last_scoring_yield
	G.CARD_CALC_COUNTS = snapshot.card_calc_counts
	G.CURRENT_SCORING_CARD = snapshot.current_scoring_card
	G.SCORING_TEXT = snapshot.scoring_text
	G.scoring_text = snapshot.scoring_text_values
	G.CURRENT_CALC_TIME = snapshot.current_calc_time
	if Talisman and snapshot.talisman then
		Talisman.scoring_state = snapshot.talisman.scoring_state
		Talisman.calculating_joker = snapshot.talisman.calculating_joker
		Talisman.calculating_score = snapshot.talisman.calculating_score
		Talisman.calculating_card = snapshot.talisman.calculating_card
		Talisman.dollar_update = snapshot.talisman.dollar_update
		Talisman.scoring_coroutine = snapshot.talisman.scoring_coroutine
		Talisman.temp_dollar_update = snapshot.talisman.temp_dollar_update
		Talisman.temp_uht_config = snapshot.talisman.temp_uht_config
		Talisman.temp_uht_vals = snapshot.talisman.temp_uht_vals
		if Talisman.coroutine then
			Talisman.coroutine.aborted = snapshot.talisman.coroutine_aborted
		end
		if Talisman.current_calc and snapshot.talisman.current_calc then
			Talisman.current_calc.score = snapshot.talisman.current_calc.score
			Talisman.current_calc.joker = snapshot.talisman.current_calc.joker
			Talisman.current_calc.card = snapshot.talisman.current_calc.card
		end
	end
end

function CALC.finish_dry_scoring_coroutine(limit)
	local scoring_coroutine = G and G.SCORING_COROUTINE
	if not scoring_coroutine then
		return true
	end
	if type(coroutine) ~= "table" or type(coroutine.status) ~= "function" then
		return true
	end
	local status, status_err = scoring_coroutine_status(scoring_coroutine)
	if not status then
		return nil, status_err
	end
	if status == "dead" then
		clear_scoring_coroutine(scoring_coroutine)
		return true
	end

	limit = limit or 10000
	local resumes = 0
	while G.SCORING_COROUTINE do
		status, status_err = scoring_coroutine_status(G.SCORING_COROUTINE)
		if not status then
			return nil, status_err
		end
		if status == "dead" then break end

		resumes = resumes + 1
		if resumes > limit then
			return nil, "scoring coroutine did not finish"
		end

		local ok, err = resume_scoring_coroutine(G.SCORING_COROUTINE)
		if not ok then
			return nil, err
		end
	end

	clear_scoring_coroutine(scoring_coroutine)
	return true
end

local function state_guard_auditor()
	if type(CALC.audit_state_guard_mutations) == "function" then return CALC.audit_state_guard_mutations end
	return nil
end

function CALC.with_state_guard(ctx, fn)
	ctx = ctx or {}
	local cards = collect_cards(ctx)
	local card_snapshots = {}
	for _, card in ipairs(cards) do card_snapshots[card] = snapshot_card(card) end

	local hand_cards = G.hand and G.hand.cards or nil
	local play_cards = G.play and G.play.cards or nil
	local area_snapshots = snapshot_area_cards(
		G.hand,
		G.play,
		G.jokers,
		G.consumeables,
		G.deck,
		G.discard,
		G.shop_jokers,
		G.shop_booster,
		G.shop_vouchers,
		G.pack_cards
	)
	local highlighted = G.hand and G.hand.highlighted or nil
	local game = G.GAME or {}
	local hand_state = deep_copy(game.hands)
	local current_round_state = deep_copy(game.current_round)
	local current_hand_state = snapshot_current_hand_state(game)
	local controller_state = snapshot_controller_state()
	local blind_fields = game.blind and {
		triggered = game.blind.triggered,
		prepped = game.blind.prepped,
		block_play = game.blind.block_play,
		chips_ref = game.blind.chips,
		chips = deep_copy(game.blind.chips),
		disabled = game.blind.disabled,
	} or nil
	local g_fields = {
		STATE = G.STATE,
		STATE_COMPLETE = G.STATE_COMPLETE,
		reset_to_none = G.reset_to_none,
		latest_uht = G.latest_uht,
	}
	local game_fields = snapshot_table_fields(game, {
		"chips",
		"dollars",
		"dollar_buffer",
		"joker_buffer",
		"consumeable_buffer",
		"STOP_USE",
		"last_hand_played",
		"first_used_hand_level",
		"cards_played",
		"pseudorandom",
		"probabilities",
		"round_scores",
		"cry_double_scale",
		"sus_cards",
		"last_hand_played_cards",
		"cry_asc_played",
		"cry_exploit_override",
		"LAST_CALCS",
		"LAST_CALC_TIME",
	}, {
		cards_played = true,
		pseudorandom = true,
		probabilities = true,
		round_scores = true,
		cry_double_scale = true,
		sus_cards = true,
		last_hand_played_cards = true,
	})
	local mp_money_state = snapshot_multiplayer_money_state()
	local current_scoring_calculation = game.current_scoring_calculation
	local current_scoring_calculation_key = game.current_scoring_calculation_key
	local hyper_operator = game.hyper_operator
	local global_fields = {
		mult = _G.mult,
		hand_chips = _G.hand_chips,
		text = _G.text,
		disp_text = _G.disp_text,
		poker_hands = _G.poker_hands,
		scoring_hand = _G.scoring_hand,
		non_loc_disp_text = _G.non_loc_disp_text,
		percent = _G.percent,
		percent_delta = _G.percent_delta,
		tal_aborted = _G.tal_aborted,
	}
	local score_display_queue = G.SCORE_DISPLAY_QUEUE and deep_copy(G.SCORE_DISPLAY_QUEUE) or nil
	local smods_state = snapshot_smods_state()
	local talisman_scoring_state = snapshot_talisman_scoring_state()

	local restore_callbacks = {}
	local previous_dry_run_active = CALC.dry_run_active
	CALC.dry_run_active = true
	restore_callbacks[#restore_callbacks + 1] = function()
		CALC.dry_run_active = previous_dry_run_active
	end

	install_noop_global("delay", restore_callbacks)
	install_noop_global("stop_use", restore_callbacks)
	install_state_only_update_hand_text(restore_callbacks)
	install_noop_global("card_eval_status_text", restore_callbacks)
	install_noop_global("juice_card", restore_callbacks)
	install_noop_global("highlight_card", restore_callbacks)
	install_noop_global("play_area_status_text", restore_callbacks)
	install_noop_global("check_for_unlock", restore_callbacks)
	install_noop_global("check_and_set_high_score", restore_callbacks)
	install_noop_global("attention_text", restore_callbacks)
	install_noop_global("play_sound", restore_callbacks)
	install_noop_global("ease_dollars", restore_callbacks)
	install_noop_global("ease_hands_played", restore_callbacks)
	install_noop_global("ease_discard", restore_callbacks)
	install_noop_global("inc_career_stat", restore_callbacks)
	install_noop_global("set_hand_usage", restore_callbacks)
	if type(CALC.install_dry_runtime) == "function" then
		CALC.install_dry_runtime(restore_callbacks)
	end
	install_noop_mp_function("sync_local_money_state", restore_callbacks)
	install_noop_action_table(MP and MP.ACTIONS, restore_callbacks)
	install_state_only_scoring_calculation(restore_callbacks)

	local dry_full_hand = copy_array_refs(ctx.full_hand or {})
	local dry_held_cards = copy_array_refs(ctx.held_cards or {})

	set_area_cards(G.play, dry_full_hand)
	set_area_cards(G.hand, dry_held_cards)
	if G.hand then G.hand.highlighted = {} end
	for _, card in ipairs(ctx.full_hand or {}) do card.area = G.play end
	for _, card in ipairs(ctx.held_cards or {}) do card.area = G.hand end

	local ok, result, reason = pcall(fn, ctx)
	local auditor = state_guard_auditor()
	if auditor then
		pcall(auditor, {
			ctx = ctx,
			ok = ok,
			result = result,
			reason = reason,
			cards = cards,
			card_snapshots = card_snapshots,
			areas = area_snapshots,
			highlighted = highlighted,
			game = game,
			game_fields = game_fields,
			mp_money_state = mp_money_state,
			hand_state = hand_state,
			current_round_state = current_round_state,
			current_hand_state = current_hand_state,
			controller_state = controller_state,
			blind_fields = blind_fields,
			g_fields = g_fields,
			global_fields = global_fields,
			score_display_queue = score_display_queue,
			smods_state = smods_state,
			talisman_scoring_state = talisman_scoring_state,
			current_scoring_calculation = current_scoring_calculation,
			current_scoring_calculation_key = current_scoring_calculation_key,
			hyper_operator = hyper_operator,
		})
	end

	for i = #restore_callbacks, 1, -1 do restore_callbacks[i]() end
	set_area_cards(G.hand, hand_cards)
	if G.hand then G.hand.highlighted = highlighted end
	set_area_cards(G.play, play_cards)
	restore_area_cards(area_snapshots)

	for _, card in ipairs(cards) do restore_card(card, card_snapshots[card]) end
	if game.hands and hand_state then restore_table(game.hands, hand_state) end
	if game.current_round and current_round_state then
		restore_table(game.current_round, current_round_state)
		restore_current_hand_state(game, current_hand_state)
	end
	if game.blind and blind_fields then
		game.blind.triggered = blind_fields.triggered
		game.blind.prepped = blind_fields.prepped
		game.blind.block_play = blind_fields.block_play
		if type(blind_fields.chips_ref) == "table" and type(blind_fields.chips) == "table" then
			game.blind.chips = restore_table(blind_fields.chips_ref, blind_fields.chips)
		else
			game.blind.chips = blind_fields.chips
		end
		game.blind.disabled = blind_fields.disabled
	end
	restore_table_fields(game_fields)
	restore_table_fields(mp_money_state)
	game.current_scoring_calculation = current_scoring_calculation
	game.current_scoring_calculation_key = current_scoring_calculation_key
	game.hyper_operator = hyper_operator
	_G.mult = global_fields.mult
	_G.hand_chips = global_fields.hand_chips
	_G.text = global_fields.text
	_G.disp_text = global_fields.disp_text
	_G.poker_hands = global_fields.poker_hands
	_G.scoring_hand = global_fields.scoring_hand
	_G.non_loc_disp_text = global_fields.non_loc_disp_text
	_G.percent = global_fields.percent
	_G.percent_delta = global_fields.percent_delta
	_G.tal_aborted = global_fields.tal_aborted
	for field, value in pairs(g_fields) do G[field] = value end
	if score_display_queue and type(G.SCORE_DISPLAY_QUEUE) == "table" then
		restore_table(G.SCORE_DISPLAY_QUEUE, score_display_queue)
	else
		G.SCORE_DISPLAY_QUEUE = score_display_queue
	end
	restore_controller_state(controller_state)
	restore_smods_state(smods_state)
	restore_talisman_scoring_state(talisman_scoring_state)

	if not ok then return nil, result end
	return result, reason
end
