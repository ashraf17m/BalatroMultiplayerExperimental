local function trace_client_action(action, suffix)
	if not sendTraceMessage then
		return
	end

	local message = "Client sent message: action:" .. tostring(action)
	if suffix and suffix ~= "" then
		message = message .. "," .. suffix
	end

	sendTraceMessage(message, "MULTIPLAYER")
end

local function send_end_game_summary_update()
	if not (MP.LOBBY and MP.LOBBY.code and MP.GAME) then
		return false
	end
	if MP.NETWORKING_INTERNAL and MP.NETWORKING_INTERNAL.send_end_game_summary_update then
		return MP.NETWORKING_INTERNAL.send_end_game_summary_update()
	end
	return false
end

local function get_card_ability_name(card)
	return card and card.ability and card.ability.name or nil
end

local function get_card_set(card)
	return card and card.ability and card.ability.set
		or card and card.config and card.config.center and card.config.center.set
		or nil
end

local function get_card_center_key(card)
	return card and card.config and (card.config.center_key or (card.config.center and card.config.center.key))
		or nil
end

local function resolve_center_key(card)
	local key = get_card_center_key(card)
	if key and G and G.P_CENTERS and G.P_CENTERS[key] then
		return key
	end

	local center = card and card.config and card.config.center or nil
	if center and G and G.P_CENTERS then
		for center_key, center_def in pairs(G.P_CENTERS) do
			if center_def == center then return center_key end
		end
	end

	return key
end

local function is_voucher_card(card)
	return get_card_set(card) == "Voucher"
end

local function ensure_match_stats()
	if not (MP.LOBBY and MP.LOBBY.code and MP.GAME) then return nil end

	MP.GAME.stats = MP.GAME.stats or {}
	local stats = MP.GAME.stats
	stats.reroll_count = tonumber(stats.reroll_count) or 0
	stats.reroll_cost_total = tonumber(stats.reroll_cost_total) or 0
	stats.total_money_spent = tonumber(stats.total_money_spent) or 0
	if type(stats.vouchers_bought) ~= "table" then stats.vouchers_bought = {} end
	return stats
end

local function add_money_spent(cost)
	local stats = ensure_match_stats()
	if not stats then return nil end

	cost = tonumber(cost) or 0
	if cost > 0 then stats.total_money_spent = stats.total_money_spent + cost end
	return stats, cost
end

local function original_returned_false(ctx)
	return ctx and ctx.results and ctx.results.n and ctx.results.n > 0 and ctx.results[1] == false
end

local function track_voucher_bought(stats, card)
	if not (stats and is_voucher_card(card)) then return end

	stats.vouchers_bought[#stats.vouchers_bought + 1] = resolve_center_key(card) or get_card_ability_name(card) or "UNKNOWN"
end

local function can_afford_shop_card(card)
	if not (G and G.GAME and card) then return false end

	local cost = tonumber(card.cost) or 0
	return cost <= (tonumber(G.GAME.dollars) or 0) - (tonumber(G.GAME.bankrupt_at) or 0)
end

local function is_shop_use_purchase(card)
	local set = get_card_set(card)
	return G and G.STATE == G.STATES.SHOP and (set == "Voucher" or set == "Booster") and can_afford_shop_card(card)
end

local ease_dollars_ref = ease_dollars
function ease_dollars(mod, instant)
	trace_client_action("moneyMoved", "amount:" .. tostring(mod))
	local result = ease_dollars_ref(mod, instant)
	if MP.sync_local_money_state then
		MP.sync_local_money_state()
	end
	return result
end

-- Certain Steamodded builds still call save_run while saving is disabled
-- In multiplayer runs this can crash when SMODS serializes transient hand data
local save_run_ref = save_run
function save_run(...)
	if G and G.F_NO_SAVING then
		if MP.RESUME and MP.RESUME.request_current_match_snapshot then
			MP.RESUME.request_current_match_snapshot()
		end
		return
	end
	return save_run_ref(...)
end

MP.HOOKS.register_method_hook(Card, "Card", "sell_card", "mp.game.trace_sold_card", {
	before = function(ctx, self)
		if MP.LOBBY.code and MP.ACTIONS and MP.ACTIONS.sold_joker then
			MP.ACTIONS.sold_joker()
		end

		local card_name = get_card_ability_name(self)
		if card_name then
			trace_client_action("soldCard", "card:" .. tostring(card_name))
		end
	end,
})

MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "reroll_shop", "mp.game.trace_reroll_shop", {
	before = function(ctx, e)
		local cost = G.GAME and G.GAME.current_round and tonumber(G.GAME.current_round.reroll_cost) or 0
		trace_client_action("rerollShop", "cost:" .. tostring(cost))

		local stats = ensure_match_stats()
		if stats then
			stats.reroll_count = stats.reroll_count + 1
			stats.reroll_cost_total = stats.reroll_cost_total + cost
			if cost > 0 then stats.total_money_spent = stats.total_money_spent + cost end
			send_end_game_summary_update()
		end
	end,
})

MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "buy_from_shop", "mp.game.trace_buy_from_shop", {
	after = function(ctx, e)
		if original_returned_false(ctx) then return end

		local c1 = e and e.config and e.config.ref_table
		if c1 and c1:is(Card) then
			local card_name = get_card_ability_name(c1)
			if card_name then
				trace_client_action(
					"boughtCardFromShop",
					"card:" .. tostring(card_name) .. ",cost:" .. tostring(c1.cost)
				)
			end
			add_money_spent(c1.cost)
			send_end_game_summary_update()
		end
	end,
})

MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "use_card", "mp.game.trace_use_card", {
	before = function(ctx, e)
		local ref_card = e and e.config and e.config.ref_table or nil
		local card_name = get_card_ability_name(ref_card)
		if card_name then
			trace_client_action("usedCard", "card:" .. tostring(card_name))
		end
		if ref_card and ref_card:is(Card) and is_shop_use_purchase(ref_card) then
			trace_client_action(
				"boughtCardFromShop",
				"card:" .. tostring(card_name or get_card_center_key(ref_card) or "UNKNOWN") .. ",cost:" .. tostring(ref_card.cost)
			)
			local is_voucher = is_voucher_card(ref_card)
			local stats = add_money_spent(ref_card.cost)
			if is_voucher then
				track_voucher_bought(stats, ref_card)
			end
			send_end_game_summary_update()
		end
	end,
})

MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "evaluate_round", "mp.game.end_pvp_context", {
	before = function()
		if G.after_pvp then
			G.after_pvp = nil
			MP.PLATFORM.SMODS.calculate_context({ mp_end_of_pvp = true })
		end
	end,
	after = function(ctx)
		send_end_game_summary_update()
		ctx.results = { n = 0 }
	end,
})
