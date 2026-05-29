function MP.UI.Disableable_Toggle(args)
	local enabled = MP.UI.UTILS.resolve_enabled_flag(args)

	local toggle_component = create_toggle(args)
	toggle_component.nodes[2].nodes[1].nodes[1].config.id = args.id
	toggle_component.nodes[2].nodes[1].nodes[1].config.button = enabled and "toggle_button" or nil
	toggle_component.nodes[2].nodes[1].nodes[1].config.button_dist = enabled and 0.2 or nil
	toggle_component.nodes[2].nodes[1].nodes[1].config.hover = enabled and true or false
	toggle_component.nodes[2].nodes[1].nodes[1].config.toggle_callback = enabled and args.callback or nil
	return toggle_component
end
