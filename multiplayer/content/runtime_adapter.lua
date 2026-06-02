MP.CONTENT = MP.CONTENT or {}

local content_runtime = MP.CONTENT.RUNTIME or {}
MP.CONTENT.RUNTIME = content_runtime
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}
local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY or {}

if content_runtime._loaded then
	return
end
content_runtime._loaded = true

local function get_table_value(source, name, default)
	local value = type(source) == "table" and source[name] or nil
	if value == nil then
		return default
	end

	return value
end

local function call_table_function(source, name, ...)
	local fn = source and source[name] or nil
	if fn then
		fn(...)
		return true
	end

	return false
end

local function call_mp_action(action_name, ...)
	return call_table_function(MP and MP.ACTIONS, action_name, ...)
end

function content_runtime.has_active_lobby()
	return not not (MP and MP.LOBBY and MP.LOBBY.code)
end

function content_runtime.always_unlocked()
	return true
end

function content_runtime.get_current_mod_config()
	local smods = MP and MP.PLATFORM and MP.PLATFORM.SMODS or nil
	local current_mod = smods and smods.get_current_mod and smods.get_current_mod() or nil
	if current_mod and current_mod.config then
		return current_mod.config
	end

	return nil
end

function content_runtime.get_lobby_config_value(name, default)
	if not (content_runtime.has_active_lobby() and MP.LOBBY and MP.LOBBY.config) then
		return default
	end

	return get_table_value(MP.LOBBY.config, name, default)
end

function content_runtime.include_multiplayer_jokers()
	return not not content_runtime.get_lobby_config_value("multiplayer_jokers", false)
end

function content_runtime.include_standard_ruleset()
	local is_standard_ruleset = MP and MP.UTILS and MP.UTILS.is_standard_ruleset or nil
	return not not (content_runtime.has_active_lobby() and is_standard_ruleset and is_standard_ruleset())
end

function content_runtime.include_standard_or_sandbox_ruleset()
	return content_runtime.include_standard_ruleset()
		or content_runtime.get_lobby_config_value("ruleset") == "ruleset_mp_sandbox"
end

function content_runtime.is_phantom_card(card)
	return not not (card and card.edition and card.edition.type == "mp_phantom")
end

function content_runtime.sync_phantom(key, should_exist)
	if not key then
		return false
	end

	return call_mp_action(should_exist and "send_phantom" or "remove_phantom", key)
end

function content_runtime.sync_phantom_for_card(card, from_debuff, key, should_exist)
	if from_debuff or content_runtime.is_phantom_card(card) then
		return false
	end

	return content_runtime.sync_phantom(key, should_exist)
end

local function create_phantom_sync_hooks(key)
	return function(_, card, from_debuffed)
		return content_runtime.sync_phantom_for_card(card, from_debuffed, key, true)
	end, function(_, card, from_debuff)
		return content_runtime.sync_phantom_for_card(card, from_debuff, key, false)
	end
end

function content_runtime.with_phantom_sync_hooks(joker_definition, key)
	joker_definition.add_to_deck, joker_definition.remove_from_deck = create_phantom_sync_hooks(key)
	return joker_definition
end

function content_runtime.get_nemesis_enemy_state()
	local opponents = MP.OPPONENTS or {}
	return opponents.get_nemesis_enemy_state and opponents.get_nemesis_enemy_state() or nil
end

function content_runtime.get_enemy_shop_spent(index)
	local enemy = content_runtime.get_nemesis_enemy_state()
	return get_table_value(enemy and enemy.spent_in_shop, index, nil)
end

function content_runtime.get_enemy_sells_for_ante(ante)
	local enemy = content_runtime.get_nemesis_enemy_state()
	return tonumber(get_table_value(enemy and enemy.sells_per_ante, ante, 0)) or 0
end

function content_runtime.is_pvp_boss()
	local blind = BALATRO.get_current_blind and BALATRO.get_current_blind() or nil
	if not blind then
		return false
	end

	local blind_key = blind.config and blind.config.blind and blind.config.blind.key or nil
	return blind_key == "bl_mp_nemesis" or not not blind.pvp
end

function content_runtime.is_ruleset_active(ruleset)
	return not not (MP.is_ruleset_active and MP.is_ruleset_active(ruleset))
end

function content_runtime.create_buffered_dollars_reward(dollars)
	return BALATRO.create_buffered_dollars_reward(dollars)
end

function content_runtime.get_round_order_index()
	return MP.order_round_based and MP.order_round_based(true) or nil
end

function content_runtime.get_match_value(name, default)
	return get_table_value(MP and MP.GAME, name, default)
end

function content_runtime.get_pincher_unlock()
	return not not content_runtime.get_match_value("pincher_unlock", false)
end

function content_runtime.get_pincher_index()
	return tonumber(content_runtime.get_match_value("pincher_index", 0)) or 0
end

function content_runtime.increment_asteroids(amount)
	if match_domain.increment_asteroids then
		return match_domain.increment_asteroids(amount)
	end

	local current = tonumber(content_runtime.get_match_value("asteroids", 0)) or 0
	return current + (tonumber(amount) or 0)
end

function content_runtime.increment_pizza_discards(amount)
	if match_domain.increment_pizza_discards then
		return match_domain.increment_pizza_discards(amount)
	end

	local current = tonumber(content_runtime.get_match_value("pizza_discards", 0)) or 0
	return current + (tonumber(amount) or 0)
end

function content_runtime.send_lets_go_gambling_nemesis()
	return call_mp_action("lets_go_gambling_nemesis")
end

function content_runtime.send_eat_pizza(discards)
	return call_mp_action("eat_pizza", discards)
end

function content_runtime.send_magnet()
	return call_mp_action("magnet")
end

function content_runtime.apply_fake_back_vouchers(back)
	return call_table_function(MP, "apply_fake_back_vouchers", back)
end

function content_runtime.save_current_config()
	return call_table_function(MP, "save_current_config")
end

function content_runtime.get_effective_lobby_deck()
	return lobby_domain.get_effective_lobby_deck and lobby_domain.get_effective_lobby_deck() or nil
end

function content_runtime.get_lobby_deck_value(name, default)
	local lobby_deck = content_runtime.get_effective_lobby_deck()
	if not content_runtime.has_active_lobby() then
		return default
	end

	return get_table_value(lobby_deck, name, default)
end

function content_runtime.persist_cocktail_config(cocktail_config)
	if type(cocktail_config) ~= "string" then
		return false
	end

	if content_runtime.get_lobby_config_value("different_decks", false) and lobby_domain.update_run_deck then
		lobby_domain.update_run_deck({
			cocktail = cocktail_config,
		})
		return true
	end

	if lobby_domain.set_config_field then
		lobby_domain.set_config_field("cocktail", cocktail_config)
		if lobby_domain.sync_run_deck_from_config then
			lobby_domain.sync_run_deck_from_config()
		end
		return true
	end

	return false
end

MP.is_pvp_boss = content_runtime.is_pvp_boss
