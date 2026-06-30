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

function MP.UTILS.resolve_mod_name_and_version(mod_name, mod_version)
	local fullname = mod_name .. "-" .. (mod_version or "")
	local new_mod_name, new_mod_version = fullname:match("^(.*)%-([^~]+~.*)$")
	mod_name = new_mod_name or mod_name
	mod_version = new_mod_version or mod_version
	return mod_name, mod_version
end

function MP.UTILS.version_prefix(version)
	if type(version) ~= "string" then return nil end
	return version:match("^(%d+%.%d+%.%d+)") or version:match("^(%d+%.%d+)")
end

function MP.UTILS.player_mod_version(player, mod_name)
	if not player then return nil end

	local hash_str = player.hash_str or (player.config and player.config.hash_str)
	if type(hash_str) == "string" then
		local version = (";" .. hash_str):match(";" .. mod_name .. "%-([^;]+)")
		if version then return version end
	end

	local mods = player.config and player.config.Mods
	return mods and mods[mod_name] or nil
end

local function player_mod_version_for_ids(player, mod_ids)
	for _, mod_id in ipairs(mod_ids or {}) do
		local version = MP.UTILS.player_mod_version(player, mod_id)
		if version then return version end
	end
	return nil
end

local function lobby_owner(players)
	for _, player in ipairs(players or {}) do
		if player.is_owner then
			return player
		end
	end
	return players and players[1] or nil
end

local function version_check_mismatch(prefix, host_version, guest_version)
	if prefix then
		local host_prefix = MP.UTILS.version_prefix(host_version)
		local guest_prefix = MP.UTILS.version_prefix(guest_version)
		return host_prefix and guest_prefix and host_prefix ~= guest_prefix
	end

	return host_version ~= guest_version
end

local VERSION_CHECKS = {
	{ name = "Multiplayer", mod_ids = { "MultiplayerExperimental", "Multiplayer" }, prefix = true },
	{ name = "Steamodded", mod_ids = { "Steamodded" }, prefix = false },
}

function MP.UTILS.version_mismatches(players)
	players = players or (MP.LOBBY and MP.LOBBY.players) or {}
	local host = lobby_owner(players)
	if not host then return {} end

	local results = {}
	for _, guest in ipairs(players) do
		if guest ~= host and guest.id ~= host.id then
			for _, check in ipairs(VERSION_CHECKS) do
				local host_version = player_mod_version_for_ids(host, check.mod_ids)
				local guest_version = player_mod_version_for_ids(guest, check.mod_ids)
				if host_version and guest_version and version_check_mismatch(check.prefix, host_version, guest_version) then
					results[#results + 1] = {
						mod = check.name,
						our = host_version,
						their = guest_version,
						player = guest,
					}
				end
			end
		end
	end

	return results
end

function MP.UTILS.mp_version_mismatch(players)
	for _, mismatch in ipairs(MP.UTILS.version_mismatches(players)) do
		if mismatch.mod == "Multiplayer" then
			return true, mismatch.our, mismatch.their, mismatch.player
		end
	end

	return false
end

function MP.UTILS.get_banned_mods(mods)
	local banned_mods = {}
	if not mods then return banned_mods end

	for mod_name, mod_version in pairs(mods) do
		local ban_info = MP.BANNED_MODS and MP.BANNED_MODS[mod_name]
		local is_banned = false

		if type(ban_info) == "boolean" then
			is_banned = ban_info
		elseif type(ban_info) == "string" then
			is_banned = mod_version == ban_info
		elseif type(ban_info) == "table" then
			for _, banned_version in ipairs(ban_info) do
				if mod_version == banned_version then
					is_banned = true
					break
				end
			end
		end

		if is_banned then banned_mods[#banned_mods + 1] = mod_name end
	end

	table.sort(banned_mods)
	return banned_mods
end

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
