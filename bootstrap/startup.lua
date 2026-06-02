local platform_loader = MP.PLATFORM and MP.PLATFORM.SMODS or nil
local bootstrap_map = platform_loader and platform_loader.BOOTSTRAP_MAP or nil

local NETWORK_RUNTIME_FILES = bootstrap_map and bootstrap_map.NETWORK_RUNTIME_FILES or {}
local NETWORK_DISPATCH_FILES = bootstrap_map and bootstrap_map.NETWORK_DISPATCH_FILES or {}
local NETWORK_SENDER_FILES = bootstrap_map and bootstrap_map.NETWORK_SENDER_FILES or {}
local OBJECT_DIRECTORIES = bootstrap_map and bootstrap_map.OBJECT_DIRECTORIES or {}
local CORE_RUNTIME_FILES = bootstrap_map and bootstrap_map.CORE_RUNTIME_FILES or {}
local TEAM_SYNC_FEATURE_FILES = bootstrap_map and bootstrap_map.TEAM_SYNC_FEATURE_FILES or {}
local TEAM_SYNC_DIAGNOSTIC_FILES = bootstrap_map and bootstrap_map.TEAM_SYNC_DIAGNOSTIC_FILES or {}
local PROTOCOL_BOUNDARY_FILES = bootstrap_map and bootstrap_map.PROTOCOL_BOUNDARY_FILES or {}
local UI_BOUNDARY_FILES = bootstrap_map and bootstrap_map.UI_BOUNDARY_FILES or {}
local CONTENT_ADAPTER_FILES = bootstrap_map and bootstrap_map.CONTENT_ADAPTER_FILES or {}

MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}

local function get_lobby_domain()
	return MP.DOMAIN and MP.DOMAIN.LOBBY or nil
end

local function get_match_domain()
	return MP.DOMAIN and MP.DOMAIN.MATCH or nil
end

local function get_bootstrap_failure_message(fallback)
	local failure_summary = platform_loader and platform_loader.get_bootstrap_failure_summary
		and platform_loader.get_bootstrap_failure_summary()
		or nil
	if failure_summary and failure_summary ~= "" then
		return failure_summary
	end

	return fallback
end

local function queue_bootstrap_failure_notice(message)
	if not (G and G.E_MANAGER) then
		return
	end

	G.E_MANAGER:add_event(Event({
		no_delete = true,
		trigger = "immediate",
		blockable = false,
		blocking = false,
		func = function()
			if not G.MAIN_MENU_UI then
				return
			end

			local formatted_message = message
			if MP.UTILS and MP.UTILS.wrapText then
				formatted_message = MP.UTILS.wrapText(message, 50)
			end

			if MP.UI and MP.UI.UTILS and MP.UI.UTILS.overlay_message then
				MP.UI.UTILS.overlay_message(formatted_message)
			else
				sendWarnMessage(formatted_message, "MULTIPLAYER")
			end

			return true
		end,
	}))
end

local function abort_bootstrap(message)
	local failure_message = get_bootstrap_failure_message(message)
	local failure_details = platform_loader and platform_loader.get_bootstrap_failure_details
		and platform_loader.get_bootstrap_failure_details()
		or nil

	sendWarnMessage(failure_message, "MULTIPLAYER")
	if failure_details and failure_details ~= failure_message then
		sendTraceMessage(failure_details, "MULTIPLAYER")
	end

	queue_bootstrap_failure_notice(failure_message)
	return false
end

local function require_bootstrap_step(ok, failure_message)
	if ok then
		return true
	end

	return abort_bootstrap(failure_message)
end

local function run_bootstrap_phase_steps(steps)
	for _, step in ipairs(steps or {}) do
		local ok = true

		if step.kind == "dirs" then
			ok = platform_loader and platform_loader.load_mod_dirs(step.paths, step.recursive, step.label, step.options)
		elseif step.kind == "dir" then
			ok = platform_loader and platform_loader.load_mod_dir(step.path, step.recursive, step.options)
		elseif step.kind == "file" then
			ok = platform_loader and platform_loader.load_mod_file(step.path, step.options) ~= nil
		elseif step.kind == "files" then
			ok = platform_loader and platform_loader.load_mod_files(step.paths, step.label, step.options)
		elseif step.kind == "call" then
			ok = step.fn()
		elseif step.kind == "side_effect" then
			step.fn()
		else
			return abort_bootstrap("Encountered an unknown multiplayer bootstrap step.")
		end

		if step.failure_message then
			if not require_bootstrap_step(ok, step.failure_message) then
				return false
			end
		elseif step.stop_on_false and ok == false then
			return false
		end
	end

	return true
end

local initialize_runtime_state = function()
	local lobby_domain = get_lobby_domain()
	if lobby_domain and lobby_domain.initialize_runtime_state then
		lobby_domain.initialize_runtime_state()
	end
	if MP.initialize_multiplayer_settings then
		MP.initialize_multiplayer_settings()
	end
	if MP.apply_experimental_env_overrides then
		MP.apply_experimental_env_overrides()
	end
	if MP.UTILS and MP.UTILS.trace_runtime_event then
		MP.UTILS.trace_runtime_event("runtime_trace.enabled")
	end
