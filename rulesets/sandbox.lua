MP.SANDBOX = {}

local VANILLA_KEY_OVERRIDES = {
	j_mp_golden_ticket_sandbox = "j_ticket",
	j_mp_idol_sandbox_zealot = "j_idol",
	j_mp_idol_sandbox_collector = "j_idol",
	j_mp_magnet_sandbox = false,
}

local function vanilla_key_for_sandbox(sandbox_key)
	local override = VANILLA_KEY_OVERRIDES[sandbox_key]
	if override ~= nil then
		return override or nil
	end

	return sandbox_key:gsub("^j_mp_", "j_"):gsub("_sandbox$", "")
end

local function sandbox_joker_mapping(sandbox_key, active, group)
	return {
		sandbox = sandbox_key,
		vanilla = vanilla_key_for_sandbox(sandbox_key),
		active = active,
		group = group,
	}
end

local function append_sandbox_joker_mappings(sandbox_keys, active, group)
	for _, sandbox_key in ipairs(sandbox_keys) do
		MP.SANDBOX.joker_mappings[#MP.SANDBOX.joker_mappings + 1] = sandbox_joker_mapping(sandbox_key, active, group)
	end
end

local function copy_shallow(source)
	local copy = {}
	for key, value in pairs(source or {}) do
		copy[key] = value
	end
	return copy
end

local ACTIVE_SANDBOX_JOKERS = {
	"j_mp_misprint_sandbox",
	"j_mp_castle_sandbox",
	"j_mp_mail_sandbox",
	"j_mp_square_sandbox",
	"j_mp_throwback_sandbox",
	"j_mp_vampire_sandbox",
	"j_mp_steel_joker_sandbox",
	"j_mp_baseball_sandbox",
	"j_mp_hit_the_road_sandbox",
	"j_mp_golden_ticket_sandbox",
	"j_mp_idol_sandbox_zealot",
	"j_mp_idol_sandbox_collector",
}

local INACTIVE_SANDBOX_JOKERS = {
	"j_mp_bloodstone_sandbox",
	"j_mp_cloud_9_sandbox",
	"j_mp_constellation_sandbox",
	"j_mp_faceless_sandbox",
	"j_mp_juggler_sandbox",
	"j_mp_loyalty_card_sandbox",
	"j_mp_lucky_cat_sandbox",
	"j_mp_magnet_sandbox",
	"j_mp_order_sandbox",
	"j_mp_photograph_sandbox",
	"j_mp_ride_the_bus_sandbox",
	"j_mp_runner_sandbox",
	"j_mp_satellite_sandbox",
}

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

-- Centralized joker mappings: defines sandbox variants, their vanilla counterparts, and rotation status
MP.SANDBOX.joker_mappings = {}
append_sandbox_joker_mappings(ACTIVE_SANDBOX_JOKERS, true)
append_sandbox_joker_mappings(INACTIVE_SANDBOX_JOKERS, false)
append_sandbox_joker_mappings(EXTRA_CREDIT_SANDBOX_JOKERS, true, "extra_credit")

--- Returns list of unique vanilla joker keys to ban
--- @return table List of vanilla joker keys to silently ban
local function get_vanilla_bans()
	local bans = {}
	local seen = {}
	for _, mapping in ipairs(MP.SANDBOX.joker_mappings) do
		if mapping.active and mapping.vanilla and not seen[mapping.vanilla] then
			table.insert(bans, mapping.vanilla)
			seen[mapping.vanilla] = true
		end
	end
	return bans
end

--- Centralized allowlist check for sandbox jokers
--- @param joker_key string The key of the joker to check (e.g., "j_mp_mail_sandbox")
--- @return boolean true if the joker is allowed in the sandbox ruleset and in a multiplayer lobby
function MP.SANDBOX.is_joker_allowed(joker_key)
	if not MP.is_ruleset_active("sandbox") then return false end

	for _, mapping in ipairs(MP.SANDBOX.joker_mappings) do
		if mapping.active and mapping.sandbox == joker_key then return true end
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

MP.Ruleset(MP.UTILS.with_empty_content_lists({
	key = "sandbox",
	selection_group_key = "k_matchmaking",
	selection_group_order = 1,
	selection_order = 4,
	multiplayer_content = true,
	banned_jokers = { "j_hanging_chad" },
	banned_silent = get_vanilla_bans(),
	banned_consumables = { "c_ouija", "c_ectoplasm" },
	banned_tags = { "tag_rare", "tag_juggle", "tag_investment" },

	-- Shuffle reworked jokers to randomize the overview panel order
	-- Only show extra_credit jokers + idol jokers + error jokers in overview (hide other sandbox jokers)
	reworked_jokers = (function()
		local jokers = {}
		local idol_jokers = {}

		-- Collect extra_credit and idol jokers separately
		for _, mapping in ipairs(MP.SANDBOX.joker_mappings) do
			if mapping.active then
				if mapping.group == "extra_credit" then
					table.insert(jokers, mapping.sandbox)
				elseif mapping.sandbox:find("idol") then
					table.insert(idol_jokers, mapping.sandbox)
				end
			end
		end

		-- Add error jokers (for overview only, not in actual pool)
		for i = 1, 14 do
			table.insert(jokers, "j_mp_error_sandbox_" .. i)
		end

		-- final vanilla stuff
		table.insert(jokers, "j_mp_hanging_chad")

		-- Fisher-Yates shuffle
		for i = #jokers, 2, -1 do
			local j = math.random(1, i)
			jokers[i], jokers[j] = jokers[j], jokers[i]
		end

		-- Insert idol jokers in the middle
		local middle = math.floor(#jokers / 2) + 1
		for i, idol in ipairs(idol_jokers) do
			table.insert(jokers, middle + i - 1, idol)
		end

		return jokers
	end)(),
	reworked_consumables = { "c_mp_ouija_standard", "c_mp_ectoplasm_sandbox" },
	reworked_enhancements = { "m_mp_sandbox_display_glass" },
	reworked_tags = { "tag_mp_gambling_sandbox", "tag_mp_juggle_sandbox", "tag_mp_investment_sandbox" },

	create_info_menu = function()
		return MP.UI.CreateRulesetInfoMenu({
			multiplayer_content = true,
			forced_lobby_options = true,
			description_key = "k_sandbox_description",
		})
	end,

	forced_lobby_options = true,

	force_lobby_options = function(self)
		MP.LOBBY.config.preview_disabled = true
		MP.LOBBY.config.the_order = true
		MP.LOBBY.config.starting_lives = 4
		return true
	end,
})):inject()

--- Randomly selects one idol variant to be available in the sandbox ruleset
--- Bans the other two idol variants to ensure only one is available per game
--- Uses pseudorandom selection based on the lobby seed for consistency across players
--- @return nil
local function select_random_idol()
	local idol_keys = {
		"j_mp_idol_sandbox_zealot",
		"j_mp_idol_sandbox_collector",
	}
	table.sort(idol_keys)

	-- Pseudorandom shuffle using the lobby seed so all players get the same idol
	pseudoshuffle(idol_keys, pseudoseed("idol_selection_mp_sandbox"))

	-- Ban all idols except the first one (which is now randomly selected)
	for i = 2, #idol_keys do
		G.GAME.banned_keys[idol_keys[i]] = true
	end
end

MP.register_ruleset_ban_extension("sandbox", function()
	-- Apply sandbox-specific idol selection when in sandbox ruleset
	if MP.is_ruleset_active("sandbox") then
		select_random_idol()

		if SMODS.Mods["extracredit"] and SMODS.Mods["extracredit"].can_load then
			for _, mapping in ipairs(MP.SANDBOX.joker_mappings) do
				if mapping.group == "extra_credit" then G.GAME.banned_keys[mapping.sandbox] = true end
			end
		end
	end
end)

MP.sandbox_no_collection = not MP.EXPERIMENTAL.show_sandbox_collection
