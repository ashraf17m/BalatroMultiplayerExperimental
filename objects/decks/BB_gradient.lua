SMODS.Back({
	key = "gradient",
	config = {},
	atlas = "mp_decks",
	pos = { x = 0, y = 1 },
	apply = function(self)
		G.GAME.modifiers.mp_gradient = true
	end,
	mp_credits = { art = { "aura!", "Ganpan140" }, code = { "Toneblock" } },
})

MP.GRADIENT = MP.GRADIENT or {}
local Gradient = MP.GRADIENT

local function gradient_active()
	return G and G.GAME and G.GAME.modifiers and G.GAME.modifiers.mp_gradient
end

local function normal_rank(rank)
	if type(rank) ~= "number" then
		return nil
	end
	if rank < 2 or rank > 14 then
		return nil
	end
	return rank
end

local function shift_rank(rank, step)
	if rank == 14 and step == 1 then
		return 2
	end
	if rank == 2 and step == -1 then
		return 14
	end
	return normal_rank(rank + step)
end

function Gradient.active()
	return gradient_active()
end

function Gradient.real_rank(card)
	if not (card and card.base) then
		return nil
	end
	if card.ability and card.ability.effect == "Stone Card" and not card.vampired then
		return nil
	end
	return normal_rank(card.base.id)
end

