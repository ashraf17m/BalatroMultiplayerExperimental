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

local function get_card_ability_name(card)
	return card and card.ability and card.ability.name or nil
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
		trace_client_action("rerollShop", "cost:" .. tostring(G.GAME.current_round.reroll_cost))

		-- Update reroll stats if in a multiplayer game
		if MP.LOBBY.code and MP.GAME.stats then
			MP.GAME.stats.reroll_count = MP.GAME.stats.reroll_count + 1
			MP.GAME.stats.reroll_cost_total = MP.GAME.stats.reroll_cost_total + G.GAME.current_round.reroll_cost
		end
	end,
})

MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "buy_from_shop", "mp.game.trace_buy_from_shop", {
	before = function(ctx, e)
		local c1 = e.config.ref_table
		if c1 and c1:is(Card) then
			local card_name = get_card_ability_name(c1)
			if card_name then
				trace_client_action(
					"boughtCardFromShop",
					"card:" .. tostring(card_name) .. ",cost:" .. tostring(c1.cost)
				)
			end
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
		ctx.results = { n = 0 }
	end,
})
