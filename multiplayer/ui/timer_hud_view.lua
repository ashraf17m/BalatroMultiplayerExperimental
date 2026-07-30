local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function get_blind_choice_internal()
	return MP.BLIND_CHOICE_INTERNAL or {}
end

local function is_readying_pvp_blind()
	local blind_choice = get_blind_choice_internal()
	return blind_choice.is_readying_pvp_blind and blind_choice.is_readying_pvp_blind()
end

local function should_allow_pvp_timer_interaction()
	local blind_choice = get_blind_choice_internal()
	return blind_choice.is_pvp_timer_context and blind_choice.is_pvp_timer_context()
end

local function get_timer_value()
	if not (MP.GAME and MP.GAME.timer) then
		return 0
	end
	return math.max(0, tonumber(MP.GAME.timer) or 0)
end

local function is_timer_warning()
	return MP.GAME and MP.GAME.timer ~= nil and get_timer_value() < 10
end

local function get_low_timer_colour(default_colour)
	return is_timer_warning() and G.C.RED or default_colour
end

local function get_timer_display_ref()
	return setmetatable({}, {
		__index = function()
			return tostring(math.floor(get_timer_value()))
		end,
	})
end

local function get_local_score_int()
	if MP.GAME and MP.GAME.score_display then
		return MP.GAME.score_display
	end
	if MP.INSANE_INT and MP.INSANE_INT.from_string then
		return MP.INSANE_INT.from_string(tostring(MP.GAME and MP.GAME.score_text or "0"))
	end
	return nil
end

function MP.UI.cam_timer_opponent()
	if not (MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.timer) then
		return false
	end
	if get_timer_value() <= 0 then
		return false
	end

	if MP.is_pvp_boss and MP.is_pvp_boss() and MP.is_layer_active and MP.is_layer_active("pvp_timer") then
		local states = BALATRO.get_states and BALATRO.get_states() or nil
		local state = BALATRO.get_state and BALATRO.get_state() or nil
		if states and (state == states.ROUND_EVAL or state == states.NEW_ROUND) then
			return false
		end

		local local_score = get_local_score_int()
		local enemy_score = MP.GAME and MP.GAME.enemy and MP.GAME.enemy.score or nil
		if not (local_score and enemy_score and MP.INSANE_INT) then
			return false
		end
		if MP.INSANE_INT.greater_than(local_score, enemy_score) then
			return true
		end
		if MP.INSANE_INT.equal and MP.INSANE_INT.equal(local_score, enemy_score) then
			return not not MP.GAME.pvp_reached_first
		end
		return false
	end

	return not not (MP.GAME and MP.GAME.ready_blind)
end

BALATRO.set_ui_function("mp_timer_button", function(e)
	if not (MP.UI.cam_timer_opponent and MP.UI.cam_timer_opponent()) then
		return
	end
	if not MP.GAME.timer_started then
		MP.ACTIONS.start_ante_timer()
	else
		MP.ACTIONS.pause_ante_timer()
	end
end)

local function create_timer_count_dynatext(colours)
	return DynaText({
		string = MP.is_ruleset_active("speedlatro") and ">>" or {
			{
				ref_table = get_timer_display_ref(),
				ref_value = "timer",
			},
		},
		colours = colours or { G.C.UI.TEXT_DARK },
		shadow = true,
		scale = 0.8,
	})
end

function MP.UI.should_show_timer_hud()
	return not not (
		MP.LOBBY
		and MP.LOBBY.code
		and MP.LOBBY.config
		and MP.LOBBY.config.timer
	)
end

function MP.UI.timer_hud()
	if not (MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.timer) then
		return nil
	end

	return {
		n = G.UIT.C,
		config = {
			align = "cm",
			padding = 0.05,
			minw = 1.45,
			minh = 1,
			colour = G.C.DYN_UI.BOSS_MAIN,
			emboss = 0.05,
			r = 0.1,
		},
		nodes = {
			{
				n = G.UIT.R,
				config = { align = "cm", maxw = 1.35 },
				nodes = {
					{
						n = G.UIT.T,
						config = {
							text = localize("k_timer"),
							minh = 0.33,
							scale = 0.34,
							colour = G.C.UI.TEXT_LIGHT,
							shadow = true,
						},
					},
				},
			},
			{
				n = G.UIT.R,
				config = {
					align = "cm",
					r = 0.1,
					minw = 1.2,
					colour = G.C.DYN_UI.BOSS_DARK,
					id = "row_round_text",
					func = "set_timer_box",
					button = "mp_timer_button",
				},
				nodes = {
					{
						n = G.UIT.O,
						config = {
							object = create_timer_count_dynatext({ G.C.UI.TEXT_DARK }),
							id = "timer_UI_count",
						},
					},
				},
			},
		},
	}
end

function MP.UI.refresh_timer_hud_binding()
	if not (BALATRO.get_hud and BALATRO.get_hud_element_by_id) then
		return false
	end

	local timer_count = BALATRO.get_hud_element_by_id("timer_UI_count")
	if not (timer_count and timer_count.config) then
		return false
	end

	local current_colours = { G.C.UI.TEXT_DARK }
	local current_object = timer_count.config.object
	if current_object and current_object.colours and current_object.colours[1] then
		current_colours = current_object.colours
	end

	MP.UI.UTILS.replace_config_object(timer_count, create_timer_count_dynatext(current_colours), {
		recalculate_object = false,
		recalculate_ui_box = false,
	})

	local timer_box = BALATRO.get_hud_element_by_id("row_round_text")
	if timer_box and BALATRO.call_ui_function then
		BALATRO.call_ui_function("set_timer_box", timer_box)
	end

	BALATRO.recalculate_ui(BALATRO.get_hud and BALATRO.get_hud() or nil)

	return true
end

BALATRO.set_ui_function("set_timer_box", function(e)
	if not (MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.timer) then
		return
	end

	local allow_interaction = should_allow_pvp_timer_interaction()
	if MP.UI.cam_timer_opponent then
		allow_interaction = MP.UI.cam_timer_opponent()
	end
	e.config.button = allow_interaction and "mp_timer_button" or nil
	e.config.hover = nil
	e.config.outline_colour = nil

	if MP.GAME.timer_started or MP.GAME.nemesis_timer_started then
		e.config.colour = G.C.DYN_UI.BOSS_DARK
		e.children[1].config.object.colours = { get_low_timer_colour(G.C.IMPORTANT) }
		return
	end

	if allow_interaction or is_readying_pvp_blind() then
		e.config.colour = G.C.IMPORTANT
		e.children[1].config.object.colours = { G.C.UI.TEXT_LIGHT }
		return
	end

	e.config.colour = G.C.DYN_UI.BOSS_DARK
	e.children[1].config.object.colours = {
		(MP.is_layer_active and MP.is_layer_active("pressure_timer") and not (MP.is_pvp_boss and MP.is_pvp_boss()))
			and G.C.IMPORTANT
			or G.C.UI.TEXT_DARK,
	}
end)
