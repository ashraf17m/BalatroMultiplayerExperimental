local RESUME_APPLY = {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}
local teams_domain = MP.DOMAIN and MP.DOMAIN.TEAMS or {}

local DEFERRED_SHOP_CARD_AREAS = {
	shop_jokers = { load_field = "load_shop_jokers" },
	shop_booster = { load_field = "load_shop_booster" },
	shop_vouchers = { load_field = "load_shop_vouchers" },
}

local RESUME_START_RUN_LOG_DEFERRED_SHOP_AREAS = {
	["ERROR LOADING GAME: Card area 'shop_jokers' not instantiated before load"] = "shop_jokers",
	["ERROR LOADING GAME: Card area 'shop_booster' not instantiated before load"] = "shop_booster",
	["ERROR LOADING GAME: Card area 'shop_vouchers' not instantiated before load"] = "shop_vouchers",
}

local build_traceback = MP.UTILS.build_traceback
local deferred_shop_card_areas = {}
local deferred_shop_card_area_pending_noted = {}

local function trace_resume_event(event, fields)
	if MP.UTILS and MP.UTILS.trace_runtime_event then
		MP.UTILS.trace_runtime_event(event, fields)
	end
end

local function get_balatro_root()
	if BALATRO.get_root then
		return BALATRO.get_root()
	end

	return G
end

local function repair_scoring_calculation(game_state)
	if type(game_state) ~= "table" then
		return
	end

	local scoring_calculation = game_state.current_scoring_calculation
	if type(scoring_calculation) == "table" and scoring_calculation.func == nil then
		local key = scoring_calculation.key or "multiply"
		local definitions = MP.PLATFORM.SMODS.get_scoring_calculation_definitions()
		local definition = definitions and definitions[key]

		if definition and definition.load then
			game_state.current_scoring_calculation = definition:load(scoring_calculation)
		elseif definition and definition.new then
			game_state.current_scoring_calculation = definition:new(scoring_calculation)
		else
			game_state.current_scoring_calculation = nil
			sendWarnMessage(
				"Missing scoring calculation definition for saved resume state: " .. tostring(key),
				"MULTIPLAYER"
			)
		end
	end
end

local function refresh_resumed_team_shared_score()
	if not MP.GAME then
		return
	end

	if teams_domain.recalculate_state then
		teams_domain.recalculate_state()
	end

	local is_cooperative_shared_score = (teams_domain.is_cooperative_blind and teams_domain.is_cooperative_blind())
		or (MP.is_coop_blind and MP.is_coop_blind())

	if is_cooperative_shared_score then
		if match_domain.set_shared_score_text then
			match_domain.set_shared_score_text(MP.GAME.team_score_text or MP.GAME.shared_score_text or "0")
		end
		if BALATRO.get_hud and BALATRO.get_hud() and MP.UI and MP.UI.hide_enemy_location then
			local chip_UI = BALATRO.get_hud_element_by_id and BALATRO.get_hud_element_by_id("chip_UI_count")
			if not (chip_UI and chip_UI.config and chip_UI.config.func == "mp_shared_chip_UI_set") then
				MP.UI.hide_enemy_location()
			end
		end
		if MP.UI and MP.UI.request_shared_score_refresh then
			MP.UI.request_shared_score_refresh()
		end
	end
end

local function reapply_post_resume_multiplayer_blind_ui()
	if not (MP.UI and MP.UI.reapply_active_multiplayer_blind_ui) then
		return false
	end

	local ui_reapplied = MP.UI.reapply_active_multiplayer_blind_ui()
	if ui_reapplied then
		refresh_resumed_team_shared_score()
		return true
	end

	if BALATRO.queue_event then
		BALATRO.queue_event({
			trigger = "after",
			delay = 0.2,
			blockable = false,
			func = function()
				if MP.UI and MP.UI.reapply_active_multiplayer_blind_ui then
					MP.UI.reapply_active_multiplayer_blind_ui()
				end
				refresh_resumed_team_shared_score()
				return true
			end,
		})
		return true
	end

	return false
end

function RESUME_APPLY.repair_saved_run_snapshot(saved_run_snapshot)
	if type(saved_run_snapshot) ~= "table" then
		return
	end

	if type(saved_run_snapshot.SCORING_CALC) ~= "table" then
		local game_state = saved_run_snapshot.GAME or {}
		local scoring_calculation = game_state.current_scoring_calculation
		saved_run_snapshot.SCORING_CALC = {
			key = (type(scoring_calculation) == "table" and scoring_calculation.key) or "multiply",
			config = (type(scoring_calculation) == "table" and scoring_calculation.config) or {},
		}
	end

	repair_scoring_calculation(saved_run_snapshot.GAME)
end

function RESUME_APPLY.record_deferred_shop_area(area_key)
	if type(area_key) ~= "string" or not DEFERRED_SHOP_CARD_AREAS[area_key] then
		return false
	end

	deferred_shop_card_areas[area_key] = true
	deferred_shop_card_area_pending_noted[area_key] = nil
	trace_resume_event("resume.deferred_shop_area", { area = area_key })
	return true
