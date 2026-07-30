G.P_CENTER_POOLS.Ruleset = {}
MP.Rulesets = {}
local selection_utils = MP.UTILS

local RulesetBase = SMODS.GameObject:extend({
	obj_table = {},
	obj_buffer = {},
	required_params = {
		"key",
		"multiplayer_content",
		"banned_jokers",
		"banned_consumables",
		"banned_vouchers",
		"banned_enhancements",
		"banned_tags",
		"banned_blinds",
		"reworked_jokers",
		"reworked_consumables",
		"reworked_vouchers",
		"reworked_enhancements",
		"reworked_tags",
		"reworked_blinds",
		"create_info_menu",
	},
	class_prefix = "ruleset",
	inject = function(self)
		MP.Rulesets[self.key] = self
		if not G.P_CENTER_POOLS.Ruleset then G.P_CENTER_POOLS.Ruleset = {} end
		if not selection_utils.pool_contains_key(G.P_CENTER_POOLS.Ruleset, self.key) then
			table.insert(G.P_CENTER_POOLS.Ruleset, self)
		end
	end,
	process_loc_text = function(self)
		SMODS.process_loc_text(G.localization.descriptions["Ruleset"], self.key, self.loc_txt)
	end,
	is_disabled = function(self)
		return false
	end,
	force_lobby_options = function(self)
		return false
	end,
})

