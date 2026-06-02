MP = MP or {}
if MP.MULTIPLAYER_EXPERIMENTAL_BOOTED then
	if sendWarnMessage then
		sendWarnMessage("Duplicate Multiplayer Experimental boot skipped.", "MULTIPLAYER")
	end
	return
end
MP.MULTIPLAYER_EXPERIMENTAL_BOOTED = true

MP.BOOT_MOD_ID = MP.BOOT_MOD_ID or "MultiplayerExperimental"

MP.GAME = MP.GAME or {}
MP.UI = MP.UI or {}
MP.ACTIONS = MP.ACTIONS or {}
MP.MOD_ACTIONS = MP.MOD_ACTIONS or {}
MP.LOBBY = MP.LOBBY or {
	code = nil,
	lobby_type = "",
	config = {},
	run_deck = {},
	client = {
		connected = false,
		username = "Guest",
		blind_col = 1,
		pending_lobby_ready = nil,
	},
	setup = {
		temp_code = "",
		temp_seed = "",
		creation_ruleset = "",
		creation_gamemode = "",
		fetched_weekly = nil,
		ruleset_preview = false,
		gamemode_preview = false,
	},
	players = {},
	is_host = false,
	match_in_progress = false,
}
MP.INTEGRATIONS = MP.INTEGRATIONS or {}
MP.CALCULATOR_LABELS = MP.CALCULATOR_LABELS or { text = "", button = "" }
MP.EXPERIMENTAL = MP.EXPERIMENTAL or {}

local function load_platform_loader()
	local chunk, err = SMODS.load_file("platform/smods/loader.lua", MP.BOOT_MOD_ID)
	if not chunk then
		sendWarnMessage(
			"Failed to load multiplayer bootstrap file: platform/smods/loader.lua (" .. tostring(err) .. ")",
			"MULTIPLAYER"
		)
		return nil
	end

	local ok, result = pcall(chunk)
	if ok then
		if result == nil then
			return true
		end

		return result
	end

	sendWarnMessage("Failed to process multiplayer bootstrap file: " .. tostring(result), "MULTIPLAYER")
	return nil
end

local platform_loader_bootstrap = load_platform_loader()
if platform_loader_bootstrap == nil then
	sendWarnMessage("Multiplayer bootstrap failed before startup initialization.", "MULTIPLAYER")
	return
end

if not (MP.PLATFORM and MP.PLATFORM.SMODS and MP.PLATFORM.SMODS.bootstrap_runtime) then
	sendWarnMessage("Multiplayer platform bootstrap is incomplete.", "MULTIPLAYER")
	return
end

if not MP.PLATFORM.SMODS.bootstrap_runtime() then
	sendWarnMessage("Multiplayer bootstrap failed before startup initialization.", "MULTIPLAYER")
	return
end

if MP.bootstrap_startup then
	MP.bootstrap_startup()
end
