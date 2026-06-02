MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.SMODS = MP.PLATFORM.SMODS or {}

MP.BOOTSTRAP_INTERNAL = MP.BOOTSTRAP_INTERNAL or {}

function MP.BOOTSTRAP_INTERNAL.build_traceback(err)
	local message = tostring(err)
	if debug and debug.traceback then
		return debug.traceback(message, 2)
	end

	return message
end

local function set_bootstrap_failure(summary, details)
	MP.BOOTSTRAP_INTERNAL.failure_summary = summary
	MP.BOOTSTRAP_INTERNAL.failure_details = details
end

function MP.PLATFORM.SMODS.get_bootstrap_failure_summary()
	return MP.BOOTSTRAP_INTERNAL and MP.BOOTSTRAP_INTERNAL.failure_summary or nil
end

function MP.PLATFORM.SMODS.get_bootstrap_failure_details()
	return MP.BOOTSTRAP_INTERNAL and MP.BOOTSTRAP_INTERNAL.failure_details or nil
end

local function handle_load_failure(file, options, summary, details)
	sendWarnMessage(summary, "MULTIPLAYER")
	if details and details ~= summary then
		sendTraceMessage(details, "MULTIPLAYER")
	end

	if options and options.required then
		set_bootstrap_failure(summary, details)
	end
end

local function get_mod_load_id()
	if MP.PLATFORM.SMODS.get_current_mod_id then
		return MP.PLATFORM.SMODS.get_current_mod_id()
	end

	return (MP and MP.BOOT_MOD_ID) or (MP and MP.id) or "MultiplayerExperimental"
end

local function get_table_path(root, path)
	local current = root
	for segment in tostring(path or ""):gmatch("[^%.]+") do
		if type(current) ~= "table" then
			return nil
		end

		current = current[segment]
		if current == nil then
			return nil
		end
	end

	return current
end

local function has_prefix(name)
	return name:match("^_") ~= nil
end

function MP.PLATFORM.SMODS.load_mod_file(file, options)
	options = options or {}

	local chunk, err = SMODS.load_file(file, get_mod_load_id())
	if chunk then
		local ok, result = pcall(chunk)
		if ok then
			if result == nil then
				return true
			end

			return result
		else
			local summary = "Failed to process multiplayer file: " .. tostring(file)
			local details = tostring(result)
			handle_load_failure(file, options, summary, details)
		end
	else
		local summary = "Failed to find or compile multiplayer file: " .. tostring(file)
		local details = tostring(err)
		handle_load_failure(file, options, summary, details)
	end

	return nil
end

function MP.PLATFORM.SMODS.load_mod_dir(directory, recursive, options)
	recursive = recursive or false
	options = options or {}

	local dir_path = MP.path .. "/" .. directory
	local ok, items = pcall(NFS.getDirectoryItemsInfo, dir_path)
	if not ok or type(items) ~= "table" then
		local summary = "Failed to read multiplayer directory: " .. tostring(directory)
		local details = tostring(items)
		handle_load_failure(directory, options, summary, details)
		return false
	end

	table.sort(items, function(a, b)
		local ac, bc = 0, 0
		if has_prefix(a.name) then ac = ac + 100 end
		if has_prefix(b.name) then bc = bc + 100 end
		if a.type == "directory" then ac = ac + 10 end
		if b.type == "directory" then bc = bc + 10 end
		if ac ~= bc then return ac > bc end
		return string.lower(a.name) < string.lower(b.name)
	end)

	for _, item in ipairs(items) do
		local path = directory .. "/" .. item.name
		sendDebugMessage("Loading item: " .. path, "MULTIPLAYER")
		if item.type ~= "directory" then
			local loaded = MP.PLATFORM.SMODS.load_mod_file(path, options)
			if loaded == nil and options.required then
				return false
			end
		elseif recursive then
			local loaded = MP.PLATFORM.SMODS.load_mod_dir(path, recursive, options)
			if loaded == false and options.required then
				return false
			end
		end
	end

	return true
end

local function load_mod_collection(items, load_item, phase_name, options)
	if phase_name then
		sendDebugMessage("Bootstrap phase: " .. phase_name, "MULTIPLAYER")
	end

	options = options or {}

	for _, item in ipairs(items) do
		local loaded = load_item(item, options)
		if (loaded == nil or loaded == false) and options.required then
			return false
		end
	end

	return true
end

function MP.PLATFORM.SMODS.load_mod_files(files, phase_name, options)
	return load_mod_collection(files, MP.PLATFORM.SMODS.load_mod_file, phase_name, options)
