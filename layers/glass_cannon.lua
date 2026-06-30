local GLASS_CANNON_HANDS = 2
local GLASS_CANNON_XMULT = 4

local function install_glass_cannon_back_patch()
	if MP._glass_cannon_back_patch_installed then
		return
	end
	if not (Back and type(Back.trigger_effect) == "function") then
		return
	end

	MP._glass_cannon_back_patch_installed = true
	local back_trigger_effect_ref = Back.trigger_effect

	function Back:trigger_effect(args)
		local nu_chip, nu_mult = back_trigger_effect_ref(self, args)
		if args and args.context == "final_scoring_step" and MP.is_layer_active("glass_cannon") then
			local base_mult = nu_mult or args.mult
			return nu_chip, base_mult * GLASS_CANNON_XMULT
		end
		return nu_chip, nu_mult
	end
end

MP.Layer("glass_cannon", {
	starting_params = { hands = GLASS_CANNON_HANDS },
	on_apply_bans = install_glass_cannon_back_patch,
})

install_glass_cannon_back_patch()
