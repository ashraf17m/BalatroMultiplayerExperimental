MP.UI = MP.UI or {}
MP.UI.MAIN_MENU_SELECTION = MP.UI.MAIN_MENU_SELECTION or {}

local selection = MP.UI.MAIN_MENU_SELECTION
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function create_practice_ruleset_selection(options)
	options = options or {}
	options.mode = "practice"

	local builder = G.UIDEF.ruleset_selection_tabs or G.UIDEF.ruleset_selection_options
	return builder(MP.SP and MP.SP.ruleset or nil, options)
end

local function open_practice_ruleset_selection()
	BALATRO.open_overlay_menu({
		definition = create_practice_ruleset_selection({
			preserve_modifiers = true,
		}),
	})
end

local function build_practice_toggle(args)
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.05 },
		nodes = {
			MP.UI.Disableable_Toggle({
				id = args.id,
				label = localize(args.label),
				enabled_ref_table = { val = true },
				enabled_ref_value = "val",
				ref_table = MP.SP,
				ref_value = args.ref_value,
			}),
		},
	}
end

local function build_ghost_replay_button()
	local label = localize("k_ghost_replays")
	if MP.GHOST and MP.GHOST.is_active and MP.GHOST.is_active() then
		label = label .. " (" .. localize("k_active") .. ")"
	end

	return MP.UI.Disableable_Button({
		button = "open_ghost_replay_picker",
		align = "cm",
		padding = 0.05,
		r = 0.1,
		minw = 3.5,
		minh = 0.8,
		colour = (MP.GHOST and MP.GHOST.is_active and MP.GHOST.is_active()) and G.C.GREEN or G.C.BLUE,
		hover = true,
		shadow = true,
		label = { label },
		scale = 0.4,
		enabled_ref_table = { val = true },
		enabled_ref_value = "val",
	})
end

BALATRO.set_ui_function("setup_practice_mode", function()
	if MP.start_practice_mode then
		MP.start_practice_mode()
	end
	BALATRO.set_paused(true)
	BALATRO.open_overlay_menu({
		definition = create_practice_ruleset_selection(),
	})
end)

BALATRO.set_ui_function("start_practice_run", function(e)
	if not (MP.SP and MP.SP.ruleset) and MP.start_practice_mode then
		MP.start_practice_mode()
	end
	if MP.GHOST and MP.GHOST.is_active and MP.GHOST.is_active()
		and MP.GHOST.start_practice_run and MP.GHOST.start_practice_run(e) then
		return
	end
	BALATRO.exit_overlay_menu()
	BALATRO.call_ui_function("setup_run", e)
end)

BALATRO.set_ui_function("mp_return_to_practice_rulesets", function()
	open_practice_ruleset_selection()
end)

BALATRO.set_ui_function("mp_open_practice_options_overlay", function()
	local ruleset = MP.SP and MP.SP.ruleset and MP.Rulesets[MP.SP.ruleset] or nil
	if not ruleset and MP.set_practice_ruleset then
		local fallback_key = MP.set_practice_ruleset(MP.DEFAULT_LOBBY_CREATION_RULESET)
		ruleset = fallback_key and MP.Rulesets[fallback_key] or nil
	end
	if not ruleset then
		return
	end

	local rows = {
		build_practice_toggle({
			id = "practice_unlimited_slots_toggle",
			label = "k_unlimited_slots",
			ref_value = "unlimited_slots",
		}),
		build_practice_toggle({
			id = "practice_edition_cycling_toggle",
			label = "k_edition_cycling",
			ref_value = "edition_cycling",
		}),
	}

	local modifier_button = ruleset and selection.build_modifier_button
		and selection.build_modifier_button(ruleset, "practice")
		or nil
	if modifier_button then
		rows[#rows + 1] = {
			n = G.UIT.R,
			config = { align = "cm", padding = 0.15 },
			nodes = { modifier_button },
		}
	end

	rows[#rows + 1] = {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.15 },
		nodes = { build_ghost_replay_button() },
	}

	rows[#rows + 1] = {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.15 },
		nodes = {
			selection.build_ruleset_continue_button(ruleset, 5, "practice"),
		},
	}

	BALATRO.open_overlay_menu({
		definition = create_UIBox_generic_options({
			back_func = "mp_return_to_practice_rulesets",
			contents = {
				{
					n = G.UIT.R,
					config = { align = "cm", padding = 0.25, colour = G.C.BLACK, r = 0.25, minw = 6 },
					nodes = rows,
				},
			},
		}),
	})
end)
