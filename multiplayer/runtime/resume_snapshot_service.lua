local RESUME_SNAPSHOT = MP.RESUME or {}
MP.RESUME = RESUME_SNAPSHOT
local has_required_methods = MP.UTILS.has_required_methods

local RESUME_SNAPSHOT_CAPTURE_METHODS = {
	"capture_current_match_snapshot",
	"request_current_match_snapshot",
	"update_pending_snapshot_capture",
}

local RESUME_SNAPSHOT_MANUAL_APPLY_METHODS = {
	"begin_manual_resume",
	"refresh_saved_resume_metadata",
	"apply_saved_mp_state",
}

local function ensure_snapshot_module(path, required_methods)
	if has_required_methods(RESUME_SNAPSHOT, required_methods) then
		return true
	end

	local loaded = MP.PLATFORM
		and MP.PLATFORM.SMODS
		and MP.PLATFORM.SMODS.load_mod_file
		and MP.PLATFORM.SMODS.load_mod_file(path, { required = true })

	if loaded == nil then
		return false
	end
	if type(loaded) == "table" then
		RESUME_SNAPSHOT = loaded
		MP.RESUME = RESUME_SNAPSHOT
	end

	return has_required_methods(RESUME_SNAPSHOT, required_methods)
end

if not ensure_snapshot_module("multiplayer/runtime/resume_snapshot_capture.lua", RESUME_SNAPSHOT_CAPTURE_METHODS) then
	sendWarnMessage("Multiplayer resume snapshot capture helpers are missing.", "MULTIPLAYER")
	return nil
end

if not ensure_snapshot_module("multiplayer/runtime/resume_snapshot_manual_apply.lua", RESUME_SNAPSHOT_MANUAL_APPLY_METHODS) then
	sendWarnMessage("Multiplayer resume snapshot manual-apply helpers are missing.", "MULTIPLAYER")
	return nil
end

RESUME_SNAPSHOT._service_loaded = true

return RESUME_SNAPSHOT
