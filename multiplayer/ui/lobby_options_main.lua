local function create_main_lobby_options_title(info_area_id)
	local title_colour = mix_colours(G.C.RED, G.C.BLACK, 0.6)
	local title = "ERROR"

	if info_area_id == "ruleset_area" then
		title_colour = mix_colours(G.C.BLUE, G.C.BLACK, 0.6)
		title = localize("k_rulesets") or "ERROR"
	end

	if info_area_id == "gamemode_area" then
		title_colour = mix_colours(G.C.ORANGE, G.C.BLACK, 0.6)
		title = localize("k_gamemodes") or "ERROR"
	end

	if title == "ERROR" then return nil end

	return MP.UI.UTILS.create_row({ id = "ruleset_name", align = "cm", padding = 0.07 }, {
		MP.UI.UTILS.create_row({
			align = "cm",
			r = 0.1,
			outline = 1,
			outline_colour = title_colour,
			colour = darken(title_colour, 0.3),
			minw = 2.9,
			emboss = 0.1,
			padding = 0.07,
			line_emboss = 1,
		}, {
			MP.UI.UTILS.create_object_node(DynaText({
				string = { { string = title } },
				colours = { G.C.WHITE },
				float = true,
				y_offset = -4,
				scale = 0.45,
				maxw = 2.8,
			})),
		}),
	})
end

local function build_main_lobby_options_columns(info_area_id, default_info_area, button_func, buttons_data, selected_button_id)
	local categories = {
		create_main_lobby_options_title(info_area_id),
	}
	for cat_idx, category in ipairs(buttons_data) do
		local buttons = {}
		for btn_idx, data in ipairs(category.buttons) do
			local col = data.button_col or G.C.RED
			if data.button_id == "weekly_ruleset_button" then
				if (not MP.LOBBY.config.weekly) or (MP.LOBBY.config.weekly ~= MP.LOBBY.setup.fetched_weekly) then
					col = G.C.DARK_EDITION
				end
			end
			local button = UIBox_button({
				id = data.button_id,
				col = true,
				chosen = (
					(selected_button_id and data.button_id == selected_button_id)
					or (not selected_button_id and cat_idx == 1 and btn_idx == 1)
				) and "vert" or false,
				label = { localize(data.button_localize_key) },
				button = button_func,
				colour = col,
				minw = 4,
				scale = 0.4,
				minh = 0.6,
			})
			buttons[#buttons + 1] = MP.UI.UTILS.create_row({ align = "cm", padding = 0.05 }, { button })
		end
		categories[#categories + 1] = MP.UI.BackgroundGrouping(localize(category.name), buttons)
	end

	return {
		{ n = G.UIT.C, config = { align = "tm", minh = 8, minw = 4, padding = 0.1 }, nodes = categories },
		{
			n = G.UIT.C,
			config = { align = "cm", minh = 8, maxh = 8, minw = 11, maxw = 11 },
			nodes = {
				{ n = G.UIT.O, config = { id = info_area_id, object = default_info_area } },
			},
		},
	}
end

function MP.UI.Main_Lobby_Options(info_area_id, default_info_area, button_func, buttons_data, selected_button_id, args)
	args = args or {}
	local columns = build_main_lobby_options_columns(
		info_area_id,
		default_info_area,
		button_func,
		buttons_data,
		selected_button_id
	)

	if args.raw then
		return {
			n = G.UIT.ROOT,
			config = { colour = G.C.CLEAR },
			nodes = columns,
		}
	end

	return create_UIBox_generic_options({
		back_func = args.back_func or "play_options",
		contents = columns,
	})
end

function MP.UI.Change_Main_Lobby_Options(e, info_area_id, info_area_func, default_button_id, update_lobby_config_func)
	if not G.OVERLAY_MENU then return end

	local info_area = G.OVERLAY_MENU:get_UIE_by_ID(info_area_id)
	if not info_area then return end

	-- Switch 'chosen' status from the previously-chosen button to this one:
	if info_area.config.prev_chosen then
		info_area.config.prev_chosen.config.chosen = nil
	else -- The previously-chosen button should be the default one here:
		local default_button = G.OVERLAY_MENU:get_UIE_by_ID(default_button_id)
		if default_button then default_button.config.chosen = nil end
	end
	e.config.chosen = "vert" -- Special setting to show 'chosen' indicator on the side

	local info_obj_name = string.match(e.config.id, "(.+)_%w+_button")
	update_lobby_config_func(info_obj_name)

	MP.UI.UTILS.replace_config_object(info_area, UIBox({
		definition = info_area_func(info_obj_name),
		config = { align = "cm", parent = info_area },
	}), {
		recalculate_target = G.OVERLAY_MENU,
	})

	info_area.config.prev_chosen = e
end

function MP.UI.update_lobby_option_toggle(option_key)
	if G.OVERLAY_MENU and MP.LOBBY and MP.LOBBY.config then
		local config_uie = G.OVERLAY_MENU:get_UIE_by_ID(option_key .. "_toggle")
		local config = config_uie and config_uie.config or nil
		if config and config.ref_table and config.ref_value then
			config.ref_table[config.ref_value] = MP.LOBBY.config[option_key]
		end
	end
end

local function refresh_seed_options_in_place(options)
	if type(options) ~= "table" or (options.different_seeds == nil and options.custom_seed == nil) then
		return false
	end

	if MP.UI.refresh_custom_seed_controls then
		MP.UI.refresh_custom_seed_controls()
	end
	return true
end

function MP.UI.refresh_lobby_options_tab(options)
	if not (G.OVERLAY_MENU and G.OVERLAY_MENU:get_UIE_by_ID("lobby_options_overlay")) then
		return false
	end
	if refresh_seed_options_in_place(options) then
		return true
	end
	return false
end

function MP.UI.create_lobby_options_tab()
	return MP.UI.create_lobby_option_specs_page(MP.UI.LOBBY_OPTION_TAB_SPECS.options, 4)
end

function MP.UI.create_gameplay_options_tab()
	return MP.UI.create_lobby_option_specs_page(MP.UI.LOBBY_OPTION_TAB_SPECS.gameplay, 3)
end

function MP.UI.create_gamemode_modifiers_tab()
	return MP.UI.create_lobby_option_specs_page(MP.UI.LOBBY_OPTION_TAB_SPECS.modifiers, 6, {
		center_controls = true,
	})
end

function MP.UI.create_bonuses_options_tab()
	return MP.UI.create_lobby_option_specs_page(MP.UI.LOBBY_OPTION_TAB_SPECS.bonuses, 6, {
		center_controls = true,
	})
end
