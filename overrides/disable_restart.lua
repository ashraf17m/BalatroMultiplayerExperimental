MP.HOOKS.register_method_hook(Controller, "Controller", "key_hold_update", "mp.disable_restart.in_lobby", {
	before = function(ctx)
		if MP and MP.LOBBY and MP.LOBBY.code then
			ctx.skip_original = true
			ctx.results = { n = 0 }
		end
	end,
})