end

function RESUME_APPLY.run_with_start_run_log_filter(fn)
	local print_ref = print
	if type(print_ref) ~= "function" then
		return fn()
	end

	-- luacheck: push ignore 121
	print = function(...)
		local first = select(1, ...)
		local deferred_shop_area = RESUME_START_RUN_LOG_DEFERRED_SHOP_AREAS[tostring(first)]
		if deferred_shop_area then
			RESUME_APPLY.record_deferred_shop_area(deferred_shop_area)
			if sendTraceMessage then
				sendTraceMessage("Resume deferred vanilla shop card area: " .. deferred_shop_area, "MULTIPLAYER")
			end
			return
		end

		return print_ref(...)
	end

	local ok, result = xpcall(fn, build_traceback)

	print = print_ref
	-- luacheck: pop

	if not ok then
		error(result, 0)
	end

	return result
end

function RESUME_APPLY.validate_deferred_shop_loads(context)
	local root = get_balatro_root()
	if not root then
		return false
	end

	local had_deferred_area = false
	for area_key, _ in pairs(deferred_shop_card_areas) do
		local spec = DEFERRED_SHOP_CARD_AREAS[area_key]
		local deferred_value = spec and root[spec.load_field] or nil
		had_deferred_area = true

		if deferred_value == nil then
			deferred_shop_card_areas[area_key] = nil
			deferred_shop_card_area_pending_noted[area_key] = nil
			trace_resume_event("resume.deferred_shop_area_consumed", {
				area = area_key,
				context = context or "unknown",
			})
		elseif root[area_key] ~= nil then
			if not deferred_shop_card_area_pending_noted[area_key] then
				deferred_shop_card_area_pending_noted[area_key] = true
				trace_resume_event("resume.deferred_shop_area_waiting", {
					area = area_key,
					context = context or "unknown",
				})
			end
		end
	end

	return had_deferred_area
end

function RESUME_APPLY.repair_post_resume_run_state()
	local game = BALATRO.get_game and BALATRO.get_game() or nil
	if not game then
		return
	end

	repair_scoring_calculation(game)

	if MP.UI and MP.UI.refresh_timer_hud_binding then
		MP.UI.refresh_timer_hud_binding()
	end
	if MP.UI and MP.UI.refresh_lives_hud_binding then
		MP.UI.refresh_lives_hud_binding()
	end

	if
		MP.PLATFORM.SMODS.refresh_score_ui_list
		and BALATRO.get_hud
		and BALATRO.get_hud()
		and BALATRO.call_ui_function
	then
		local hand_text_area = BALATRO.get_hud_element_by_id("hand_text_area")
		local operator_container = BALATRO.get_hud_element_by_id("hand_operator_container")

		if hand_text_area then
			BALATRO.call_ui_function("SMODS_scoring_calculation_function", hand_text_area)
		end
		if operator_container then
			BALATRO.recalculate_ui(operator_container)
		end

		MP.PLATFORM.SMODS.refresh_score_ui_list()
	end
end

function RESUME_APPLY.clear_resume_main_menu_ui()
	BALATRO.clear_main_menu_ui()
end

function RESUME_APPLY.apply_resumed_multiplayer_session_state(queued_resume)
	if match_domain.reset_state then
		match_domain.reset_state()
	end

	if MP.RESUME and MP.RESUME.apply_saved_mp_state then
		MP.RESUME.apply_saved_mp_state(queued_resume and queued_resume.mp_state or {})
	end

	if MP.NETWORKING_INTERNAL and MP.NETWORKING_INTERNAL.restore_local_ante_timer_state then
		MP.NETWORKING_INTERNAL.restore_local_ante_timer_state(MP.GAME.timer, MP.GAME.timer_started)
	end

	if MP.NETWORKING_INTERNAL and MP.NETWORKING_INTERNAL.sync_resume_enemies_from_lobby then
		MP.NETWORKING_INTERNAL.sync_resume_enemies_from_lobby()
	end

	if MP.RESUME and MP.RESUME.flush_runtime_match_sync_buffer then
		MP.RESUME.flush_runtime_match_sync_buffer()
	end

	if MP.OPPONENTS and MP.OPPONENTS.refresh_primary_enemy_view then
		MP.OPPONENTS.refresh_primary_enemy_view()
	end
end

function RESUME_APPLY.repair_post_resume_ui_state()
	if MP.RESUME and MP.RESUME.repair_post_resume_run_state then
		MP.RESUME.repair_post_resume_run_state()
	end

	refresh_resumed_team_shared_score()
	reapply_post_resume_multiplayer_blind_ui()

	if MP.RESUME and MP.RESUME.request_current_match_snapshot then
		MP.RESUME.request_current_match_snapshot()
	end
end

return RESUME_APPLY
