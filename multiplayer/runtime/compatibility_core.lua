MP.DECK = MP.DECK or {}

MP.DECK.BANNED_JOKERS = MP.DECK.BANNED_JOKERS or {}
MP.DECK.BANNED_CONSUMABLES = MP.DECK.BANNED_CONSUMABLES or {}
MP.DECK.BANNED_VOUCHERS = MP.DECK.BANNED_VOUCHERS or {}
MP.DECK.BANNED_ENHANCEMENTS = MP.DECK.BANNED_ENHANCEMENTS or {}
MP.DECK.BANNED_TAGS = MP.DECK.BANNED_TAGS or {}
MP.DECK.BANNED_BLINDS = MP.DECK.BANNED_BLINDS or {}
MP.DECK.BANNED_CARDS = MP.DECK.BANNED_CARDS or {}
MP.DECK.MAX_STAKE = MP.DECK.MAX_STAKE or 0

function MP.DECK.ban_card(card_id)
	MP.DECK.BANNED_CARDS[#MP.DECK.BANNED_CARDS + 1] = { id = card_id }

	if card_id:sub(1, 1) == "j" then
		MP.DECK.BANNED_JOKERS[#MP.DECK.BANNED_JOKERS + 1] = card_id
	elseif card_id:sub(1, 1) == "c" then
		MP.DECK.BANNED_CONSUMABLES[#MP.DECK.BANNED_CONSUMABLES + 1] = card_id
	elseif card_id:sub(1, 1) == "v" then
		MP.DECK.BANNED_VOUCHERS[#MP.DECK.BANNED_VOUCHERS + 1] = card_id
	elseif card_id:sub(1, 1) == "m" then
		MP.DECK.BANNED_ENHANCEMENTS[#MP.DECK.BANNED_ENHANCEMENTS + 1] = card_id
	end
end

function MP.DECK.ban_cards(card_ids)
	for _, card_id in ipairs(card_ids or {}) do
		MP.DECK.ban_card(card_id)
	end
end

function MP.DECK.ban_blind(blind_id)
	MP.DECK.BANNED_BLINDS[#MP.DECK.BANNED_BLINDS + 1] = blind_id
end

local broken_center = {
	order = 1,
	unlocked = true,
	start_alerted = true,
	discovered = true,
	blueprint_compat = true,
	perishable_compat = true,
	eternal_compat = true,
	rarity = 4,
	cost = 10000,
	name = "BROKEN",
	pos = { x = 9, y = 9 },
	set = "Joker",
	effect = "",
	cost_mult = 1.0,
	config = {},
	key = "j_broken",
}

MP.HOOKS.register_method_hook(Card, "Card", "init", "mp.compatibility.broken_center", {
	before = function(ctx)
		if ctx.args[6] == nil then
			ctx.args[6] = broken_center
		end
	end,
})

local stake_queue = {}

function MP.set_max_stake(stake_key)
	if not MP.PLATFORM.SMODS.is_booted() then
		stake_queue[stake_key] = true
		return
	end

	local stake = 1
	repeat
		local key = MP.PLATFORM.SMODS.get_stake_key(stake)
		if key == stake_key then
			sendTraceMessage("Setting max stake to " .. stake, "MULTIPLAYER")
			MP.DECK.MAX_STAKE = math.max(stake, MP.DECK.MAX_STAKE)
			return
		end
		stake = stake + 1
	until key == "error"
end

MP.GAME_UPDATE_CYCLE.register_after("mp.compatibility.stake_queue", function()
	if next(stake_queue) and MP.PLATFORM.SMODS.is_booted() then
		for key, _ in pairs(stake_queue) do
			MP.set_max_stake(key)
			stake_queue[key] = nil
		end
	end
end, 20)