end

local initialize_lobby_defaults = function()
	local lobby_domain = get_lobby_domain()
	local match_domain = get_match_domain()
	if not (lobby_domain and lobby_domain.reset_config and match_domain and match_domain.reset_state) then
		return false
	end
	if not MP.UTILS or not MP.UTILS.get_username or not MP.UTILS.get_blind_col or not MP.UTILS.get_weekly then
		return false
	end

	lobby_domain.reset_config()
	match_domain.reset_state()

	MP.LOBBY.client.username = MP.UTILS.get_username()
	MP.LOBBY.client.blind_col = MP.UTILS.get_blind_col()

	MP.LOBBY.config.weekly = MP.UTILS.get_weekly()
	return true
end

local verify_lovely_loaded = function()
	if MP.PLATFORM and MP.PLATFORM.SMODS and MP.PLATFORM.SMODS.is_lovely_loaded
		and MP.PLATFORM.SMODS.is_lovely_loaded() then
		return true
	end

	G.E_MANAGER:add_event(Event({
		no_delete = true,
		trigger = "immediate",
		blockable = false,
		blocking = false,
		func = function()
			if G.MAIN_MENU_UI then
				MP.UI.UTILS.overlay_message(
					MP.UTILS.wrapText(
						"Your Multiplayer Mod is not loaded correctly, make sure the Multiplayer folder does not have an extra Multiplayer folder around it.",
						50
					)
				)
				return true
			end
		end,
	}))
	return false
end

local load_weekly_ruleset = function()
	if MP.LOBBY.config.weekly then
		platform_loader.load_mod_file("rulesets/weeklies/" .. MP.LOBBY.config.weekly .. ".lua")
	end
end

local TESTING_TOOL_FILES = {
	"testing_tools/rulesets/testing.lua",
	"testing_tools/decks/testing_deck.lua",
	"testing_tools/decks/testing_2_deck.lua",
	"testing_tools/notice.lua",
	"testing_tools/temp_username_hotkey.lua",
	"testing_tools/dummy_players_hotkey.lua",
}

local DIAGNOSTIC_TOOL_FILES = {
	calculator = "testing_tools/diagnostics/calculator.lua",
}

local load_testing_tools = function()
	local enabled_by_config = platform_loader.get_config_value("testing_tools", false, MP) == true
	local enabled_by_env = MP.EXPERIMENTAL and MP.EXPERIMENTAL.testing_tools == true
	if not (enabled_by_config or enabled_by_env) then
		return true
	end

	return platform_loader.load_mod_files(TESTING_TOOL_FILES, "Testing tools", { required = false }) ~= false
end

local load_diagnostic_tools = function()
	if MP.EXPERIMENTAL and MP.EXPERIMENTAL.calculator_trace_logging == true then
		return platform_loader.load_mod_file(DIAGNOSTIC_TOOL_FILES.calculator, { required = false }) ~= nil
	end

	return true
end

local function is_runtime_trace_logging_enabled()
	return MP.UTILS
		and MP.UTILS.is_runtime_trace_enabled
		and MP.UTILS.is_runtime_trace_enabled()
end

