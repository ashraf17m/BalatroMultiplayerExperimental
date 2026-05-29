local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function get_scaled_coop_blind_amount(blind)
	if not (MP.is_coop_blind and MP.is_coop_blind()) then
		return nil
	end

	local round_resets = G.GAME and G.GAME.round_resets or nil
	local starting_params = G.GAME and G.GAME.starting_params or nil
	if not (round_resets and starting_params and blind and blind.mult) then
		return nil
	end

	local blind_ante = round_resets.blind_ante or round_resets.ante
	if blind_ante == nil then
		return nil
	end

	local base_amount = get_blind_amount(blind_ante) * blind.mult * (starting_params.ante_scaling or 1)
	return MP.scale_coop_blind_amount and MP.scale_coop_blind_amount(base_amount) or base_amount
end

local function apply_coop_blind_score_scaling(self, blind)
	local scaled_amount = get_scaled_coop_blind_amount(blind or (self and self.config and self.config.blind))
	if not scaled_amount then
		return
	end

	local chip_text = number_format(scaled_amount)
	if BALATRO.set_current_blind_score and BALATRO.set_current_blind_score(scaled_amount, chip_text) then
		return
	end

	self.chips = scaled_amount
	self.chip_text = chip_text
end

MP.HOOKS.register_method_hook(Blind, "Blind", "draw", "mp.blind_hud.hide_floating_icon", {
	before = function(ctx, self)
		if self.hide_floating_icon then
			ctx.skip_original = true
			ctx.results = { n = 0 }
		end
	end,
})

MP.HOOKS.register_method_hook(Blind, "Blind", "defeat", "mp.blind_hud.reset_after_defeat", {
	after = function(ctx)
		BALATRO.queue_event({
			trigger = "after",
			delay = 0.5,
			func = function()
				if MP.LOBBY.code and MP.UI.reset_blind_HUD then
					MP.UI.reset_blind_HUD()
				end
				return true
			end,
		})
		ctx.results = { n = 0 }
	end,
})

local get_blind_main_colour_ref = get_blind_main_colour
function get_blind_main_colour(type)
	local blind_choices = BALATRO.get_blind_choices and BALATRO.get_blind_choices() or nil
	local is_pvp_blind = (blind_choices and blind_choices[type] == "bl_mp_nemesis") or type == "bl_mp_nemesis"
	if is_pvp_blind then
		type = MP.UTILS.get_pvp_blind_key()
	end

	return get_blind_main_colour_ref(type)
end

MP.HOOKS.register_method_hook(Blind, "Blind", "change_colour", "mp.blind_hud.nemesis_small_colour", {
	before = function(ctx, self)
		local small = false
		local blind_key = self and self.config and self.config.blind and self.config.blind.key or nil
		if blind_key == "bl_mp_nemesis" then
			local pvp_blind_key = MP.UTILS.get_pvp_blind_key()
			if pvp_blind_key == "bl_small" or pvp_blind_key == "bl_big" then
				small = true
			end
		end

		ctx.mp_blind_hud_original_boss = self.boss
		if small then
			self.boss = false
		end
	end,
	after = function(ctx, self)
		self.boss = ctx.mp_blind_hud_original_boss
		ctx.results = { n = 0 }
	end,
})

MP.HOOKS.register_method_hook(Blind, "Blind", "set_blind", "mp.blind_hud.nemesis_state", {
	after = function(ctx, self)
		local blind = ctx.args and ctx.args[1] or nil
		local blind_key = (blind and blind.key) or (self and self.name) or nil
		local is_pvp_blind = blind_key == "bl_mp_nemesis"
		if not is_pvp_blind then
			apply_coop_blind_score_scaling(self, blind)
			self.hide_floating_icon = false
			if MP.LOBBY.code and MP.UI.reset_blind_HUD then
				MP.UI.reset_blind_HUD()
			end
			ctx.results = { n = 0 }
			return
		end

		if (MP.is_ffa_mode and MP.is_ffa_mode()) or (MP.is_teams_mode and MP.is_teams_mode()) then
			if MP.UI.update_blind_HUD then
				MP.UI.update_blind_HUD()
			end
			self.hide_floating_icon = true
		end

		local boss = true
		local showdown = false
		local pvp_blind_key = MP.UTILS.get_pvp_blind_key()
		if pvp_blind_key == "bl_small" or pvp_blind_key == "bl_big" then
			boss = false
		end
		if pvp_blind_key == "bl_final_heart" then
			showdown = true
		end
		G.ARGS.spin.real = (G.SETTINGS.reduced_motion and 0 or 1) * (boss and (showdown and 0.5 or 0.25) or 0)
		ctx.results = { n = 0 }
	end,
})

local ease_background_colour_blind_ref = ease_background_colour_blind
function ease_background_colour_blind(state, blind_override)
	local current_blind = BALATRO.get_current_blind and BALATRO.get_current_blind() or nil
	local blind_name = blind_override or (current_blind and current_blind.name) or "Small Blind"
	blind_name = (blind_name == "" and "Small Blind" or blind_name)
	if blind_name == "bl_mp_nemesis" then
		blind_override = MP.UTILS.get_pvp_blind_key()
		for key, value in pairs(G.P_BLINDS) do
			if blind_override == key then
				blind_override = value.name
			end
		end
	end

	return ease_background_colour_blind_ref(state, blind_override)
end

local add_round_eval_row_ref = add_round_eval_row
function add_round_eval_row(config)
	local current_blind_key = BALATRO.get_current_blind_key and BALATRO.get_current_blind_key() or nil
	if config.name == "blind1" and current_blind_key == "bl_mp_nemesis" then
		local enemy_view = MP.get_primary_enemy_state and MP.get_primary_enemy_state()
		local current_blind = BALATRO.get_current_blind and BALATRO.get_current_blind() or nil
		if current_blind then
			current_blind.chip_text = MP.INSANE_INT.to_string(enemy_view and enemy_view.score or MP.INSANE_INT.empty())
			current_blind.pos = G.P_BLINDS[MP.UTILS.get_pvp_blind_key()].pos
		end

		G.P_BLINDS["bl_mp_nemesis"].atlas = "mp_player_blind_col"
		add_round_eval_row_ref(config)
		BALATRO.queue_event({
			trigger = "before",
			delay = 0.0,
			func = function()
				G.P_BLINDS["bl_mp_nemesis"].atlas = "mp_player_blind_chip"
				return true
			end,
		})
		return
	end

	add_round_eval_row_ref(config)
end

MP.HOOKS.register_method_hook(Blind, "Blind", "disable", "mp.blind_hud.pvp_disable_guard", {
	before = function(ctx)
		local current_blind = BALATRO.get_current_blind and BALATRO.get_current_blind() or nil
		if MP.is_pvp_boss() and not (current_blind and current_blind.name == "Verdant Leaf") then
			ctx.skip_original = true
			ctx.results = { n = 0 }
		end
	end,
	after = function(ctx)
		ctx.results = { n = 0 }
	end,
})
