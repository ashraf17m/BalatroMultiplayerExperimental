MP.UI = MP.UI or {}
MP.UI.MAIN_MENU_SELECTION = MP.UI.MAIN_MENU_SELECTION or {}

local selection = MP.UI.MAIN_MENU_SELECTION
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function build_smallworld_toggle()
	local toggle_state = {
		val = MP.has_modifier and MP.has_modifier("smallworld") or false,
	}

	return create_toggle({
		id = "modifier_smallworld_toggle",
		label = localize("b_opts_modifier_smallworld"),
		ref_table = toggle_state,
		ref_value = "val",
		callback = function(new_val)
			if new_val then
				MP.add_modifier("smallworld")
			else
				MP.remove_modifier("smallworld")
			end
		end,
	})
end

local function build_modifier_entry(option_node, description_key)
	local message_table = localize(description_key)
	local result_text = {}
	for _, line in ipairs(message_table) do
		result_text[#result_text + 1] = {
			n = G.UIT.R,
			config = { minw = 8.5, maxw = 8.5 },
			nodes = SMODS.localize_box(loc_parse_string(line), {
				default_col = G.C.UI.TEXT_LIGHT,
			}),
		}
	end

	return {
		n = G.UIT.R,
		config = {
			padding = 0.25,
			align = "cm",
			r = 0.25,
			colour = { 1, 1, 1, 0.1 },
		},
		nodes = {
			{
				n = G.UIT.C,
				config = { minw = 5, align = "cm" },
				nodes = { option_node },
			},
			{
				n = G.UIT.C,
				config = { align = "cm" },
				nodes = result_text,
			},
		},
	}
end

function G.FUNCS.mp_return_to_ruleset_selection_from_modifiers()
	local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY or {}
	local ruleset_key = lobby_domain.get_creation_ruleset and lobby_domain.get_creation_ruleset()
		or MP.DEFAULT_LOBBY_CREATION_RULESET

	BALATRO.open_overlay_menu({
		definition = (G.UIDEF.ruleset_selection_tabs or G.UIDEF.ruleset_selection_options)(ruleset_key, {
			preserve_modifiers = true,
		}),
	})
end

function G.FUNCS.mp_open_modifiers_overlay(e)
	local ref_table = e and e.config and e.config.ref_table or {}
	local ruleset = ref_table.ruleset
	if not ruleset then
		return
	end
	local mode = ref_table.mode or (selection.get_ruleset_selection_mode and selection.get_ruleset_selection_mode()) or "lobby"
	local back_func = mode == "practice" and "mp_open_practice_options_overlay" or "mp_return_to_ruleset_selection_from_modifiers"

	local timer_cycle = MP.UI.build_timer_modifier_cycle and MP.UI.build_timer_modifier_cycle() or nil
	local pvp_timer_toggle = MP.UI.build_pvp_timer_toggle and MP.UI.build_pvp_timer_toggle() or nil
	local smallworld_toggle = build_smallworld_toggle()
	local modifier_nodes = {
		timer_cycle and build_modifier_entry(timer_cycle, "k_experimental_modifiers_timers") or nil,
		{ n = G.UIT.R, config = { minh = 0.25 } },
		pvp_timer_toggle and build_modifier_entry(pvp_timer_toggle, "k_experimental_modifiers_pvp_timer") or nil,
		{ n = G.UIT.R, config = { minh = 0.25 } },
		build_modifier_entry(smallworld_toggle, "k_experimental_modifiers_smallworld"),
	}

	BALATRO.open_overlay_menu({
		definition = create_UIBox_generic_options({
			back_func = back_func,
			contents = {
				{
					n = G.UIT.R,
					config = { align = "cm", padding = 0.25, colour = G.C.BLACK, r = 0.25 },
					nodes = {
						{
							n = G.UIT.R,
							nodes = modifier_nodes,
						},
						{ n = G.UIT.R },
						{
							n = G.UIT.R,
							config = { align = "cm" },
							nodes = {
								selection.build_ruleset_continue_button(ruleset, 5, mode),
							},
						},
					},
				},
			},
		}),
	})
end