local function build_team_sync_feature_files()
	local files = {}
	for _, file in ipairs(TEAM_SYNC_FEATURE_FILES) do
		files[#files + 1] = file
		if file == "multiplayer/features/team_card_sync_identity.lua" and is_runtime_trace_logging_enabled() then
			for _, diagnostic_file in ipairs(TEAM_SYNC_DIAGNOSTIC_FILES) do
				files[#files + 1] = diagnostic_file
			end
		end
	end
	return files
end

local load_team_sync_feature_files = function()
	return platform_loader.load_mod_files(build_team_sync_feature_files(), "Team sync feature files", { required = true }) ~= false
end

local register_multiplayer_mod_icon = function()
	SMODS.Atlas({
		key = "modicon",
		path = "modicon.png",
		px = 34,
		py = 34,
	})
end

local finalize_network_dispatch_routes = function()
	if not MP.NETWORKING_INTERNAL.rebuild_action_routes then
		return false
	end

	MP.NETWORKING_INTERNAL.rebuild_action_routes()
	return true
end

local CORE_BOOTSTRAP_STEPS = {
	{
		kind = "dirs",
		paths = { "lib" },
		recursive = false,
		label = "Core libraries",
		options = { required = true },
		failure_message = "Failed to load required multiplayer core libraries.",
	},
	{
		kind = "file",
		path = "multiplayer/domain/match.lua",
		options = { required = true },
		failure_message = "Failed to load required multiplayer match domain.",
	},
	{
		kind = "files",
		paths = PROTOCOL_BOUNDARY_FILES,
		label = "Protocol boundary surfaces",
		options = { required = true },
		failure_message = "Failed to load required multiplayer protocol boundary support.",
	},
	{ kind = "call", fn = initialize_runtime_state },
	{ kind = "call", fn = load_diagnostic_tools },
	{
		kind = "files",
		paths = CORE_RUNTIME_FILES,
		label = "Core runtime services",
		options = { required = true },
		failure_message = "Failed to load required multiplayer core runtime services.",
	},
	{
		kind = "call",
		fn = load_team_sync_feature_files,
		failure_message = "Failed to load required multiplayer team sync feature support.",
	},
	{
		kind = "dir",
		path = "overrides",
		recursive = false,
		options = { required = true },
		failure_message = "Failed to load required multiplayer gameplay overrides.",
	},
	{
		kind = "call",
		fn = initialize_lobby_defaults,
		failure_message = "Failed to initialize required multiplayer lobby defaults.",
	},
	{
		kind = "call",
		fn = verify_lovely_loaded,
		stop_on_false = true,
	},
	{ kind = "side_effect", fn = register_multiplayer_mod_icon },
	{
		kind = "dirs",
		paths = { "compatibility" },
		recursive = false,
		label = "Compatibility shims",
	},
}

local NETWORKING_DEFINITION_STEPS = {
	{
		kind = "files",
		paths = NETWORK_RUNTIME_FILES,
		label = "Networking runtime handlers",
		options = { required = true },
		failure_message = "Failed to load required multiplayer networking runtime handlers.",
	},
	{
		kind = "files",
		paths = NETWORK_DISPATCH_FILES,
		label = "Networking dispatch registries",
		options = { required = true },
		failure_message = "Failed to load required multiplayer networking dispatch registries.",
	},
	{
		kind = "call",
		fn = finalize_network_dispatch_routes,
		failure_message = "Failed to finalize required multiplayer networking dispatch routes.",
	},
	{
		kind = "files",
		paths = NETWORK_SENDER_FILES,
		label = "Networking send helpers",
		options = { required = true },
		failure_message = "Failed to load required multiplayer networking send helpers.",
	},
}

local CONTENT_BOOTSTRAP_STEPS = {
	{
		kind = "dirs",
		paths = { "gamemodes", "rulesets" },
		recursive = false,
		label = "Mode and ruleset registries",
		options = { required = true },
		failure_message = "Failed to load required multiplayer mode and ruleset registries.",
	},
	{
		kind = "files",
		paths = UI_BOUNDARY_FILES,
		label = "UI boundary surfaces",
		options = { required = true },
		failure_message = "Failed to load required multiplayer UI boundary surfaces.",
	},
	{
		kind = "files",
		paths = CONTENT_ADAPTER_FILES,
		label = "Content adapter surfaces",
		options = { required = true },
		failure_message = "Failed to load required multiplayer content adapter surfaces.",
	},
	{ kind = "side_effect", fn = load_weekly_ruleset },
	{
		kind = "dirs",
		paths = OBJECT_DIRECTORIES,
		recursive = false,
		label = "Gameplay objects",
		options = { required = true },
		failure_message = "Failed to load required multiplayer gameplay objects.",
	},
	{ kind = "call", fn = load_testing_tools },
}

local NETWORKING_STARTUP_STEPS = {
	{
		kind = "file",
		path = "multiplayer/runtime/network_transport_runtime.lua",
		options = { required = true },
		failure_message = "Failed to load required multiplayer networking bootstrap.",
	},
	{
		kind = "call",
		fn = function()
			return type(MP.NETWORKING_INTERNAL.install_runtime_loop) == "function"
		end,
		failure_message = "Missing required multiplayer runtime loop installer.",
	},
	{
		kind = "side_effect",
		fn = function()
			MP.NETWORKING_INTERNAL.install_runtime_loop()
		end,
	},
	{
		kind = "call",
		fn = function()
			return type(MP.NETWORKING_INTERNAL.start_networking) == "function"
		end,
		failure_message = "Missing required multiplayer networking starter.",
	},
	{
		kind = "call",
		fn = function()
			return MP.NETWORKING_INTERNAL.start_networking() ~= false
		end,
		failure_message = "Failed to start multiplayer networking.",
	},
}

local function load_core_bootstrap_phase()
	return run_bootstrap_phase_steps(CORE_BOOTSTRAP_STEPS)
end

local function load_networking_definition_phase()
	return run_bootstrap_phase_steps(NETWORKING_DEFINITION_STEPS)
end

local function load_content_bootstrap_phase()
	return run_bootstrap_phase_steps(CONTENT_BOOTSTRAP_STEPS)
end

local function start_networking_bootstrap_phase()
	return run_bootstrap_phase_steps(NETWORKING_STARTUP_STEPS)
end

function MP.bootstrap_startup()
	if not platform_loader or not bootstrap_map then
		abort_bootstrap("Multiplayer platform bootstrap map is unavailable.")
		return
	end
	if not load_core_bootstrap_phase() then
		return
	end
	if not load_networking_definition_phase() then
		return
	end
	if not load_content_bootstrap_phase() then
		return
	end
	if not start_networking_bootstrap_phase() then
		return
	end
end
