local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

function G.FUNCS.attention_text_realtime(args)
	args = args or {}
	args.text = args.text or "test"
	args.scale = args.scale or 1
	args.colour = copy_table(args.colour or G.C.WHITE)
	args.hold = (args.hold or 0)
	args.pos = args.pos or { x = 0, y = 0 }
	args.align = args.align or "cm"

	args.fade = 1

	if args.cover then
		args.cover_colour = copy_table(args.cover_colour or G.C.RED)
		args.cover_colour_l = copy_table(lighten(args.cover_colour, 0.2))
		args.cover_colour_d = copy_table(darken(args.cover_colour, 0.2))
	else
		args.cover_colour = copy_table(G.C.CLEAR)
	end

	args.uibox_config = {
		align = args.align,
		offset = args.offset or { x = 0, y = 0 },
		major = args.cover or args.major or nil,
	}

	BALATRO.queue_event({
		trigger = "after",
		timer = "REAL",
		delay = 0,
		blockable = false,
		blocking = false,
		func = function()
			args.AT = UIBox({
				T = { args.pos.x, args.pos.y, 0, 0 },
				definition = {
					n = G.UIT.ROOT,
					config = {
						align = args.cover_align or "cm",
						minw = (args.cover and args.cover.T.w or 0.001) + (args.cover_padding or 0),
						minh = (args.cover and args.cover.T.h or 0.001) + (args.cover_padding or 0),
						padding = 0.03,
						r = 0.1,
						emboss = args.emboss,
						colour = args.cover_colour,
					},
					nodes = {
						{
							n = G.UIT.O,
							config = {
								draw_layer = 1,
								object = DynaText({
									scale = args.scale,
									string = args.text,
									maxw = args.maxw,
									colours = { args.colour },
									float = true,
									shadow = true,
									silent = not args.noisy,
									pop_in = 0,
									pop_in_rate = 6,
									rotate = args.rotate or nil,
								}),
							},
						},
					},
				},
				config = args.uibox_config,
			})
			args.AT.attention_text = true

			args.text = args.AT.UIRoot.children[1].config.object
			args.text:pulse(0.5)

			if args.cover then
				Particles(args.pos.x, args.pos.y, 0, 0, {
					timer_type = "TOTAL",
					timer = 0.01,
					pulse_max = 15,
					max = 0,
					scale = 0.3,
					vel_variation = 0.2,
					padding = 0.1,
					fill = true,
					lifespan = 0.5,
					speed = 2.5,
					attach = args.AT.UIRoot,
					colours = { args.cover_colour, args.cover_colour_l, args.cover_colour_d },
				})
			end
			if args.backdrop_colour then
				args.backdrop_colour = copy_table(args.backdrop_colour)
				Particles(args.pos.x, args.pos.y, 0, 0, {
					timer_type = "TOTAL",
					timer = 5,
					scale = 2.4 * (args.backdrop_scale or 1),
					lifespan = 5,
					speed = 0,
					attach = args.AT,
					colours = { args.backdrop_colour },
				})
			end
			return true
		end,
	})

	BALATRO.queue_event({
		trigger = "after",
		timer = "REAL",
		delay = args.hold,
		blockable = false,
		blocking = false,
		func = function()
			if not args.start_time then
				args.start_time = G.TIMERS.TOTAL
				args.text:pop_out(3)
			else
				args.fade = math.max(0, 1 - 3 * (G.TIMERS.TOTAL - args.start_time))
				if args.cover_colour then args.cover_colour[4] = math.min(args.cover_colour[4], 2 * args.fade) end
				if args.cover_colour_l then args.cover_colour_l[4] = math.min(args.cover_colour_l[4], args.fade) end
				if args.cover_colour_d then args.cover_colour_d[4] = math.min(args.cover_colour_d[4], args.fade) end
				if args.backdrop_colour then args.backdrop_colour[4] = math.min(args.backdrop_colour[4], args.fade) end
				args.colour[4] = math.min(args.colour[4], args.fade)
				if args.fade <= 0 then
					args.AT:remove()
					return true
				end
			end
		end,
	})
end

local function create_lives_hud_text()
	return DynaText({
		string = { { ref_table = MP.GAME, ref_value = "lives" } },
		colours = { G.C.IMPORTANT },
		shadow = true,
		font = G.LANGUAGES["en-us"].font,
		scale = 0.8,
	})
end

function MP.UI.refresh_lives_hud_binding(options)
	options = options or {}

	if
		not (
			MP
			and MP.GAME
			and G
			and G.HUD
			and G.HUD.get_UIE_by_ID
			and G.hand_text_area
			and DynaText
		)
	then
		return false
	end

	local hud_ante = G.HUD:get_UIE_by_ID("hud_ante")
	if not (hud_ante and hud_ante.children and hud_ante.children[1] and hud_ante.children[2]) then
		return false
	end

	local label_container = hud_ante.children[1].children
	local label = label_container and label_container[1]
	if label and label.config then
		label.config.text = localize("k_lives")
	end

	local value_container = hud_ante.children[2].children
	local lives_UI = value_container and value_container[1]
	if not (lives_UI and lives_UI.config) then
		return false
	end

	MP.UI.UTILS.replace_config_object(lives_UI, create_lives_hud_text(), {
		recalculate_object = false,
		recalculate_ui_box = false,
	})
	G.hand_text_area.ante = lives_UI

	value_container[2] = nil
	value_container[3] = nil
	value_container[4] = nil

	if options.recalculate ~= false and G.HUD.recalculate then
		G.HUD:recalculate()
	end

	return true
end

function MP.UI.ease_lives(mod)
	BALATRO.queue_event({
		trigger = "immediate",
		func = function()
			if not G.hand_text_area then return end

			if MP.LOBBY.config.disable_live_and_timer_hud then
				return true
			end

			if MP.UI.refresh_lives_hud_binding then
				MP.UI.refresh_lives_hud_binding({ recalculate = false })
			end

			local lives_UI = G.hand_text_area.ante
			if not (lives_UI and lives_UI.config and lives_UI.config.object) then return true end

			mod = mod or 0
			local text = "+"
			local col = G.C.IMPORTANT
			if mod < 0 then
				text = "-"
				col = G.C.RED
			end
			if lives_UI.config.object.update then
				lives_UI.config.object:update()
			end
			if G.HUD and G.HUD.recalculate then
				G.HUD:recalculate()
			end
			attention_text({
				text = text .. tostring(math.abs(mod)),
				scale = 1,
				hold = 0.7,
				cover = lives_UI.parent,
				cover_colour = col,
				align = "cm",
			})
			play_sound("highlight2", 0.685, 0.2)
			play_sound("generic1")
			return true
		end,
	})
end

function MP.UI.show_asteroid_hand_level_up()
	local hand_type = MP.PLATFORM.BALATRO.get_highest_level_poker_hand(function(key)
		return MP.PLATFORM.SMODS.is_poker_hand_visible(key)
	end)
	MP.PLATFORM.SMODS.upgrade_poker_hands({ hands = hand_type, level_up = -1 })
end
