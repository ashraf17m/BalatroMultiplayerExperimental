local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

function G.UIDEF.confirmation_dialog()
	return create_UIBox_generic_options({
		back_func = "options",
		contents = {
			MP.UI.UTILS.create_row({ align = "cm", padding = 0 }, {
				MP.UI.UTILS.create_row({ align = "cm", padding = 0.5 }, {
					MP.UI.UTILS.create_text_node(localize("k_are_you_sure"), {
						scale = 0.6,
						colour = G.C.UI.TEXT_LIGHT,
					}),
				}),
				UIBox_button({
					label = { localize("k_yes") },
					button = "confirmation_dialog_yes",
					minw = 5,
				}),
			}),
		},
	})
end

do
	local confirm_selection_callback = nil

	BALATRO.set_ui_function("confirm_selection", function(callback)
		confirm_selection_callback = callback
		BALATRO.open_overlay_menu({
			definition = G.UIDEF.confirmation_dialog(),
		})
	end)

	BALATRO.set_ui_function("confirmation_dialog_yes", function()
		BALATRO.exit_overlay_menu()
		if confirm_selection_callback then
			confirm_selection_callback()
			confirm_selection_callback = nil
		end
	end)
end
