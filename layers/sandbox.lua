MP.SANDBOX = {}
local apply_sandbox_bans

local function copy_shallow(source)
	local copy = {}
	for key, value in pairs(source or {}) do
		copy[key] = value
	end
	return copy
end

local EXTRA_CREDIT_SANDBOX_JOKERS = {
	"j_mp_alloy_sandbox",
	"j_mp_ambrosia_sandbox",
	"j_mp_bobby_sandbox",
	"j_mp_candynecklace_sandbox",
	"j_mp_chainlightning_sandbox",
	"j_mp_clowncar_sandbox",
	"j_mp_clowncollege_sandbox",
	"j_mp_couponsheet_sandbox",
	"j_mp_doublerainbow_sandbox",
	"j_mp_espresso_sandbox",
	"j_mp_farmer_sandbox",
	"j_mp_forklift_sandbox",
	"j_mp_gofish_sandbox",
	"j_mp_hoarder_sandbox",
	"j_mp_jokalisa_sandbox",
	"j_mp_jokeroftheyear_sandbox",
	"j_mp_lucky7_sandbox",
	"j_mp_montehaul_sandbox",
	"j_mp_pocketaces_sandbox",
	"j_mp_pyromancer_sandbox",
	"j_mp_shipoftheseus_sandbox",
	"j_mp_starfruit_sandbox",
	"j_mp_trafficlight_sandbox",
	"j_mp_tuxedo_sandbox",
	"j_mp_warlock_sandbox",
	"j_mp_werewolf_sandbox",
}

MP.SANDBOX.joker_mappings = {}
for _, sandbox_key in ipairs(EXTRA_CREDIT_SANDBOX_JOKERS) do
	MP.SANDBOX.joker_mappings[#MP.SANDBOX.joker_mappings + 1] = {
		sandbox = sandbox_key,
		vanilla = nil,
		active = true,
		group = "extra_credit",
	}
end

function MP.SANDBOX.is_joker_allowed(joker_key)
	if not MP.is_layer_active("sandbox") then
		return false
	end

	for _, mapping in ipairs(MP.SANDBOX.joker_mappings) do
		if mapping.active and mapping.sandbox == joker_key then
			return true
		end
	end

	return false
end

function MP.SANDBOX.include_joker(self)
	return self and MP.SANDBOX.is_joker_allowed(self.key)
end

function MP.SANDBOX.register_joker(definition)
	local joker_definition = copy_shallow(definition)
	joker_definition.no_collection = MP.sandbox_no_collection
	joker_definition.unlocked = true
	joker_definition.discovered = true
	joker_definition.mp_include = joker_definition.mp_include or MP.SANDBOX.include_joker
	return SMODS.Joker(joker_definition)
end

function MP.SANDBOX.destroy_joker(card, drag_is)
	G.E_MANAGER:add_event(Event({
		func = function()
			play_sound("tarot1")
			card.T.r = -0.2
			card:juice_up(0.3, 0.4)
			card.states.drag.is = drag_is == true
			card.children.center.pinch.x = true
			G.E_MANAGER:add_event(Event({
				trigger = "after",
				delay = 0.3,
				blockable = false,
				func = function()
					G.jokers:remove_card(card)
					card:remove()
					card = nil
					return true
				end,
			}))
			return true
		end,
	}))
end

MP.Layer("sandbox", {
	multiplayer_content = true,
	banned_jokers = { "j_hanging_chad" },
	banned_silent = {},
	banned_consumables = { "c_ouija", "c_ectoplasm" },
	banned_tags = { "tag_rare", "tag_juggle", "tag_investment" },

	reworked_jokers = (function()
		local jokers = {}
		for _, mapping in ipairs(MP.SANDBOX.joker_mappings) do
			if mapping.active then
				jokers[#jokers + 1] = mapping.sandbox
			end
		end
		jokers[#jokers + 1] = "j_mp_hanging_chad"
		return jokers
	end)(),
	reworked_consumables = { "c_mp_ouija_standard", "c_mp_ectoplasm_sandbox" },
	reworked_enhancements = { "m_glass" },
	reworked_tags = { "tag_mp_gambling_sandbox", "tag_mp_juggle_sandbox", "tag_mp_investment_sandbox" },

	on_apply_bans = function()
		if apply_sandbox_bans then
			apply_sandbox_bans()
		end
	end,
})

apply_sandbox_bans = function()
	if not MP.is_layer_active("sandbox") then
		return
	end

	if SMODS.Mods["extracredit"] and SMODS.Mods["extracredit"].can_load then
		for _, mapping in ipairs(MP.SANDBOX.joker_mappings) do
			if mapping.group == "extra_credit" then
				G.GAME.banned_keys[mapping.sandbox] = true
			end
		end
	end
end

MP.sandbox_no_collection = MP.should_hide_sandbox_collection()