function Gradient.ranks(card, options)
	local rank = Gradient.real_rank(card)
	if not rank then
		return {}
	end

	if not gradient_active() then
		return { rank }
	end

	options = options or {}
	local ranks = {}
	local seen = {}
	local candidates = {
		shift_rank(rank, -1),
		rank,
		shift_rank(rank, 1),
	}

	for _, candidate in ipairs(candidates) do
		if candidate and not seen[candidate] and not (options.gradient_only and candidate == rank) then
			seen[candidate] = true
			ranks[#ranks + 1] = candidate
		end
	end

	return ranks
end

function Gradient.matches_rank(card, rank, options)
	rank = normal_rank(rank)
	if not rank then
		return false
	end

	for _, candidate in ipairs(Gradient.ranks(card, options)) do
		if candidate == rank then
			return true
		end
	end

	return false
end

function Gradient.matches_any_rank(card, ranks, options)
	for _, rank in ipairs(ranks or {}) do
		if Gradient.matches_rank(card, rank, options) then
			return true
		end
	end

	return false
end

function Gradient.matches_rank_predicate(card, predicate, options)
	for _, rank in ipairs(Gradient.ranks(card, options)) do
		if predicate(rank) then
			return true
		end
	end

	return false
end

function Gradient.is_face(card, from_boss, options)
	if card and card.debuff and not from_boss then
		return false
	end
	if next(find_joker("Pareidolia")) then
		return true
	end
	return Gradient.matches_any_rank(card, { 11, 12, 13 }, options)
end

function Gradient.count_rank(cards, rank)
	local count = 0
	for _, card in pairs(cards or {}) do
		if Gradient.matches_rank(card, rank) then
			count = count + 1
		end
	end
	return count
end

Gradient.virtual_ranks = Gradient.virtual_ranks or {}
Gradient.generic_rank_depth = Gradient.generic_rank_depth or 0

local function pack_result(...)
	return { n = select("#", ...), ... }
end

local function track_side_effects(func)
	local event_manager = G and G.E_MANAGER
	local original_add_event = event_manager and event_manager.add_event
	local original_dollars = G and G.GAME and G.GAME.dollars
	local added_events = 0

	if type(original_add_event) == "function" then
		event_manager.add_event = function(manager, ...)
			added_events = added_events + 1
			return original_add_event(manager, ...)
		end
	end

	local ok, result = xpcall(func, function(err)
		if build_traceback then
			return build_traceback(err)
		end
		return tostring(err)
	end)

	if type(original_add_event) == "function" then
		event_manager.add_event = original_add_event
	end

	if not ok then
		error(result)
	end

	local dollars_changed = original_dollars ~= nil and G and G.GAME and G.GAME.dollars ~= original_dollars
	return result, added_events > 0 or dollars_changed
end

local function set_results(ctx, result)
	ctx.results = result or { n = 0 }
end

local function get_hook_original(method_name)
	local hook_state = MP.HOOKS
		and MP.HOOKS.method_targets
		and MP.HOOKS.method_targets[Card]
		and MP.HOOKS.method_targets[Card].methods
		and MP.HOOKS.method_targets[Card].methods[method_name]

	return hook_state and hook_state.original
end

local function with_virtual_rank(card, rank, func)
	local previous = Gradient.virtual_ranks[card]
	Gradient.virtual_ranks[card] = rank

	local ok, result = xpcall(func, function(err)
		if build_traceback then
			return build_traceback(err)
		end
		return tostring(err)
	end)

	if previous == nil then
		Gradient.virtual_ranks[card] = nil
	else
		Gradient.virtual_ranks[card] = previous
	end

	if not ok then
		error(result)
	end
	return result
end

local function add_unique_card(cards, card)
	if not card then
		return
	end
	for _, existing in ipairs(cards) do
		if existing == card then
			return
		end
	end
	cards[#cards + 1] = card
end

local function context_rank_cards(context)
	local cards = {}

	add_unique_card(cards, context.other_card)

	if context.destroying_card and context.full_hand and #context.full_hand == 1 then
		add_unique_card(cards, context.full_hand[1])
	end

	if context.cardarea == G.jokers and context.scoring_hand then
		for _, card in ipairs(context.scoring_hand) do
			add_unique_card(cards, card)
		end
	end

	return cards
end

local function calculate_with_virtual_ranks(joker, context)
	local original = get_hook_original("calculate_joker")
	if type(original) ~= "function" then
		return pack_result()
	end

	Gradient.generic_rank_depth = Gradient.generic_rank_depth + 1

	local ok, result = xpcall(function()
		local function call_original()
			local result, had_side_effect = track_side_effects(function()
				return pack_result(original(joker, context))
			end)
			result.had_side_effect = had_side_effect
			return result
		end

		local real_result = call_original()
		if real_result.had_side_effect or (real_result.n > 0 and real_result[1] ~= nil) then
			return real_result
		end

		for _, card in ipairs(context_rank_cards(context)) do
			for _, rank in ipairs(Gradient.ranks(card, { gradient_only = true })) do
				local virtual_result = with_virtual_rank(card, rank, call_original)
				if virtual_result.had_side_effect or (virtual_result.n > 0 and virtual_result[1] ~= nil) then
					return virtual_result
				end
			end
		end

		return pack_result()
	end, function(err)
		if build_traceback then
			return build_traceback(err)
		end
		return tostring(err)
	end)

	Gradient.generic_rank_depth = math.max(0, Gradient.generic_rank_depth - 1)
	if not ok then
		error(result)
	end

	return result
end

MP.HOOKS.register_method_hook(Card, "Card", "get_id", "mp.gradient.virtual_rank_id", {
	after = function(ctx, self)
		if gradient_active() and Gradient.virtual_ranks[self] then
			ctx.results = { Gradient.virtual_ranks[self], n = 1 }
		end
	end,
})

MP.HOOKS.register_method_hook(Card, "Card", "is_face", "mp.gradient.effective_face_ranks", {
	after = function(ctx, self)
		local from_boss = ctx.args[1]
		local existing = ctx.results and ctx.results[1]
		if gradient_active() and not existing and Gradient.is_face(self, from_boss, { gradient_only = true }) then
			ctx.results = { true, n = 1 }
		end
	end,
})

MP.HOOKS.register_method_hook(Card, "Card", "calculate_joker", "mp.gradient.generic_virtual_rank_replay", {
	before = function(ctx, self)
		local context = ctx.args[1]
		if not (gradient_active() and context and self and self.ability) then
			return
		end

		if Gradient.generic_rank_depth > 0 then
			return
		end

		ctx.skip_original = true
		set_results(ctx, calculate_with_virtual_ranks(self, context))
	end,
})

MP.HOOKS.register_method_hook(Card, "Card", "update", "mp.gradient.cached_rank_tallies", {
	after = function(ctx, self)
		if gradient_active() and self.ability and type(self.ability.nine_tally) == "number" then
			self.ability.nine_tally = Gradient.count_rank(G.playing_cards, 9)
		end
	end,
})
