local resume_runtime = MP.RESUME or {}
MP.RESUME = resume_runtime
local has_required_methods = MP.UTILS.has_required_methods
local load_required_service = MP.UTILS.load_required_service

local RESUME_SNAPSHOT_METHODS = {
	"capture_current_match_snapshot",
	"request_current_match_snapshot",
	"update_pending_snapshot_capture",
	"has_saved_resume",
	"clear_saved_resume",
	"begin_manual_resume",
	"get_pending_manual_resume",
	"complete_manual_resume",
	"fail_manual_resume",
	"refresh_saved_resume_metadata",
	"apply_saved_mp_state",
}

local RESUME_SYNC_BUFFER_METHODS = {
	"queue_runtime_resume",
	"get_pending_team_card_restore",
	"activate_runtime_match_sync_buffer",
	"consume_runtime_resume",
	"is_resume_transition_active",
	"is_runtime_match_sync_buffer_active",
	"buffer_runtime_player_info",
	"buffer_runtime_money_update",
	"buffer_runtime_enemy_info",
	"buffer_runtime_enemy_location",
	"buffer_runtime_start_ante_timer",
	"buffer_runtime_pause_ante_timer",
	"buffer_runtime_team_card_sync",
	"buffer_runtime_team_hand_level_sync",
	"buffer_runtime_match_outcome",
	"flush_runtime_match_sync_buffer",
}

local RESUME_APPLY_FACADE_METHODS = {
	"repair_saved_run_snapshot",
	"repair_post_resume_run_state",
	"record_deferred_shop_area",
	"validate_deferred_shop_loads",
}

local RESUME_APPLY_REQUIRED_METHODS = {
	"repair_saved_run_snapshot",
	"repair_post_resume_run_state",
	"record_deferred_shop_area",
	"validate_deferred_shop_loads",
	"clear_resume_main_menu_ui",
	"apply_resumed_multiplayer_session_state",
	"repair_post_resume_ui_state",
}

local SERVICE_SPECS = {
	{
		name = "reconnect_domain",
		file_path = "multiplayer/domain/reconnect.lua",
		warning = "Multiplayer reconnect domain is missing.",
		required_methods = {
			"ensure_resume_runtime_state",
			"set_resume_transition_active",
		},
		resolve = function()
			local reconnect_domain = MP.DOMAIN and MP.DOMAIN.RECONNECT or nil
			if reconnect_domain and reconnect_domain.ensure_resume_runtime_state then
				return reconnect_domain
			end

			return nil
		end,
	},
	{
		name = "reconnect_persistence",
		file_path = "multiplayer/reconnect_persistence.lua",
		warning = "Multiplayer reconnect persistence is missing.",
		required_methods = {
			"save_resume_snapshots",
			"load_saved_resume_run_snapshot",
			"load_saved_resume_meta_snapshot",
			"has_saved_resume",
			"clear_saved_resume_files",
		},
		resolve = function()
			return MP.RECONNECT_PERSISTENCE or nil
		end,
	},
	{
		name = "resume_sync_buffer",
		file_path = "multiplayer/runtime/resume_sync_buffer.lua",
		warning = "Multiplayer resume sync buffer runtime is missing.",
		required_methods = RESUME_SYNC_BUFFER_METHODS,
	},
	{
		name = "resume_runtime_apply",
		file_path = "multiplayer/runtime/resume_runtime_apply.lua",
		warning = "Multiplayer resume runtime apply service is missing.",
		required_methods = RESUME_APPLY_REQUIRED_METHODS,
	},
	{
		name = "resume_snapshot_service",
		file_path = "multiplayer/runtime/resume_snapshot_service.lua",
		warning = "Multiplayer resume snapshot service is missing.",
		required_methods = RESUME_SNAPSHOT_METHODS,
	},
}

local services = {}
for _, spec in ipairs(SERVICE_SPECS) do
	services[spec.name] = load_required_service(spec.file_path, spec.required_methods, spec.warning, spec.resolve)
	if not services[spec.name] then
		return nil
	end
end

local reconnect_domain = services.reconnect_domain
local resume_sync_buffer = services.resume_sync_buffer
local resume_runtime_apply = services.resume_runtime_apply
local resume_snapshot_service = services.resume_snapshot_service

local function bind_runtime_facade_methods(service, method_names)
	if service == resume_runtime then
		return
	end

	for _, method_name in ipairs(method_names) do
		local name = method_name
		resume_runtime[name] = function(...)
			return service[name](...)
		end
	end
end

bind_runtime_facade_methods(resume_snapshot_service, RESUME_SNAPSHOT_METHODS)
bind_runtime_facade_methods(resume_sync_buffer, RESUME_SYNC_BUFFER_METHODS)
bind_runtime_facade_methods(resume_runtime_apply, RESUME_APPLY_FACADE_METHODS)

function resume_runtime.on_game_start_run(args)
	if not (args and args.mp_resume) then
		return
	end

	reconnect_domain.set_resume_transition_active(false)
	local queued_resume = resume_runtime.consume_runtime_resume and resume_runtime.consume_runtime_resume() or nil

	resume_runtime_apply.clear_resume_main_menu_ui()
	resume_runtime_apply.apply_resumed_multiplayer_session_state(queued_resume)
	resume_runtime_apply.repair_post_resume_ui_state()
end

return resume_runtime
