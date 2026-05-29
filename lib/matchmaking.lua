MP.MOD_HASH = "0000"
MP.MOD_STRING = ""

MP.UTILS = MP.UTILS or {}

function MP.UTILS.hash_mod_string(str)
	local str_to_hash = str or "0000"
	local hash_value = 0
	for i = 1, #str_to_hash do
		local char = string.byte(str_to_hash, i)
		hash_value = (hash_value * 31 + char) % 10000
	end
	return string.format("%04d", hash_value)
end

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

local encrypt_ID, sum_numbers_in_table, parse_modlist

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
	MP.MOD_HASH = MP.UTILS.hash_mod_string(mod_string) or "0000"
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

-- Parses a semicolon-delimited hash string containing client compatibility data.
--
-- Input format: "preview=false;unlocked=true;encryptID=123456;serversideConnectionID=abc123;ModName1-1.0.0;ModName2-2.1.0"
--
-- Returns:
--   config (table): Parsed configuration object with structure:
--     {
--       encryptID = number,     -- Client's encryption ID
--       preview = boolean,      -- Whether Preview integration is enabled
--       unlocked = boolean,     -- Whether client has all content unlocked
--       Mods = table           -- Parsed mod list (see parse_modlist for structure)
--     }
--   mod_string (string): Semicolon-delimited compatibility string, excluding per-connection metadata
function MP.UTILS.parse_Hash(hash)
	local parts = {}
	for part in string.gmatch(hash, "([^;]+)") do
		table.insert(parts, part)
	end

	local config = {
		encryptID = nil,
		preview = nil,
		unlocked = nil,
		Mods = {},
	}

	local compatibility_data = {}
	local mod_entries = {}

	for _, part in ipairs(parts) do
		local key, val = string.match(part, "([^=]+)=([^=]+)")
		if key == "encryptID" then
			config.encryptID = tonumber(val)
		elseif key == "preview" then
			config.preview = val == "true"
			table.insert(compatibility_data, part)
		elseif key == "unlocked" then
			config.unlocked = val == "true"
		elseif key ~= "serversideConnectionID" then
			table.insert(compatibility_data, part)
			if key == nil then
				table.insert(mod_entries, part)
			end
		end
	end

	config.Mods = parse_modlist(mod_entries)
	local mod_string = table.concat(compatibility_data, ";")

	return config, mod_string
end

-- Parses an array of mod entries into a mod table
--
-- Input: Array of mod entry strings: {"ModName1-1.0.0", "ModName2-2.1.0", "ModName3"}
--
-- Returns:
--   mods (table): Key-value pairs where:
--     - key = mod name (string)
--     - value = mod version (string) or nil if no version specified
--
-- Example output:
--   {
--     ModName1 = "1.0.0",
--     ModName2 = "2.1.0",
--     ModName3 = nil
--   }
parse_modlist = function(mod_entries)
	if not mod_entries then return {} end

	local mods = {}

	for _, mod_entry in ipairs(mod_entries) do
		local mod_name, mod_version

		-- Split on the LAST dash to handle mod names with dashes (e.g., "lovely-compat-trance-v0.0.0")
		mod_name, mod_version = string.match(mod_entry, "^(.-)%-([^%-]*)$")
		if not mod_name then
			-- No dash found, entire string is mod name
			mod_name = mod_entry
			mod_version = nil
		end

		mods[mod_name] = mod_version
	end

	return mods
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
