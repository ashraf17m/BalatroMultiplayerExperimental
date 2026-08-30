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
	self.mp_coop_base_chips = base_amount
	local scaled_amount = server_amount ~= nil and server_amount
		or MP.scale_coop_blind_amount and MP.scale_coop_blind_amount(base_amount)
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

MP.HOOKS.register_method_hook(Blind, "Blind", "defeat", "mp.blind_hud.reset_after_defeat", {
	after = function(ctx)
		BALATRO.queue_event({
			trigger = "after",
			delay = 0.5,
			func = function()
				if has_blind_hud_context() and MP.UI.reset_blind_HUD then
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
		if MP.SPECTATOR and MP.SPECTATOR.is_spectating then
			if MP.SPECTATOR.applying_snapshot then
				MP.SPECTATOR.hide_blind_loc_debuff = true
			else
				MP.SPECTATOR.hide_blind_loc_debuff = false
			end
		end
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
	if config.name == "blind1" and current_blind_key == "bl_mp_nemesis" and not (MP.SPECTATOR and MP.SPECTATOR.is_spectating) then
		local opponents = MP.OPPONENTS or {}
		local enemy_view = opponents.get_primary_enemy_state and opponents.get_primary_enemy_state()
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

-- Fix SMODS src/overrides.lua:46 crash (assert(G.HUD_blind == e.UIBox)) during profile switches / menu transitions
G.FUNCS = G.FUNCS or {}
G.FUNCS.HUD_blind_debuff = function(e)
	-- Spectators only see boss loc_debuff if they watched set_blind live.
	-- Switching onto a player who is already in the blind must not show it,
	-- and delayed HUD pop-in from snapshot set_blind must not stick it.
	if MP and MP.SPECTATOR and MP.SPECTATOR.is_spectating and MP.SPECTATOR.hide_blind_loc_debuff then
		if e and e.children then
			for i = 1, #e.children do
				local child = e.children[i]
				if child and child.states then
					child.states.visible = false
				end
			end
		end
		if e and e.config then
			e.config.minh = 0
			e.config.padding = 0
		end
		return
	end
	if not (G and G.GAME and G.GAME.blind and G.GAME.blind.loc_debuff_lines) then
		return
	end
	if not e or not e.UIBox or not e.children then
		return
	end
	local scale = 0.4
	local num_lines = #G.GAME.blind.loc_debuff_lines
	while num_lines > 0 and G.GAME.blind.loc_debuff_lines[num_lines] == "" do
		num_lines = num_lines - 1
	end
	local padding = 0.05
	if num_lines > 5 then
		local excess_height = (0.3 + padding) * (num_lines - 5)
		padding = padding - excess_height / (num_lines + 1)
	end
	e.config = e.config or {}
	e.config.padding = padding
	if G.GAME.blind.update_loc_debuff_lines then
		for i = 1, #e.children do
			if e.children[i] then
				e.children[i]:remove()
				e.children[i] = nil
			end
		end
		G.GAME.blind.update_loc_debuff_lines = nil
	end
	if num_lines > #e.children then
		for i = #e.children + 1, num_lines do
			local node_def = nil
			if type(G.GAME.blind.loc_debuff_lines[i]) == "string" then
				node_def = {
					n = G.UIT.R,
					config = { align = "cm", minh = 0.3, maxw = 4.2 },
					nodes = {
						{
							n = G.UIT.T,
							config = {
								ref_table = G.GAME.blind.loc_debuff_lines,
								ref_value = i,
								scale = scale * 0.9,
								colour = G.C.UI.TEXT_LIGHT,
							},
						},
					},
				}
			elseif SMODS and SMODS.localize_box then
				node_def = {
					n = G.UIT.R,
					config = { align = "cm", minh = 0.3, maxw = 4.2 },
					nodes = SMODS.localize_box(G.GAME.blind.loc_debuff_lines[i], {
						default_col = G.GAME.blind.loc_debuff_lines.text_colour or G.C.UI.TEXT_LIGHT,
						scale = 1.125 * (G.GAME.blind.loc_debuff_lines.scale or 1),
						vars = G.GAME.blind.loc_debuff_lines.vars or {},
					}),
				}
			end
			if node_def and e.UIBox and e.UIBox.set_parent_child then
				e.UIBox:set_parent_child(node_def, e)
			end
		end
	elseif num_lines < #e.children then
		for i = num_lines + 1, #e.children do
			if e.children[i] then
				e.children[i]:remove()
				e.children[i] = nil
			end
		end
	end
	if e.UIBox and e.UIBox.recalculate then
		e.UIBox:recalculate()
	end
end
