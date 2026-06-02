local RESUME_SNAPSHOT = MP.RESUME or {}
MP.RESUME = RESUME_SNAPSHOT
local load_required_service = MP.UTILS.load_required_service

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

local function load_snapshot_module(path, required_methods, warning_message)
	local loaded = load_required_service(path, required_methods, warning_message, function()
		return MP.RESUME
	end)
	if not loaded then
		return false
	end

	RESUME_SNAPSHOT = loaded
	MP.RESUME = RESUME_SNAPSHOT
	return true
end

if
	not load_snapshot_module(
		"multiplayer/runtime/resume_snapshot_capture.lua",
		RESUME_SNAPSHOT_CAPTURE_METHODS,
		"Multiplayer resume snapshot capture helpers are missing."
	)
then
	return nil
end

if
	not load_snapshot_module(
		"multiplayer/runtime/resume_snapshot_manual_apply.lua",
		RESUME_SNAPSHOT_MANUAL_APPLY_METHODS,
		"Multiplayer resume snapshot manual-apply helpers are missing."
	)
then
	return nil
end

RESUME_SNAPSHOT._service_loaded = true

return RESUME_SNAPSHOT
