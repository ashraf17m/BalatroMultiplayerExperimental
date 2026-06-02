MP.MOD_STRING = ""

MP.UTILS = MP.UTILS or {}

local function get_mod_data()
	local mod_table = {}
	local seen_mod_ids = {}
	local loaded_mods = MP.PLATFORM.SMODS.get_all_loaded_mods() or {}
	for key, mod in pairs(loaded_mods) do
		local mod_id = mod and (mod.id or key) or key
		if type(mod) == "table" and not mod.disabled and mod_id ~= "Balatro" and not seen_mod_ids[mod_id] then
			seen_mod_ids[mod_id] = true
			table.insert(mod_table, mod_id .. "-" .. (mod.version or "UNK"))
		end
	end
	for key, mod in pairs(MP.INTEGRATIONS or {}) do
		if mod then table.insert(mod_table, key .. "-MultiplayerIntegration") end
	end
	return mod_table
end

local encrypt_ID, sum_numbers_in_table

function MP:generate_hash()
	local mod_data = get_mod_data()
	table.sort(mod_data)
	table.insert(mod_data, 1, "serversideConnectionID=" .. tostring(MP.UTILS.server_connection_ID()))
	table.insert(mod_data, 1, "encryptID=" .. tostring(encrypt_ID()))
	MP.PLATFORM.SMODS.set_config_value("unlocked", MP.UTILS.unlock_check())
	table.insert(mod_data, 1, "unlocked=" .. tostring(MP.PLATFORM.SMODS.get_config_value("unlocked")))
	table.insert(mod_data, 1, "preview=" .. tostring(MP.PLATFORM.SMODS.get_config_value("integrations.Preview")))
	local mod_string = table.concat(mod_data, ";")
	MP.MOD_STRING = mod_string
	return true
end

local hash_generated = false

MP.HOOKS.register_method_hook(Game, "Game", "update", "mp.matchmaking.generate_hash", {
	after = function()
		if not hash_generated and MP.PLATFORM.SMODS.is_booted() then
			hash_generated = MP:generate_hash() == true
		end
	end,
})

function MP.UTILS.unlock_check()
	local notFullyUnlocked = false

	for k, v in pairs(G.P_CENTER_POOLS.Joker) do
		if not v.unlocked then
			notFullyUnlocked = true
			break -- No need to keep checking once we know it's not fully unlocked
		end
	end

	return not notFullyUnlocked
end

encrypt_ID = function()
	local encryptID = 1
	for key, center in pairs(G.P_CENTERS or {}) do
		if type(key) == "string" and key:match("^j_") then
			if center.cost and type(center.cost) == "number" then encryptID = encryptID + center.cost end
			if center.config and type(center.config) == "table" then
				encryptID = encryptID + sum_numbers_in_table(center.config)
			end
		elseif type(key) == "string" and key:match("^[cvp]_") then
			if center.cost and type(center.cost) == "number" then
				if center.cost == 0 then return 0 end
				encryptID = encryptID + center.cost
			end
		end
	end
	for key, value in pairs(G.GAME.starting_params or {}) do
		if type(value) == "number" and value % 1 == 0 then encryptID = encryptID * value end
	end
	local day = tonumber(os.date("%d")) or 1
	encryptID = encryptID * day
	local gameSpeed = G.SETTINGS.GAMESPEED
	if gameSpeed then
		gameSpeed = gameSpeed * 16
		gameSpeed = gameSpeed + 7
		encryptID = encryptID + (gameSpeed / 1000)
	else
		encryptID = encryptID + 0.404
	end
	return encryptID
end

sum_numbers_in_table = function(t)
	local sum = 0
	for k, v in pairs(t) do
		if type(v) == "number" then
			sum = sum + v
		elseif type(v) == "table" then
			sum = sum + sum_numbers_in_table(v)
		end
		-- ignore other types
	end
	return sum
end
