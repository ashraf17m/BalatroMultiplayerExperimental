local connection_resume = MP.CONNECTION_RESUME or {}
MP.CONNECTION_RESUME = connection_resume

local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end
local build_traceback = MP.UTILS.build_traceback

local function call_resume_method(method_name, ...)
	local method = MP.RESUME and MP.RESUME[method_name] or nil
	if method then
		return method(...)
	end

	return nil
end

for _, method_name in ipairs({
	"get_pending_manual_resume",
	"complete_manual_resume",
	"activate_runtime_match_sync_buffer",
	"fail_manual_resume",
	"refresh_saved_resume_metadata",
}) do
	local name = method_name
	connection_resume[method_name] = function(...)
		return call_resume_method(name, ...)
	end
end

local function build_resume_restore_traceback(step, err)
	local summary = string.format("Resume restore failed at step '%s': %s", tostring(step), tostring(err))
	return build_traceback(summary)
end

local function summarize_resume_restore_error(err)
	local error_text = tostring(err or "Unknown resume restore error.")
	local first_line = string.match(error_text, "([^\r\n]+)") or error_text

	local nested_summary = string.match(first_line, "Resume runtime failed at step '[^']+': .+$")
	if nested_summary then
		return nested_summary
	end

	return first_line
end

function connection_resume.resume_saved_match(pending_resume, code, token, player_id)
	trace_runtime_event("resume.restore_begin", {
		code = code,
		player_id = player_id,
		has_run_snapshot = pending_resume and pending_resume.run_snapshot ~= nil,
		has_meta_state = pending_resume and pending_resume.meta and pending_resume.meta.mp_state ~= nil,
	})
	local current_step = "refresh resume metadata"
	local ok, err = xpcall(function()
		if not connection_resume.refresh_saved_resume_metadata(token, code, player_id) then
			trace_runtime_event("resume.metadata_refresh_failed", {
				code = code,
				player_id = player_id,
			})
			sendWarnMessage("Failed to refresh saved resume metadata before restoring match.", "MULTIPLAYER")
		end
		current_step = "run resume bootstrap"
		if not (MP.NETWORKING_INTERNAL and MP.NETWORKING_INTERNAL.resume_match_runtime) then
			error("Missing multiplayer resume runtime handler.")
		end
		MP.NETWORKING_INTERNAL.resume_match_runtime(pending_resume.run_snapshot, pending_resume.meta and pending_resume.meta.mp_state)
	end, function(restore_err)
		return build_resume_restore_traceback(current_step, restore_err)
	end)

	if not ok then
		local concise_error = summarize_resume_restore_error(err)
		trace_runtime_event("resume.restore_failed", {
			code = code,
			step = current_step,
			error = concise_error,
		})
		connection_resume.fail_manual_resume(true)
		MP.CONNECTION_FEEDBACK.show_resume_restore_failed(concise_error, err)
		return false
	end

	connection_resume.complete_manual_resume()
	trace_runtime_event("resume.restore_complete", {
		code = code,
		player_id = player_id,
	})
	return true
end
