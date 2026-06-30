-- Global values that must be present for the rest of this mod to work.

if not FN then FN = {} end

FN.PRE = {
	data = {
		score = { min = 0, exact = 0, max = 0 },
		dollars = { min = 0, exact = 0, max = 0 },
	},
	text = {
		score = { l = "", r = "" },
	},
	joker_order = {},
	hand_order = {},
	show_preview = false,
	lock_updates = false,
	on_startup = true,
}

-- The original calculator is loaded by a Lovely manifest, not by bootstrap/startup.lua.
-- This shared gate keeps the always-patched Preview files optional at runtime.
function FN.PRE.integration_enabled()
	return MP and MP.INTEGRATIONS and MP.INTEGRATIONS.Preview
end

function FN.PRE.is_preview_state()
	return G.STATE == G.STATES.SELECTING_HAND or G.STATE == G.STATES.DRAW_TO_HAND or G.STATE == G.STATES.PLAY_TAROT
end

local function is_current_pvp_blind()
	if MP and type(MP.is_pvp_boss) == "function" and MP.is_pvp_boss() then return true end

	local blind = BALATRO and BALATRO.get_current_blind and BALATRO.get_current_blind() or nil
	if not blind then return false end

	local blind_key = blind.config and blind.config.blind and blind.config.blind.key or blind.name
	return blind_key == "bl_mp_nemesis" or not not blind.pvp
end

function FN.PRE.start_calculation_event()
	if not FN.PRE.enabled() then return end

	FN.PRE.lock_updates = true
	FN.PRE.show_preview = true
	FN.PRE.add_update_event("immediate") -- Force UI refresh
	local is_pvp_blind = is_current_pvp_blind()
	local delay = 0
	if MP and MP.CALCULATOR and type(MP.CALCULATOR.calculation_start_delay) == "function" then
		delay = MP.CALCULATOR.calculation_start_delay(is_pvp_blind)
	elseif MP and MP.LOBBY and MP.LOBBY.code and not is_pvp_blind then
		delay = 3 * G.SETTINGS.GAMESPEED
	end
	local func = function()
		FN.PRE.simulate()
		if MP and MP.CALCULATOR and type(MP.CALCULATOR.consume_calculation_timer_cost) == "function" then
			MP.CALCULATOR.consume_calculation_timer_cost(is_pvp_blind, FN.PRE.data)
		end
		FN.PRE.lock_updates = false
		FN.PRE.show_preview = true
		FN.PRE.add_update_event("immediate") -- Refresh UI again
		return true
	end
	G.E_MANAGER:add_event(Event({ trigger = "after", blockable = false, blocking = false, delay = delay, func = func }))
end

FN.PRE._start_up = Game.start_up
function Game:start_up()
	FN.PRE._start_up(self)

	if not FN.PRE.integration_enabled() then return end

	if not G.SETTINGS.FN then G.SETTINGS.FN = {} end
	if not G.SETTINGS.FN.PRE then
		G.SETTINGS.FN.PRE = true

		G.SETTINGS.FN.preview_score = true
		G.SETTINGS.FN.preview_dollars = true
		G.SETTINGS.FN.hide_face_down = true
		G.SETTINGS.FN.show_min_max = true
	end
end
