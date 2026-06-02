local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}

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

BALATRO.set_ui_function("mp_timer_button", function(e)
	if
		not should_allow_pvp_timer_interaction()
		or not is_readying_pvp_blind()
		or MP.GAME.timer <= 0
	then
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
		string = MP.is_ruleset_active("speedlatro") and ">>" or { { ref_table = MP.GAME, ref_value = "timer" } },
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
					hover = true,
					button_dist = 0.1,
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

function MP.UI.start_pvp_countdown(callback)
	local seconds = (MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.pvp_countdown_seconds) or 3
	if match_domain.begin_pvp_countdown then
		match_domain.begin_pvp_countdown(seconds)
	end

	BALATRO.set_controller_lock("enter_pvp", true)

	local function show_next()
		if MP.GAME.pvp_countdown <= 0 then
			if callback then callback() end
			BALATRO.queue_event({
				no_delete = true,
				trigger = "after",
				blocking = false,
				blockable = false,
				delay = 1,
				timer = "TOTAL",
				func = function()
					BALATRO.clear_controller_lock("enter_pvp")
					return true
				end,
			})
			return true
		end

		BALATRO.call_ui_function("attention_text_realtime", {
			text = tostring(MP.GAME.pvp_countdown),
			scale = 5,
			hold = 0.85,
			align = "cm",
			major = BALATRO.get_root and BALATRO.get_root() and BALATRO.get_root().play or nil,
			backdrop_colour = G.C.MULT,
		})

		BALATRO.play_sound("tarot2", 1, 0.4)

		if match_domain.tick_pvp_countdown then
			match_domain.tick_pvp_countdown()
		end

		BALATRO.queue_event({
			trigger = "after",
			timer = "REAL",
			delay = 1,
			blockable = false,
			func = show_next,
		})
		return true
	end

	BALATRO.queue_event({
		trigger = "after",
		timer = "REAL",
		delay = 0,
		blockable = false,
		func = show_next,
	})
end

BALATRO.set_ui_function("set_timer_box", function(e)
	if not MP.LOBBY.config.timer then
		return
	end

	local allow_interaction = should_allow_pvp_timer_interaction()
	e.config.button = allow_interaction and "mp_timer_button" or nil
	e.config.hover = allow_interaction

	local box_colour = G.C.DYN_UI.BOSS_DARK
	local text_colour = G.C.UI.TEXT_DARK
	if MP.GAME.timer_started then
		text_colour = G.C.IMPORTANT
	elseif is_readying_pvp_blind() then
		box_colour = G.C.IMPORTANT
		text_colour = G.C.UI.TEXT_LIGHT
	end
	e.config.colour = box_colour
	e.children[1].config.object.colours = { text_colour }
end)
