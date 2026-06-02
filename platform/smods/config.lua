MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.SMODS = MP.PLATFORM.SMODS or {}

local MP_CONFIG_STORAGE_ID = "MPexperimental"
local MP_CONFIG_LEGACY_STORAGE_IDS = {
	"multiplayer_experimental",
	"MultiplayerExperimental",
}
local NON_PERSISTENT_CONFIG_KEYS = {
	server_port = true,
	server_url = true,
}

local function get_config_owner(mod)
	return mod or MP.PLATFORM.SMODS.get_current_mod() or MP
end

local function build_mp_config_storage_mod(config, mod, storage_id)
	local owner = get_config_owner(mod)
	return {
		id = storage_id or MP_CONFIG_STORAGE_ID,
		path = owner and owner.path or MP.path,
		config_file = owner and owner.config_file or "config.lua",
		config = config,
	}
end

local function has_saved_config(storage_id)
	if not (NFS and type(NFS.read) == "function") then
		return false
	end

	local ok, contents = pcall(NFS.read, ("config/%s.jkr"):format(storage_id))
	return ok and type(contents) == "string" and contents ~= ""
end

local function merge_config_values(source, target)
	if type(source) ~= "table" or type(target) ~= "table" then
		return target
	end

	for key, value in pairs(source) do
		if type(value) == "table" and type(target[key]) == "table" then
			merge_config_values(value, target[key])
		else
			target[key] = value
		end
	end

	return target
end

local function remove_non_persistent_config_values(config)
	if type(config) ~= "table" then
		return config
	end

	for key in pairs(NON_PERSISTENT_CONFIG_KEYS) do
		config[key] = nil
	end

	return config
end

local function load_default_mod_config(owner)
	if not (NFS and type(NFS.read) == "function") then
		return nil
	end

	owner = get_config_owner(owner)
	local mod_path = owner and owner.path or MP.path
	local config_file = owner and owner.config_file or "config.lua"
	if type(mod_path) ~= "string" then
		return nil
	end

	local contents = NFS.read(mod_path .. config_file)
	if type(contents) ~= "string" then
		return nil
	end

	local chunk = load(contents, ("=[SMODS %s \"default_config\"]"):format(owner and owner.id or MP_CONFIG_STORAGE_ID))
	if type(chunk) ~= "function" then
		return nil
	end

	local ok, config = pcall(chunk)
	if ok and type(config) == "table" then
		return config
	end

	return nil
end

local function load_config_for_storage_id(storage_id, owner)
	if not has_saved_config(storage_id) then
		return nil
	end

	return SMODS.load_mod_config(build_mp_config_storage_mod(owner and owner.config or nil, owner, storage_id))
end

local function migrate_legacy_config(owner, config, preloaded_config)
	if has_saved_config(MP_CONFIG_STORAGE_ID) then
		return config
	end

	if type(preloaded_config) == "table" and has_saved_config(owner and owner.id or "") then
		merge_config_values(preloaded_config, config)
	end

	for _, legacy_id in ipairs(MP_CONFIG_LEGACY_STORAGE_IDS) do
		local legacy_config = load_config_for_storage_id(legacy_id, owner)
		if type(legacy_config) == "table" then
			merge_config_values(legacy_config, config)
		end
	end

	return config
end

local function normalize_config_path(path)
	if type(path) == "table" then
		return path
	end

	local normalized = {}
	for segment in tostring(path or ""):gmatch("[^%.]+") do
		normalized[#normalized + 1] = segment
	end
	return normalized
end

local function walk_config_path(root, path, create_missing)
	local current = root
	local normalized_path = normalize_config_path(path)

	if type(current) ~= "table" then
		return nil, nil
	end

	for index = 1, #normalized_path - 1 do
		local key = normalized_path[index]
		local next_value = current[key]
		if type(next_value) ~= "table" then
			if not create_missing then
				return nil, nil
			end

			next_value = {}
			current[key] = next_value
		end

		current = next_value
	end

	return current, normalized_path[#normalized_path]
end

function MP.PLATFORM.SMODS.load_config(mod)
	if not (SMODS and type(SMODS.load_mod_config) == "function") then
		return nil
	end

	local owner = get_config_owner(mod)
	local preloaded_config = owner and owner.config or nil
	local config = SMODS.load_mod_config(build_mp_config_storage_mod(owner and owner.config or nil, owner))
	config = migrate_legacy_config(owner, config, preloaded_config)
	config = remove_non_persistent_config_values(config)
	if type(config) == "table" then
		owner.config = config
	end

	return owner and owner.config or nil
end

function MP.PLATFORM.SMODS.save_config(mod)
	if not (SMODS and type(SMODS.save_mod_config) == "function") then
		return false
	end

	local owner = get_config_owner(mod)
	local config = owner and owner.config or MP.config
	config = remove_non_persistent_config_values(config)
	return SMODS.save_mod_config(build_mp_config_storage_mod(config, owner))
end

function MP.PLATFORM.SMODS.save_current_config()
	return MP.PLATFORM.SMODS.save_config(MP)
end

function MP.PLATFORM.SMODS.install_config_storage_hooks(mod)
	local owner = get_config_owner(mod)
	if not owner then
		return false
	end

	owner.load_mod_config = function(target_mod)
		return MP.PLATFORM.SMODS.load_config(target_mod or owner)
	end

	owner.save_mod_config = function(target_mod)
		return MP.PLATFORM.SMODS.save_config(target_mod or owner)
	end

	return true
end

function MP.PLATFORM.SMODS.get_config(mod)
	local owner = get_config_owner(mod)
	return owner and owner.config or MP.config
end

function MP.PLATFORM.SMODS.get_config_value(path, default, mod)
	local config = MP.PLATFORM.SMODS.get_config(mod)
	local current = config

	for _, key in ipairs(normalize_config_path(path)) do
		if type(current) ~= "table" then
			return default
		end

		current = current[key]
		if current == nil then
			return default
		end
	end

	if current == nil then
		return default
	end

	return current
end

function MP.PLATFORM.SMODS.set_config_value(path, value, mod)
	local owner = get_config_owner(mod)
	owner.config = owner.config or {}

	local parent, key = walk_config_path(owner.config, path, true)
	if not (parent and key) then
		return false
	end

	parent[key] = value
	return true
end

function MP.PLATFORM.SMODS.get_connection_settings(mod)
	local config = load_default_mod_config(mod)
	return {
		server_url = config and config.server_url or nil,
		server_port = config and config.server_port or nil,
	}
end

function MP.PLATFORM.SMODS.restart_game()
	if SMODS and type(SMODS.restart_game) == "function" then
		return SMODS.restart_game()
	end

	return false
end

function MP.save_current_config()
	return MP.PLATFORM.SMODS.save_current_config()
end
