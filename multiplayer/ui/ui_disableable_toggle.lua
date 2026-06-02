function MP.UI.Disableable_Toggle(args)
	local enabled = MP.UI.UTILS.resolve_enabled_flag(args)

	local toggle_component = create_toggle(args)
	local toggle_node = toggle_component.nodes[2].nodes[1].nodes[1]

	toggle_node.config.id = args.id
	toggle_node.config.button = enabled and "toggle_button" or nil
	toggle_node.config.button_dist = enabled and 0.2 or nil
	toggle_node.config.hover = enabled and true or false
	toggle_node.config.toggle_callback = enabled and args.callback or nil
	return toggle_component
end
