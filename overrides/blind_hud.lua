local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function has_blind_hud_context()
	return MP.LOBBY and MP.LOBBY.code
end

local function clear_coop_blind_base(self)
	if self then
		self.mp_coop_base_chips = nil
		self.mp_coop_scaled_chips = nil
	end
	if MP.GAME then
		MP.GAME.coop_blind_target_chips = nil
	end
end

local function get_server_coop_blind_amount()
	return MP.GAME and MP.GAME.coop_blind_server_target_chips or nil
end

local function to_score_number(value)
	if BALATRO.to_score_number then
		return BALATRO.to_score_number(value)
	end
	if type(value) == "number" then
		return value
	end
	if value == nil then
		return nil
	end
	return tonumber((string.gsub(tostring(value), ",", "")))
end

local function get_scaled_coop_blind_amount(self)
	if not (MP.is_coop_blind and MP.is_coop_blind()) then
		return nil
	end

	if not (self and self.chips ~= nil) then
		return nil
	end

	local server_amount = to_score_number(get_server_coop_blind_amount())
	local base_amount = to_score_number(self.mp_coop_base_chips) or to_score_number(self.chips)
	if base_amount == nil then
		return nil
	end
	if not self.mp_coop_base_chips then
		self.mp_coop_base_chips = base_amount
	end
	local current_ante = (G and G.GAME and G.GAME.round_resets and (G.GAME.round_resets.blind_ante or G.GAME.round_resets.ante)) or nil
	local blind_mult = self.config and self.config.blind and self.config.blind.mult or nil
	local scaled_amount = server_amount ~= nil and server_amount
		or MP.scale_coop_blind_amount and MP.scale_coop_blind_amount(base_amount, current_ante, blind_mult)
		or base_amount
	scaled_amount = to_score_number(scaled_amount)
	if scaled_amount == nil then
		return nil
	end
	self.mp_coop_scaled_chips = scaled_amount
	if MP.GAME then
		MP.GAME.coop_blind_target_chips = scaled_amount
	end
	return scaled_amount
end

local function apply_coop_blind_score_scaling(self)
	local scaled_amount = get_scaled_coop_blind_amount(self)
	if not scaled_amount then
		clear_coop_blind_base(self)
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

local get_blind_main_colour_ref = get_blind_main_colour
function get_blind_main_colour(type)
	local blind_choices = (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_choices or nil)
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

MP.HOOKS.register_method_hook(Blind, "Blind", "alert_debuff", "mp.spectator.skip_switch_debuff_alert", {
	before = function(ctx)
		-- Snapshot set_blind always calls alert_debuff (silent only skips juice).
		-- That queues the big "Face another player / boss effect" attention_text
		-- over the play area. Spectators must not see it on a target switch.
		if MP.SPECTATOR and MP.SPECTATOR.is_spectating and MP.SPECTATOR.applying_snapshot then
			ctx.skip_original = true
			ctx.results = { n = 0 }
		end
	end,
})

