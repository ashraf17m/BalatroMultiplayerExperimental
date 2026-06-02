function MP.UI.Disableable_Option_Cycle(args)
	local enabled = MP.UI.UTILS.resolve_enabled_flag(args)

	if not enabled then
		args.options = { args.options[args.current_option] }
		args.current_option = 1
	end

	return create_option_cycle(args)
end
