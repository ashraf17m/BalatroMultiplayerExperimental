MP.Layer("bigger_shop", {
	on_apply_bans = function()
		if type(change_shop_size) == "function" then
			change_shop_size(1)
		end
	end,
})
