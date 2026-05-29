-- Pre-compile a reversed list of all the centers
local reversed_centers = nil

function MP.UTILS.card_to_string(card)
	if not card or not card.base or not card.base.suit or not card.base.value then return "" end

	if not reversed_centers then reversed_centers = MP.UTILS.reverse_key_value_pairs(G.P_CENTERS) end

	local suit = string.sub(card.base.suit, 1, 1)

	local rank_value_map = {
		["10"] = "T",
		Jack = "J",
		Queen = "Q",
		King = "K",
		Ace = "A",
	}
	local rank = rank_value_map[card.base.value] or card.base.value

	local enhancement = reversed_centers[card.config.center] or "none"
	local edition = card.edition and MP.UTILS.reverse_key_value_pairs(card.edition, true)["true"] or "none"
	local seal = card.seal or "none"

	local card_str = suit .. "-" .. rank .. "-" .. enhancement .. "-" .. edition .. "-" .. seal

	return card_str
end

function MP.UTILS.get_phantom_joker(key)
	if not MP.shared or not MP.shared.cards then return nil end
	for i = 1, #MP.shared.cards do
		if
			MP.shared.cards[i].ability.name == key
			and MP.shared.cards[i].edition
			and MP.shared.cards[i].edition.type == "mp_phantom"
		then
			return MP.shared.cards[i]
		end
	end
	return nil
end

-- Maintain a stable single-enemy mirror for HUD/UI bindings that still point
-- at MP.GAME.enemy while the rest of the runtime tracks many enemies.
local function sync_primary_enemy_view(enemy)
	local primary_enemy_view = MP.GAME and MP.GAME.enemy
	if not primary_enemy_view then return end

	local empty_enemy = MP.GAME and MP.GAME.empty_enemy
	if empty_enemy then
		for key, value in pairs(empty_enemy) do
			primary_enemy_view[key] = value
		end
	end

	local source = enemy or empty_enemy
	if not source then return end

	for key, value in pairs(source) do
		primary_enemy_view[key] = value
	end
end

function MP.UTILS.refresh_primary_enemy_view(fallback_enemy)
	local source = MP.get_primary_enemy_state and MP.get_primary_enemy_state() or nil
	if not source or source == (MP.GAME and MP.GAME.empty_enemy) then
		source = fallback_enemy or source
	end

	sync_primary_enemy_view(source)
end

function MP.UTILS.get_deck_key_from_name(_name)
	for k, v in pairs(G.P_CENTERS) do
		if v.name == _name then return k end
	end
end

function MP.UTILS.get_culled_pool(_type, _rarity, _legendary, _append)
	local pool = get_current_pool(_type, _rarity, _legendary, _append)
	local ret = {}
	for i, v in ipairs(pool) do
		if v ~= "UNAVAILABLE" then ret[#ret + 1] = v end
	end
	return ret
end
