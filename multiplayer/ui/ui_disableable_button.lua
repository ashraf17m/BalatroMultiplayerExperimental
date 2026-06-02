local function normalize_button_label(label)
	if type(label) == "table" then
		return label
	end
	if label == nil then
		return {}
	end
	return { tostring(label) }
end

function MP.UI.Disableable_Button(args)
	local enabled = MP.UI.UTILS.resolve_enabled_flag(args)
	args.colour = args.colour or G.C.RED
	args.text_colour = args.text_colour or G.C.UI.TEXT_LIGHT
	args.disabled_text = args.disabled_text or args.label
	args.label = normalize_button_label(not enabled and args.disabled_text or args.label)

	local button_component = UIBox_button(args)
	local button_node = button_component.nodes[1]
	local text_node = button_node.nodes[1].nodes[1]

	button_node.config.button = enabled and args.button or nil
	button_node.config.hover = enabled
	button_node.config.shadow = enabled
	button_node.config.colour = enabled and args.colour or G.C.UI.BACKGROUND_INACTIVE
	text_node.colour = enabled and args.text_colour or G.C.UI.TEXT_INACTIVE
	text_node.shadow = enabled
	return button_component
end
