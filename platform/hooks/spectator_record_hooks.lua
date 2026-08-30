MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.HOOKS = MP.PLATFORM.HOOKS or {}

local function get_hand_indices(highlighted_cards)
	local indices = {}
	if not (G and G.hand and G.hand.cards and highlighted_cards) then
		return indices
	end

	for _, card in ipairs(highlighted_cards) do
		for idx, hand_card in ipairs(G.hand.cards) do
			if card == hand_card then
				indices[#indices + 1] = idx
				break
			end
		end
	end
	return indices
end

-- Vanilla player discard clicks the discard button, so the first argument
-- is a UI event. Effects (The Hook, and anything else that reuses this
-- func) call G.FUNCS.discard_cards_from_highlighted(nil, ...). Those must
-- not be recorded as DISCARD — the spectator sim will run the same effect.
local function is_player_discard_event(ctx)
	local e = ctx and ctx.self
	if type(e) ~= "table" then
		return false
	end
	if e.config and e.config.button == "discard_cards_from_highlighted" then
		return true
	end
	-- Pressed discard button still has a UIBox even if config.button was
	-- cleared for one_press.
	return e.UIBox ~= nil or (e.config and e.config.id ~= nil)
end

local function get_card_area_name(area)
	if not G then return "unknown" end
	if area == G.jokers then return "jokers" end
	if area == G.consumeables then return "consumeables" end
	if area == G.hand then return "hand" end
	if area == G.deck then return "deck" end
	if area == G.discard then return "discard" end
	if area == G.shop_jokers then return "shop_jokers" end
	if area == G.shop_booster then return "shop_booster" end
	if area == G.shop_vouchers then return "shop_vouchers" end
	if area == G.pack_cards then return "pack_cards" end
	return "unknown"
end

local function get_card_index_in_area(card)
	if not (card and card.area and card.area.cards) then
		return 1
	end
	for idx, c in ipairs(card.area.cards) do
		if c == card then
			return idx
		end
	end
	return 1
end

local function get_highlighted_area_indices(highlighted)
	local indices = {}
	if not highlighted then
		return indices
	end
	for _, card in ipairs(highlighted) do
		local idx = get_card_index_in_area(card)
		if idx then
			indices[#indices + 1] = idx
		end
	end
	return indices
end

local function get_blind_row_from_event(e)
	if MP.BLIND_CHOICE_INTERNAL and MP.BLIND_CHOICE_INTERNAL.get_blind_choice_row_type then
		local row = MP.BLIND_CHOICE_INTERNAL.get_blind_choice_row_type(e)
		if row == "Small" or row == "Big" or row == "Boss" then
			return row
		end
	end

	local blind = e and e.config and e.config.ref_table
	if not blind then return "Small" end
	if blind.boss or (blind.key and blind.key ~= "bl_small" and blind.key ~= "bl_big") then
		return "Boss"
	end
	local name = string.lower(tostring(blind.name or blind.label or blind.key or blind.blind or ""))
	if string.find(name, "big") then
		return "Big"
	elseif string.find(name, "boss") then
		return "Boss"
	else
		return "Small"
	end
end

local function get_current_selected_blind_row()
	if G and G.GAME and G.GAME.blind then
		local b = G.GAME.blind
		if b.boss or (b.key and b.key ~= "bl_small" and b.key ~= "bl_big") then
			return "Boss"
		end
		if b.key == "bl_big" or b.name == "Big Blind" then
			return "Big"
		end
		if b.key == "bl_small" or b.name == "Small Blind" then
			return "Small"
		end
	end

	if G and G.GAME and G.GAME.blind_on_deck then
		return G.GAME.blind_on_deck
	end

	return "Small"
end

local function is_spectating()
	return not not (MP.SPECTATOR and MP.SPECTATOR.is_spectating)
end

-- Vanilla reorders hand/jokers by sorting on T.x inside CardArea:align_cards
-- every frame while a card is dragged. Stream one permutation per gesture
-- (drop, or immediately before an index-based action if they have not
-- released yet). Spectator applies that permutation so PLAY/USE/SELL indices match.
local reorder_origin = {}

local function is_reorder_tracked_area(area)
	return not not (G and area and (area == G.hand or area == G.jokers))
end

local function copy_area_cards(area)
	local copy = {}
	if not (area and area.cards) then
		return copy
	end
	for i, card in ipairs(area.cards) do
		copy[i] = card
	end
	return copy
end

local function permutation_from_origin(origin, cards)
	if not (origin and cards) or #origin ~= #cards or #cards < 2 then
		return nil
	end
	local index_of = {}
	for i, card in ipairs(origin) do
		index_of[card] = i
	end
	local order = {}
	local seen = {}
	for i, card in ipairs(cards) do
		local from = index_of[card]
		if not from or seen[from] then
			return nil
		end
		seen[from] = true
		order[i] = from
	end
	return order
end

local function is_identity_order(order)
	if not order then
		return true
	end
	for i, from in ipairs(order) do
		if from ~= i then
			return false
		end
	end
	return true
end

local function remember_reorder_origin(area)
	if not is_reorder_tracked_area(area) or reorder_origin[area] then
		return
	end
	reorder_origin[area] = copy_area_cards(area)
end

local function flush_area_reorder(area, keep_origin)
	if not is_reorder_tracked_area(area) then
		return
	end
	local origin = reorder_origin[area]
	if not origin then
		return
	end
	local order = permutation_from_origin(origin, area.cards)
	if keep_origin then
		reorder_origin[area] = copy_area_cards(area)
	else
		reorder_origin[area] = nil
	end
	if not (MP.RECORDER and MP.RECORDER.is_recording) or is_spectating() then
		return
	end
	if MP.SPECTATOR and MP.SPECTATOR.is_executing_action then
		return
	end
	if not order or is_identity_order(order) then
		return
	end
	MP.RECORDER.record_reorder_cards(get_card_area_name(area), order)
end

local function flush_tracked_reorders(keep_origin)
	if not G then
		return
	end
	flush_area_reorder(G.hand, keep_origin)
	flush_area_reorder(G.jokers, keep_origin)
end

-- Switch snapshots may skip local shop RNG so the captured offer can be
-- placed once. Live follow does not: cash-out / reroll must roll the seed.
local function is_applying_switch_snapshot()
	return is_spectating() and MP.SPECTATOR and MP.SPECTATOR.applying_snapshot
end

local function install_stream_shop_joker_hook()
	if MP.PLATFORM.HOOKS.spectator_shop_create_hooked then
		return
	end
	if type(create_card_for_shop) ~= "function" then
		return
	end
	MP.HOOKS.register_method_hook(_G, "_G", "create_card_for_shop", "mp.spectator.stream_shop_jokers", {
		before = function(ctx)
			if not is_applying_switch_snapshot() then
				-- Roll detector: while spectating, every shop card must come
				-- from either a live seed roll (cash-out/reroll) or a stamp.
				-- Logging which one fired makes unexplained boards traceable.
				if is_spectating() and MP.TESTING and MP.TESTING.log_spectator then
					MP.TESTING.log_spectator("SHOP", "roll", "live create_card_for_shop (seed)")
				end
				return
			end
			local take = MP.SPECTATOR and MP.SPECTATOR.take_queued_shop_joker
			local queue = MP.SPECTATOR and MP.SPECTATOR.shop_joker_queue
			if take and queue and #queue > 0 then
				ctx.skip_original = true
				ctx.results = { n = 1, [1] = take(ctx.self) }
			end
		end,
	})
	MP.HOOKS.register_method_hook(CardArea, "CardArea", "emplace", "mp.spectator.skip_nil_shop_card", {
		before = function(ctx)
			local card = ctx.args and ctx.args[1]
			if card then
				return
			end
			if not is_applying_switch_snapshot() then
				return
			end
			local area = ctx.self
			if not G or (area ~= G.shop_jokers and area ~= G.shop_vouchers and area ~= G.shop_booster) then
				return
			end
			ctx.skip_original = true
			ctx.results = { n = 0 }
		end,
	})
	MP.PLATFORM.HOOKS.spectator_shop_create_hooked = true
end
install_stream_shop_joker_hook()

-- On a switch snapshot, pre-build the shop UI so vanilla skips local RNG
-- spawn and the snapshot can place the real offer once. Live cash-out must
-- not do this — that shop has to roll from the shared seed.
MP.HOOKS.register_method_hook(Game, "Game", "update_shop", "mp.spectator.shop_ui_without_local_rng", {
	before = function()
		install_stream_shop_joker_hook()
		if not is_applying_switch_snapshot() then
			return
		end
		if not G or G.STATE_COMPLETE or G.shop then
			return
		end
		if not (G.UIDEF and G.UIDEF.shop and UIBox) then
			return
		end
		G.shop = UIBox({
			definition = G.UIDEF.shop(),
			config = {
				align = "tmi",
				offset = { x = 0, y = G.ROOM.T.y + 11 },
				major = G.hand,
				bond = "Weak",
			},
		})
	end,
})

if Tag and Tag.yep then
	MP.HOOKS.register_method_hook(Tag, "Tag", "yep", "mp.spectator.tag_yep_nil_hud", {
		before = function(ctx, self)
			if self and self.HUD_tag then
				return
			end
			local func = ctx.args and ctx.args[3]
			if type(func) == "function" then
				pcall(func)
			end
			if self and self.remove then
				pcall(function()
					self:remove()
				end)
			end
			ctx.skip_original = true
			ctx.results = { n = 0 }
		end,
	})
end

if Tag and Tag.nope then
	MP.HOOKS.register_method_hook(Tag, "Tag", "nope", "mp.spectator.tag_nope_nil_hud", {
		before = function(ctx, self)
			if self and self.HUD_tag then
				return
			end
			if self and self.remove then
				pcall(function()
					self:remove()
				end)
			end
			ctx.skip_original = true
			ctx.results = { n = 0 }
		end,
	})
end

if Tag and Tag.remove then
	MP.HOOKS.register_method_hook(Tag, "Tag", "remove", "mp.spectator.tag_remove_nil_hud", {
		before = function(ctx, self)
			if self and self.HUD_tag then
				return
			end
			if self and self.remove_from_game then
				pcall(function()
					self:remove_from_game()
				end)
			end
			ctx.skip_original = true
			ctx.results = { n = 0 }
		end,
	})
end

-- Shop tags already ran on the watched player. Re-running them while
-- stamping a switch snapshot would spawn extras on top of that offer.
if Tag and Tag.apply_to_run then
	MP.HOOKS.register_method_hook(Tag, "Tag", "apply_to_run", "mp.spectator.skip_local_shop_tags", {
		before = function(ctx)
			if not is_applying_switch_snapshot() then
				return
			end
			local context = ctx.args and ctx.args[1]
			local kind = context and context.type
			if
				kind == "shop_start"
				or kind == "store_joker_create"
				or kind == "store_joker_modify"
				or kind == "voucher_add"
				or kind == "shop_final_pass"
			then
				ctx.skip_original = true
				ctx.results = { n = 1, [1] = nil }
			end
		end,
	})
end

-- Log every real vanilla spawn (STATE_COMPLETE is false). More than one
-- spawn while an overlay already exists is the overlap loop.
MP.HOOKS.register_method_hook(Game, "Game", "update_blind_select", "mp.spectator.log_blind_select_spawn", {
	before = function()
		local spec = MP.SPECTATOR
		if not (spec and spec.is_spectating) then
			return
		end
		if G.STATE_COMPLETE then
			return
		end
		spec._blind_select_spawns = (spec._blind_select_spawns or 0) + 1
		local n = spec._blind_select_spawns
		local detail = string.format(
			"#%d catchup=%s has_select=%s events_base=%s uiboxes=%s",
			n,
			tostring(spec.is_catching_up),
			tostring(not not G.blind_select),
			tostring(G.E_MANAGER and G.E_MANAGER.queues and G.E_MANAGER.queues.base and #G.E_MANAGER.queues.base or 0),
			tostring(G.I and G.I.UIBOX and #G.I.UIBOX or 0)
		)
		if n <= 8 or n % 30 == 0 or G.blind_select then
			if MP.TESTING and MP.TESTING.log_spectator then
				MP.TESTING.log_spectator("BLIND", "vanilla_spawn", detail)
			else
				print("[SPEC BLIND] vanilla_spawn " .. detail)
			end
			if G.blind_select and MP.SPECTATOR_DIAG and MP.SPECTATOR_DIAG.flaw then
				MP.SPECTATOR_DIAG.flaw("blind_select.spawn_while_existing", detail)
			elseif MP.SPECTATOR_DIAG and MP.SPECTATOR_DIAG.log then
				MP.SPECTATOR_DIAG.log("blind_select.vanilla_spawn", detail)
			end
			if MP.SPECTATOR_DIAG and MP.SPECTATOR_DIAG.flush_buffer then
				pcall(MP.SPECTATOR_DIAG.flush_buffer)
			end
		end
	end,
})

-- Spectator input blocking is handled by MP.UI.isolate_spectator_input in
-- spectator_viewport_view.lua (node-state isolation). No Controller hooks here.

-- Register hooks using MP.HOOKS to ensure they are hooked properly across lifecycle

if Node and type(Node.set_offset) == "function" then
	MP.HOOKS.register_method_hook(Node, "Node", "set_offset", "mp.spectator.record_reorder_drag_start", {
		after = function(ctx, self)
			if is_spectating() then
				return
			end
			local offset_type = ctx.args and ctx.args[2]
			if offset_type ~= "Click" then
				return
			end
			remember_reorder_origin(self and self.area)
		end,
	})
end

if Node and type(Node.stop_drag) == "function" then
	MP.HOOKS.register_method_hook(Node, "Node", "stop_drag", "mp.spectator.record_reorder_drag_end", {
		after = function(ctx, self)
			if is_spectating() then
				reorder_origin[self and self.area] = nil
				return
			end
			flush_area_reorder(self and self.area, false)
		end,
	})
end

MP.HOOKS.register_method_hook(Game, "Game", "start_run", "mp.spectator.record_start_run", {
	after = function(ctx)
		if MP.RECORDER and MP.RECORDER.is_recording and not is_spectating() then
			local seed = (G.GAME and G.GAME.pseudorandom and G.GAME.pseudorandom.seed) or (G.GAME and G.GAME.seed)
			local back = (G.GAME and G.GAME.selected_back and G.GAME.selected_back.name)
				or (G.GAME and G.GAME.selected_back and G.GAME.selected_back.effect and G.GAME.selected_back.effect.center and G.GAME.selected_back.effect.center.key)
				or "Red Deck"
			local stake = (G.GAME and G.GAME.stake) or 1
			local challenge = (G.GAME and G.GAME.challenge)
			MP.RECORDER.record_start_run({
				seed = seed,
				back = back,
				stake = stake,
				challenge = challenge,
			})
			reorder_origin = {}
		end
	end,
})

MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "play_cards_from_highlighted", "mp.spectator.record_play_hand", {
	before = function(ctx)
		if MP.RECORDER and MP.RECORDER.is_recording and not is_spectating() then
			flush_tracked_reorders(true)
			local indices = get_hand_indices(G.hand and G.hand.highlighted)
			MP.RECORDER.record_play_hand(indices)
		end
	end,
})

MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "discard_cards_from_highlighted", "mp.spectator.record_discard", {
	before = function(ctx)
		if not (MP.RECORDER and MP.RECORDER.is_recording and not is_spectating()) then
			return
		end
		if not is_player_discard_event(ctx) then
			return
		end
		flush_tracked_reorders(true)
		MP.RECORDER.record_discard(get_hand_indices(G.hand and G.hand.highlighted))
	end,
})

MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "select_blind", "mp.spectator.record_select_blind", {
	before = function(ctx, e)
		if MP.RECORDER and MP.RECORDER.is_recording and not is_spectating() then
			local event = e or ctx.self or (ctx.args and ctx.args[1])
			local blind_row = get_blind_row_from_event(event) or (G and G.GAME and G.GAME.blind_on_deck) or "Small"
			local blind_ref = event and event.config and event.config.ref_table
			local blind_key = (blind_ref and (blind_ref.key or (blind_ref.config and blind_ref.config.blind and blind_ref.config.blind.key)))
				or (G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_choices and G.GAME.round_resets.blind_choices[blind_row])
			local blind_name = (blind_ref and blind_ref.name) or (blind_key and G.P_BLINDS[blind_key] and G.P_BLINDS[blind_key].name)
			MP.RECORDER.record_select_blind({
				key = blind_key,
				name = blind_name,
				blind_row = blind_row,
			})
		end
	end,
})

MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "skip_blind", "mp.spectator.record_skip_blind", {
	before = function(ctx, e)
		if MP.RECORDER and MP.RECORDER.is_recording and not is_spectating() then
			local event = e or ctx.self or (ctx.args and ctx.args[1])
			local blind_row = get_blind_row_from_event(event) or (G and G.GAME and G.GAME.blind_on_deck) or "Small"
			local key = G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_choices and G.GAME.round_resets.blind_choices[blind_row]
			MP.RECORDER.record_skip_blind({
				key = key,
				blind_row = blind_row,
			})
		end
	end,
})

MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "buy_from_shop", "mp.spectator.record_buy_shop", {
	before = function(ctx, e)
		if MP.RECORDER and MP.RECORDER.is_recording and not is_spectating() then
			flush_tracked_reorders(true)
			local event = e or ctx.self or (ctx.args and ctx.args[1])
			local card = event and event.config and event.config.ref_table
			-- "Buy & Use" pays without ever placing the card into consumeables
			-- and later re-enters G.FUNCS.use_card after the card has already
			-- left its area (card.area == nil). Record it here instead, while
			-- the shop slot index is still resolvable.
			if card and event.config.id == "buy_and_use" then
				if card.area then
					local area_name = get_card_area_name(card.area)
					local idx = get_card_index_in_area(card)
					local card_key = (card.config and card.config.center and card.config.center.key)
						or (card.config and card.config.center_key)
					local edition = card.edition and (card.edition.key or card.edition.type)
					MP.RECORDER.record_buy_and_use(area_name, idx, card_key, edition)
				end
				return
			end
			if card and card.area then
				local area_name = get_card_area_name(card.area)
				local idx = get_card_index_in_area(card)
				local card_key = (card.config and card.config.center and card.config.center.key) or (card.config and card.config.center_key) or (card.ability and card.ability.name)
				local edition = card.edition and (card.edition.key or card.edition.type)
				if area_name == "shop_booster" then
					MP.RECORDER.record_buy_booster(idx, card_key)
				else
					MP.RECORDER.record_buy_card(area_name, idx, card_key, edition)
				end
			end
		end
	end,
})

MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "use_card", "mp.spectator.record_use_card", {
	before = function(ctx, e)
		if MP.RECORDER and MP.RECORDER.is_recording and not is_spectating() then
			flush_tracked_reorders(true)
			local event = e or ctx.self or (ctx.args and ctx.args[1])
			-- Buy & Use re-enters this function after the card already left its
			-- shop area; that interaction is recorded by the buy_from_shop hook.
			if event and event.config and event.config.id == "buy_and_use" then
				return
			end
			local card = event and event.config and event.config.ref_table
			if card and card.area then
				local area_name = get_card_area_name(card.area)
				local idx = get_card_index_in_area(card)
				local card_key = (card.config and card.config.center and card.config.center.key) or (card.config and card.config.center_key) or (card.ability and card.ability.name)
				local edition = card.edition and (card.edition.key or card.edition.type)
				if area_name == "pack_cards" then
					MP.RECORDER.record_select_pack_card(idx)
				elseif (card.ability and card.ability.set == "Booster") or area_name == "shop_booster" then
					-- Shop packs use use_card (can_open), not buy_from_shop.
					MP.RECORDER.record_buy_booster(idx, card_key)
				else
					-- Consumable targets: hand is the default for tarots
					-- (Death, Sun, etc.) — only fall back to jokers/
					-- consumeables if the hand has no highlights. The old
					-- priority checked jokers first, so a lingering highlight
					-- there would steal the target from the hand, which is
					-- exactly why Death/Sun appeared targetless on spectators.
					local target_area = "hand"
					local target_indices = get_hand_indices(G.hand and G.hand.highlighted)
					if #target_indices == 0 then
						if G.jokers and G.jokers.highlighted and #G.jokers.highlighted > 0 then
							target_area = "jokers"
							target_indices = get_highlighted_area_indices(G.jokers.highlighted)
						elseif G.consumeables and G.consumeables.highlighted and #G.consumeables.highlighted > 0 then
							target_area = "consumeables"
							target_indices = get_highlighted_area_indices(G.consumeables.highlighted)
						end
					end
					MP.RECORDER.record_use_card(area_name, idx, target_indices, target_area, card_key)
				end
			end
		end
	end,
})

MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "skip_booster", "mp.spectator.record_skip_booster", {
	before = function(ctx)
		if MP.RECORDER and MP.RECORDER.is_recording and not is_spectating() then
			MP.RECORDER.record_skip_pack()
		end
	end,
})

MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "reroll_shop", "mp.spectator.record_reroll_shop", {
	before = function(ctx)
		if MP.RECORDER and MP.RECORDER.is_recording and not is_spectating() then
			MP.RECORDER.record_reroll_shop()
		end
	end,
})

MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "toggle_shop", "mp.spectator.record_toggle_shop", {
	before = function(ctx)
		if MP.RECORDER and MP.RECORDER.is_recording and not is_spectating() then
			MP.RECORDER.record_toggle_shop()
		end
	end,
})

MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "cash_out", "mp.spectator.record_cash_out", {
	before = function(ctx)
		if MP.RECORDER and MP.RECORDER.is_recording and not is_spectating() then
			MP.RECORDER.record_cash_out()
		end
	end,
})

MP.HOOKS.register_method_hook(Card, "Card", "sell_card", "mp.spectator.record_sell_card", {
	before = function(ctx, self)
		if MP.RECORDER and MP.RECORDER.is_recording and not is_spectating() then
			flush_tracked_reorders(true)
			local area_name = get_card_area_name(self.area)
			local idx = get_card_index_in_area(self)
			MP.RECORDER.record_sell_card(area_name, idx)
		end
	end,
})

MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "reroll_boss", "mp.spectator.record_reroll_boss", {
	before = function(ctx)
		if MP.RECORDER and MP.RECORDER.is_recording and not is_spectating() then
			MP.RECORDER.record_reroll_boss()
		end
	end,
})

MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "sort_hand_suit", "mp.spectator.record_sort_suit", {
	before = function(ctx)
		if MP.RECORDER and MP.RECORDER.is_recording and not is_spectating() then
			flush_tracked_reorders(false)
			MP.RECORDER.record_sort_hand("suit")
		end
	end,
})

MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "sort_hand_value", "mp.spectator.record_sort_value", {
	before = function(ctx)
		if MP.RECORDER and MP.RECORDER.is_recording and not is_spectating() then
			flush_tracked_reorders(false)
			MP.RECORDER.record_sort_hand("value")
		end
	end,
})

MP.PLATFORM.HOOKS.spectator_record_hooks_installed = true
return true