local function add_ruleset_reverse_index_entries(index, ruleset_key, entries)
	if not index or not ruleset_key then
		return
	end
	for _, key in ipairs(entries or {}) do
		index[key] = index[key] or {}
		index[key][#index[key] + 1] = ruleset_key
	end
end

function MP.Ruleset(init)
	if MP.resolve_layers then
		init = MP.resolve_layers(init)
	end

	add_ruleset_reverse_index_entries(MP._JOKER_LAYERS, init and init.key, init and init.reworked_jokers)
	add_ruleset_reverse_index_entries(MP._CONSUMABLE_LAYERS, init and init.key, init and init.reworked_consumables)
	add_ruleset_reverse_index_entries(MP._TAG_LAYERS, init and init.key, init and init.reworked_tags)

	return RulesetBase(init)
end

function MP.is_ruleset_active(ruleset_name)
	local key = "ruleset_mp_" .. ruleset_name
	if MP.LOBBY.code then
		return MP.LOBBY.config.ruleset == key
	end
	return false
end

local ruleset_ban_extensions = {
	order = {},
	handlers = {},
}

function MP.register_ruleset_ban_extension(key, handler)
	if type(key) ~= "string" or key == "" then
		error("Ruleset ban extension key must be a non-empty string")
	end
	if type(handler) ~= "function" then
		error("Ruleset ban extension handler must be a function")
	end

	local registry = ruleset_ban_extensions
	if not registry.handlers[key] then
		registry.order[#registry.order + 1] = key
	end
	registry.handlers[key] = handler
end

local function apply_base_ruleset_bans()
	local ruleset_key = nil
	local gamemode = nil

	if MP.get_active_ruleset then
		ruleset_key = MP.get_active_ruleset()
		local gamemode_key = MP.get_active_gamemode and MP.get_active_gamemode() or nil
		gamemode = gamemode_key and MP.Gamemodes[gamemode_key] or nil
	elseif MP.LOBBY.code and MP.LOBBY.config.ruleset then
		ruleset_key = MP.LOBBY.config.ruleset
		gamemode = MP.Gamemodes[MP.LOBBY.config.gamemode]
	end

	if ruleset_key then
		local ruleset = MP.Rulesets[ruleset_key]
		local banned_tables = {
			"jokers",
			"consumables",
			"vouchers",
			"enhancements",
			"tags",
			"blinds",
		}
		for _, table in ipairs(banned_tables) do
			for _, v in ipairs(ruleset["banned_" .. table]) do
				G.GAME.banned_keys[v] = true
			end
			if gamemode then
				for _, v in ipairs(gamemode["banned_" .. table]) do
					G.GAME.banned_keys[v] = true
				end
			end
			for _, v in pairs(MP.DECK["BANNED_" .. string.upper(table)]) do
				G.GAME.banned_keys[v] = true
			end
		end
		for _, v in ipairs(ruleset["banned_silent"] or {}) do
			G.GAME.banned_keys[v] = true
		end
	end
end

function MP.ApplyBans()
	local result = apply_base_ruleset_bans()
	local registry = ruleset_ban_extensions
	for _, key in ipairs(registry and registry.order or {}) do
		local handler = registry.handlers[key]
		if handler then
			handler()
		end
	end
	if MP.apply_layer_run_start_fields then
		MP.apply_layer_run_start_fields()
	end
	if MP.RunLayerHooks then
		MP.RunLayerHooks("on_apply_bans")
	end
	if MP.apply_lobby_bonus_run_start_fields then
		MP.apply_lobby_bonus_run_start_fields()
	end
	return result
end

-- Rework a center for specific ruleset/layer slot(s). Use MP.LoadReworks() to swap in the active ruleset.
---@param key string e.g. "j_hanging_chad"
---@param opts table { rulesets|layers, loc_key?, silent?, ...center properties }
function MP.ReworkCenter(key, opts)
	local center = G.P_CENTERS[key]
	opts = opts or {}

	-- Meta keys (not center properties)
	local reserved = { rulesets = true, layers = true, loc_key = true, silent = true }
	local rulesets = opts.rulesets or opts.layers
	local loc_key = opts.loc_key
	local silent = opts.silent

	-- Convert single ruleset to list
	if type(rulesets) == "string" then rulesets = { rulesets } end

	-- Wrap loc_vars to inject loc_key if provided
	if loc_key then
		local user_loc_vars = opts.loc_vars or function()
			return {}
		end
		opts.loc_vars = function(self, info_queue, card)
			local result = user_loc_vars(self, info_queue, card)
			result.key = loc_key
			return result
		end
	end

	-- do we need to inject generate_ui for loc_vars to work?
	local needs_generate_ui = opts.loc_vars
		and not opts.generate_ui
		and not (center.generate_ui and type(center.generate_ui) == "function")

	-- Apply changes to all specified rulesets
	for _, rs in ipairs(rulesets) do
		local prefix = "mp_" .. rs .. "_"

		-- Store all reworked properties
		for k, v in pairs(opts) do
			if not reserved[k] then
				center[prefix .. k] = v
				if not center["mp_vanilla_" .. k] then center["mp_vanilla_" .. k] = center[k] or "NULL" end
			end
		end

		-- Auto-inject generate_ui when adding loc_vars to vanilla centers
		if needs_generate_ui then
			center[prefix .. "generate_ui"] = SMODS.Center.generate_ui
			if not center.mp_vanilla_generate_ui then center.mp_vanilla_generate_ui = center.generate_ui or "NULL" end
		end

		-- Mark this center as having reworks
		center.mp_reworks = center.mp_reworks or {}
		center.mp_reworks[rs] = true
		center.mp_reworks["vanilla"] = true

		center.mp_silent = center.mp_silent or {}
		center.mp_silent[rs] = silent
	end
end

-- You can call this function without a ruleset to set it to vanilla
-- You can also call this function with a key to only affect that specific joker (might be useful)
function MP.LoadReworks(ruleset, key)
	ruleset = ruleset or "vanilla"
	if string.sub(ruleset, 1, 11) == "ruleset_mp_" then ruleset = string.sub(ruleset, 12, #ruleset) end
	local function get_rework_chain(ruleset_)
		if ruleset_ == "vanilla" then
			return { "vanilla" }
		end
		if MP.active_layer_chain then
			local chain = MP.active_layer_chain(ruleset_)
			if chain and #chain > 0 then
				return chain
			end
		end
		return { ruleset_ }
	end
	local function process(key_, ruleset_)
		local center = G.P_CENTERS[key_]
		for k, v in pairs(center) do
			if string.sub(k, 1, #ruleset_) == ruleset_ then
				local orig = string.sub(k, #ruleset_ + 1)
				if orig == "rarity" then
					SMODS.remove_pool(G.P_JOKER_RARITY_POOLS[center[orig]], center.key)
					table.insert(G.P_JOKER_RARITY_POOLS[center[k]], center)
					table.sort(G.P_JOKER_RARITY_POOLS[center[k]], function(a, b)
						return a.order < b.order
					end)
				end
				if center[k] == "NULL" then
					center[orig] = nil
				else
					center[orig] = center[k]
				end
			end
		end
	end
	local rework_chain = get_rework_chain(ruleset)
	if key then
		for _, rework_key in ipairs(rework_chain) do
			process(key, "mp_" .. rework_key .. "_")
		end
	else
		for k, v in pairs(G.P_CENTERS) do
			if v.mp_reworks then
				local applied = false
				for _, rework_key in ipairs(rework_chain) do
					if v.mp_reworks[rework_key] then
						process(k, "mp_" .. rework_key .. "_")
						applied = true
					end
				end
				if not applied and v.mp_reworks["vanilla"] then -- Check vanilla separately to reset reworked jokers
					process(k, "mp_vanilla_")
				end
			end
		end
	end
end