end

function MP.PLATFORM.SMODS.load_mod_dirs(directories, recursive, phase_name, options)
	return load_mod_collection(directories, function(directory, load_options)
		return MP.PLATFORM.SMODS.load_mod_dir(directory, recursive, load_options)
	end, phase_name, options)
end

local function bootstrap_module(path, ready_path, options)
	local module = options or {}
	module.path = path
	module.ready_path = ready_path
	return module
end

local function is_bootstrap_module_ready(module)
	if type(module.ready) == "function" then
		return not not module.ready()
	end

	if module.ready_path then
		return not not get_table_path(MP, module.ready_path)
	end

	return false
end

local function is_balatro_runtime_ready()
	return get_table_path(MP, "PLATFORM.BALATRO.add_event")
		and get_table_path(MP, "PLATFORM.BALATRO.get_hud")
		and get_table_path(MP, "PLATFORM.BALATRO.read_saved_table")
		and get_table_path(MP, "PLATFORM.BALATRO.play_sound")
		and get_table_path(MP, "PLATFORM.BALATRO.register_wheelmoved_handler")
end

local PLATFORM_BOOTSTRAP_MODULES = {
	bootstrap_module("platform/smods/identity.lua", "PLATFORM.SMODS.get_current_mod_id"),
	bootstrap_module("platform/smods/registry.lua", "PLATFORM.SMODS.install_legacy_registry_alias"),
	bootstrap_module("platform/smods/config.lua", "PLATFORM.SMODS.load_config"),
	bootstrap_module("platform/smods/metadata.lua", "PLATFORM.SMODS.attach_current_mod"),
	bootstrap_module("platform/smods/mod_actions.lua", "register_mod_action"),
	bootstrap_module("platform/smods/bootstrap_map.lua", "PLATFORM.SMODS.BOOTSTRAP_MAP"),
	bootstrap_module("platform/balatro/threading.lua", "PLATFORM.BALATRO.create_thread"),
	bootstrap_module("platform/balatro/state.lua", "PLATFORM.BALATRO.get_game"),
	{
		path = "platform/balatro/runtime.lua",
		ready = is_balatro_runtime_ready,
	},
	bootstrap_module("platform/balatro/presentation.lua", "PLATFORM.BALATRO.create_player_blind_icon_object"),
	bootstrap_module("platform/smods/capabilities.lua", "PLATFORM.SMODS.compare_versions"),
	bootstrap_module("platform/hooks/registry.lua", "HOOKS.register_method_hook"),
	bootstrap_module("platform/hooks/targets.lua", "PLATFORM.HOOKS.capture_known_target"),
	bootstrap_module("platform/hooks/install.lua", "PLATFORM.HOOKS.install_known_override"),
	{
		path = "platform/hooks/round_hooks.lua",
		ready = function()
			return MP.PLATFORM and MP.PLATFORM.HOOKS and MP.PLATFORM.HOOKS.round_hooks_installed
		end,
	},
}

local function ensure_platform_bootstrap_modules()
	for _, module in ipairs(PLATFORM_BOOTSTRAP_MODULES) do
		if not is_bootstrap_module_ready(module) then
			local loaded = MP.PLATFORM.SMODS.load_mod_file(module.path, { required = true })
			if loaded == nil then
				return false
			end
		end
	end

	return true
end

function MP.PLATFORM.SMODS.bootstrap_runtime()
	if not ensure_platform_bootstrap_modules() then
		return false
	end

	if not (MP.PLATFORM and MP.PLATFORM.SMODS and MP.PLATFORM.SMODS.install_legacy_registry_alias
		and MP.PLATFORM.SMODS.load_config and MP.PLATFORM.SMODS.install_config_storage_hooks
		and MP.PLATFORM.SMODS.attach_current_mod
		and MP.PLATFORM.SMODS.load_mod_file) then
		sendWarnMessage("Multiplayer platform bootstrap is incomplete.", "MULTIPLAYER")
		return false
	end

	MP.PLATFORM.SMODS.attach_current_mod()
	MP.PLATFORM.SMODS.install_legacy_registry_alias(MP)
	MP.PLATFORM.SMODS.install_config_storage_hooks(MP)
	MP.PLATFORM.SMODS.load_config(MP)

	local startup_bootstrap = MP.PLATFORM.SMODS.load_mod_file("bootstrap/startup.lua", { required = true })
	return startup_bootstrap ~= nil
end
