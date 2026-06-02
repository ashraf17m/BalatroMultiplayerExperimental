local Disableable_Button = MP.UI.Disableable_Button
local MAIN_BUTTON_STATE = MP.UI.LOBBY_MAIN_BUTTON_STATE

local function create_lobby_main_disableable_button(text_scale, button_spec)
	return Disableable_Button({
		id = "lobby_menu_start",
		button = button_spec.button,
		colour = button_spec.colour,
		minw = 3.65,
		minh = 1.55,
		label = button_spec.label,
		disabled_text = button_spec.disabled_text,
		scale = text_scale * 2,
		col = true,
		enabled_ref_table = { enabled = button_spec.enabled },
		enabled_ref_value = "enabled",
	})
end

function MP.UI.lobby_status_display()
	local warnings = MP.UI.get_lobby_warnings and MP.UI.get_lobby_warnings() or { { " ", G.C.UI.TEXT_LIGHT } }

	local warning_texts = {}
	for k, v in pairs(warnings) do
		table.insert(
			warning_texts,
			MP.UI.UTILS.create_row({ align = "cm", padding = -0.25 }, {
				MP.UI.UTILS.create_text_node(v[1], {
					colour = v[2],
					scale = v[3] or 0.25,
				}),
			})
		)
	end

	return MP.UI.UTILS.create_row({ padding = 0.35, align = "cm" }, warning_texts)
end

-- Component for main start/ready button in lobby
function MP.UI.create_lobby_main_button(text_scale)
	local button_state = MAIN_BUTTON_STATE.get_state()

	if button_state.mode == "host_start" then
		return create_lobby_main_disableable_button(text_scale, {
			button = "lobby_start_game",
			colour = G.C.BLUE,
			label = { localize("b_start") },
			disabled_text = button_state.disabled_text,
			enabled = button_state.enabled,
		})
	end

	if button_state.mode == "guest_wait" then
		return create_lobby_main_disableable_button(text_scale, {
			button = "lobby_ready_up",
			colour = G.C.BLUE,
			label = button_state.disabled_text or { localize("b_wait_for_host_start") },
			disabled_text = button_state.disabled_text or localize("b_wait_for_host_start"),
			enabled = button_state.enabled,
		})
	end

	return UIBox_button({
		id = "lobby_menu_start",
		button = "lobby_ready_up",
		colour = button_state.is_ready and G.C.GREEN or G.C.RED,
		minw = 3.65,
		minh = 1.55,
		label = { button_state.is_ready and localize("b_unready") or localize("b_ready") },
		scale = text_scale * 2,
		col = true,
	})
end