MP.HOOKS.register_method_hook(Blind, "Blind", "set_blind", "mp.blind_hud.nemesis_state", {
	after = function(ctx, self)
		local blind = ctx.args and ctx.args[1] or nil
		local reset = ctx.args and ctx.args[2] or nil
		local blind_key = (blind and blind.key) or (self and self.name) or nil
		local is_pvp_blind = blind_key == "bl_mp_nemesis"
		if not is_pvp_blind then
			if blind then
				if not reset or self.mp_coop_base_chips ~= nil then
					apply_coop_blind_score_scaling(self)
				end
			elseif not reset then
				clear_coop_blind_base(self)
			end
			self.hide_floating_icon = false
			if has_blind_hud_context() and MP.UI.reset_blind_HUD
				and not (MP.SPECTATOR and MP.SPECTATOR.applying_snapshot) then
				MP.UI.reset_blind_HUD()
			end
			ctx.results = { n = 0 }
			return
		end

		if is_pvp_blind then
			local is_bye = MP.is_duel_bye_blind and MP.is_duel_bye_blind()
			if is_bye then
				local ante = (G.GAME and G.GAME.round_resets and (G.GAME.round_resets.blind_ante or G.GAME.round_resets.ante)) or 1
				local mult = 2
				local scaling = (G.GAME and G.GAME.starting_params and G.GAME.starting_params.ante_scaling) or 1
				local get_amt = BALATRO.get_blind_amount or (type(get_blind_amount) == "function" and get_blind_amount)
				self.chips = (get_amt and get_amt(ante) or 300) * mult * scaling
				local num_fmt = number_format or (type(number_format) == "function" and number_format)
				self.chip_text = num_fmt and num_fmt(self.chips) or tostring(self.chips)
			elseif MP.UI and MP.UI.get_pvp_score_to_beat then
				local score_int, score_text = MP.UI.get_pvp_score_to_beat()
				if score_int then
					self.chips = (MP.INSANE_INT and MP.INSANE_INT.to_safe_number(score_int)) or 0
					self.chip_text = score_text or tostring(self.chips)
				end
			end
		end

		if
			(MP.is_ffa_mode and MP.is_ffa_mode())
			or (MP.is_duels_mode and MP.is_duels_mode())
			or (MP.is_teams_mode and MP.is_teams_mode())
		then
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
	local current_blind = (G and G.GAME and G.GAME.blind) or nil
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
	local current_blind = (G and G.GAME and G.GAME.blind) or nil
	local current_blind_key = current_blind and current_blind.config and current_blind.config.blind and current_blind.config.blind.key or current_blind and current_blind.name or nil
	if config.name == "blind1" and current_blind_key == "bl_mp_nemesis" and not (MP.SPECTATOR and MP.SPECTATOR.is_spectating) then
		local opponents = MP.OPPONENTS or {}
		local enemy_view = opponents.get_primary_enemy_state and opponents.get_primary_enemy_state()
		if current_blind then
			local score_text = nil
			if MP.UI and MP.UI.get_pvp_score_to_beat then
				local _, pvp_text = MP.UI.get_pvp_score_to_beat()
				if pvp_text and pvp_text ~= "" and pvp_text ~= "0" then
					score_text = pvp_text
				end
			end
			if not score_text and enemy_view then
				local etext = enemy_view.score_text or (MP.INSANE_INT and MP.INSANE_INT.to_string(enemy_view.score))
				if etext and etext ~= "" and etext ~= "0" then
					score_text = etext
				end
			end
			if score_text then
				current_blind.chip_text = score_text
			end

			local copy_fn = copy_table or function(t) local r = {} for k, v in pairs(t) do r[k] = v end return r end
			local pvp_blind_key = MP.UTILS and MP.UTILS.get_pvp_blind_key and MP.UTILS.get_pvp_blind_key() or "bl_small"
			if G.P_BLINDS and G.P_BLINDS[pvp_blind_key] then
				current_blind.pos = copy_fn(G.P_BLINDS[pvp_blind_key].pos)
			end
			if current_blind.config and current_blind.config.blind then
				current_blind.config.blind.atlas = "mp_player_blind_col"
			end
		end

		add_round_eval_row_ref(config)
		return
	end

	add_round_eval_row_ref(config)
end

MP.HOOKS.register_method_hook(Blind, "Blind", "disable", "mp.blind_hud.pvp_disable_guard", {
	before = function(ctx)
		local current_blind = (G and G.GAME and G.GAME.blind) or nil
		if MP.is_pvp_boss() and not (current_blind and current_blind.name == "Verdant Leaf") then
			ctx.skip_original = true
			ctx.results = { n = 0 }
		end
	end,
	after = function(ctx)
		ctx.results = { n = 0 }
	end,
})

G.FUNCS = G.FUNCS or {}
local hud_blind_debuff_ref = G.FUNCS.HUD_blind_debuff
G.FUNCS.HUD_blind_debuff = function(e)
	if MP.UI and MP.UI.using_standings_blind_hud and MP.UI.using_standings_blind_hud() then
		return
	end
	if not (e and e.UIBox and G.HUD_blind == e.UIBox) then
		return
	end
	if hud_blind_debuff_ref then
		return hud_blind_debuff_ref(e)
	end
end
