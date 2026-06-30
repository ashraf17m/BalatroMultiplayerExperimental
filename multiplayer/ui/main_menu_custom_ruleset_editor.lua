MP.UI = MP.UI or {}
MP.CUSTOM = MP.CUSTOM or {}
G.FUNCS = G.FUNCS or {}

local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY or {}

local CONTENT_SETS = {
	{ label = "Vanilla", ruleset = "vanilla" },
	{ label = "Standard", ruleset = "standard_ranked" },
	{ label = "Standard (0.2)", ruleset = "legacy_ranked" },
	{ label = "Sandbox", ruleset = "sandbox" },
	{ label = "Experimental", ruleset = "experimental" },
}

local BAN_BUCKETS = {
	{ prefix = "j", field = "banned_jokers" },
	{ prefix = "c", field = "banned_consumables" },
	{ prefix = "v", field = "banned_vouchers" },
}

local function content_labels()
	local labels = {}
	for index, content in ipairs(CONTENT_SETS) do
		labels[index] = content.label
	end
	return labels
end

local function content_index_for_ruleset(ruleset, default)
	for index, content in ipairs(CONTENT_SETS) do
		if content.ruleset == ruleset or content.label == ruleset then
			return index
		end
	end
	return default or 2
end

local function get_draft_ruleset(draft)
	local content = CONTENT_SETS[content_index_for_ruleset(draft and draft.base, 2)]
	return content and content.ruleset or "standard_ranked"
end

function MP.CUSTOM.new_draft()
	return {
		name = "My Ruleset",
		base = "standard_ranked",
		banned_jokers = {},
		banned_consumables = {},
		banned_vouchers = {},
	}
end

MP.CUSTOM.draft = MP.CUSTOM.draft or nil

local function list_has(list, key)
	for _, value in ipairs(list or {}) do
		if value == key then
			return true
		end
	end
	return false
end

local function list_remove(list, key)
	for idx, value in ipairs(list or {}) do
		if value == key then
			table.remove(list, idx)
			return
		end
	end
end

local function copy_sequence(list)
	local copy = {}
	for _, value in ipairs(list or {}) do
		copy[#copy + 1] = tostring(value)
	end
	return copy
end

local function bucket_for(draft, set)
	if set == "Joker" then
		return draft.banned_jokers
	end
	if set == "Tarot" or set == "Planet" or set == "Spectral" then
		return draft.banned_consumables
	end
	if set == "Voucher" then
		return draft.banned_vouchers
	end
	return nil
end

function MP.CUSTOM.serialize_bans(draft)
	local parts = {}
	for _, bucket in ipairs(BAN_BUCKETS) do
		local values = copy_sequence(draft and draft[bucket.field])
		if #values > 0 then
			parts[#parts + 1] = bucket.prefix .. "=" .. table.concat(values, ",")
		end
	end
	return table.concat(parts, ";")
end

function MP.CUSTOM.parse_bans(value)
	local result = {}
	for _, bucket in ipairs(BAN_BUCKETS) do
		result[bucket.field] = {}
	end

	for section in tostring(value or ""):gmatch("[^;]+") do
		local prefix, body = section:match("^([^=]+)=(.*)$")
		if prefix and body then
			for _, bucket in ipairs(BAN_BUCKETS) do
				if prefix == bucket.prefix then
					for key in body:gmatch("[^,]+") do
						if key ~= "" then
							result[bucket.field][#result[bucket.field] + 1] = key
						end
					end
				end
			end
		end
	end

	return result
end

function MP.CUSTOM.apply_lobby_bans()
	if not (G and G.GAME and G.GAME.banned_keys and MP.LOBBY and MP.LOBBY.config) then
		return
	end

	local bans = MP.CUSTOM.parse_bans(MP.LOBBY.config.custom_bans)
	for _, bucket in ipairs(BAN_BUCKETS) do
		for _, key in ipairs(bans[bucket.field] or {}) do
			G.GAME.banned_keys[key] = true
		end
	end
end

if MP.register_ruleset_ban_extension and not MP.CUSTOM.ban_extension_registered then
	MP.CUSTOM.ban_extension_registered = true
	MP.register_ruleset_ban_extension("custom_ruleset_bans", MP.CUSTOM.apply_lobby_bans)
end

function MP.CUSTOM.set_pending_lobby_options(draft)
	MP.CUSTOM.pending_lobby_options = {
		custom_bans = MP.CUSTOM.serialize_bans(draft),
	}
end

function MP.CUSTOM.get_pending_lobby_options()
	return MP.CUSTOM.pending_lobby_options
end

function MP.CUSTOM.clear_pending_lobby_options()
	MP.CUSTOM.pending_lobby_options = nil
end

function MP.CUSTOM.is_banned(key)
	local draft = MP.CUSTOM.draft
	if not draft then
		return false
	end
	return list_has(draft.banned_jokers, key)
		or list_has(draft.banned_consumables, key)
		or list_has(draft.banned_vouchers, key)
end

function MP.CUSTOM.toggle_ban(card)
	local draft = MP.CUSTOM.draft
	if not (draft and card and card.config and card.config.center) then
		return
	end

	local list = bucket_for(draft, card.config.center.set)
	local key = card.config.center.key
	if not (list and key) then
		return
	end

	if list_has(list, key) then
		list_remove(list, key)
		card.debuff = false
	else
		list[#list + 1] = key
		card.debuff = true
	end
end

function MP.CUSTOM.debuff_collection_page()
	if not (G.your_collection and MP.CUSTOM.draft) then
		return
	end

	for idx = 1, #G.your_collection do
		local collection = G.your_collection[idx]
		for _, card in pairs(collection.cards or {}) do
			if card.config and card.config.center_key and MP.CUSTOM.is_banned(card.config.center_key) then
				card.debuff = true
			end
		end
	end
end

local function open_overlay(definition)
	if BALATRO.open_overlay_menu then
		BALATRO.open_overlay_menu({ definition = definition })
	elseif G.FUNCS.overlay_menu then
		G.FUNCS.overlay_menu({ definition = definition })
	end
end

function G.FUNCS.mp_custom_back_to_editor()
	local mode = MP.CUSTOM.editor_mode or "lobby"
	local build_selection = G.UIDEF.ruleset_selection_tabs or G.UIDEF.ruleset_selection_options
	if not build_selection then
		return
	end

	open_overlay(build_selection(nil, {
		mode = mode,
		chosen_label = "Custom",
		preserve_modifiers = true,
	}))
end

local function install_collection_hooks()
	if MP.CUSTOM.collection_hooks_installed then
		return
	end
	MP.CUSTOM.collection_hooks_installed = true

	if SMODS and SMODS.card_collection_UIBox then
		local card_collection_ref = SMODS.card_collection_UIBox
		function SMODS.card_collection_UIBox(pool, rows, args)
			local ret = card_collection_ref(pool, rows, args)
			MP.CUSTOM.debuff_collection_page()
			return ret
		end
	end

	if G.FUNCS.option_cycle then
		local option_cycle_ref = G.FUNCS.option_cycle
		function G.FUNCS.option_cycle(e)
			local ret = option_cycle_ref(e)
			local config = e and e.config or {}
			local ref_table = config.ref_table or {}
			if ref_table.opt_callback == "SMODS_card_collection_page" then
				MP.CUSTOM.debuff_collection_page()
			end
			return ret
		end
	end

	if G.FUNCS.your_collection then
		local your_collection_ref = G.FUNCS.your_collection
		G.FUNCS.your_collection = function(e)
			if MP.CUSTOM.editing_bans then
				MP.CUSTOM.editing_bans = nil
				return G.FUNCS.mp_custom_back_to_editor(e)
			end
			return your_collection_ref(e)
		end
	end
end

local function install_keybind()
	if MP.CUSTOM.keybind_installed or not (SMODS and SMODS.Keybind) then
		return
	end
	MP.CUSTOM.keybind_installed = true

	SMODS.Keybind({
		key = "mp_custom_ban",
		key_pressed = "delete",
		action = function()
			if not MP.CUSTOM.draft then
				return
			end
			local target = G.CONTROLLER.hovering and G.CONTROLLER.hovering.target
			if not (target and target.config and target.config.center) then
				return
			end
			local area = target.area
			if area and area.config and area.config.collection then
				MP.CUSTOM.toggle_ban(target)
			end
		end,
	})
end

install_collection_hooks()
install_keybind()

function G.FUNCS.mp_custom_set_base(args)
	if MP.CUSTOM.draft and args and args.to_key then
		local content = CONTENT_SETS[args.to_key]
		if content then
			MP.CUSTOM.draft.base = content.ruleset
		end
	end
end

function G.FUNCS.mp_custom_open_collection(e)
	MP.CUSTOM.editing_bans = true
	if G.FUNCS.your_collection_jokers then
		return G.FUNCS.your_collection_jokers(e)
	end
	if G.FUNCS.your_collection then
		return G.FUNCS.your_collection(e)
	end
end

function G.FUNCS.mp_custom_save_and_play(e)
	local draft = MP.CUSTOM.draft or MP.CUSTOM.new_draft()
	local ruleset_short = get_draft_ruleset(draft)
	local ruleset_key = "ruleset_mp_" .. ruleset_short
	local ruleset = MP.Rulesets and MP.Rulesets[ruleset_key] or nil
	if not ruleset then
		MP.UI.UTILS.overlay_message(localize("k_ruleset_not_found"))
		return
	end

	MP.CUSTOM.set_pending_lobby_options(draft)
	if MP.LoadReworks then
		MP.LoadReworks(ruleset_short)
	end

	if MP.CUSTOM.editor_mode == "practice" then
		if MP.set_practice_ruleset then
			MP.set_practice_ruleset(ruleset_key, { preserve_modifiers = true })
		end
		return BALATRO.call_ui_function("start_practice_run", e)
	end

	if lobby_domain.set_creation_ruleset then
		lobby_domain.set_creation_ruleset(ruleset_key)
	end
	if ruleset.forced_gamemode and lobby_domain.set_creation_gamemode then
		lobby_domain.set_creation_gamemode(ruleset.forced_gamemode)
		return BALATRO.call_ui_function("start_lobby", e)
	end

	return BALATRO.call_ui_function("select_gamemode", e)
end

local function text_row(str, scale, colour)
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.04 },
		nodes = {
			{ n = G.UIT.T, config = { text = str, scale = scale or 0.4, colour = colour or G.C.UI.TEXT_LIGHT } },
		},
	}
end

local function knob_row(node)
	return { n = G.UIT.R, config = { align = "cm", padding = 0.08 }, nodes = { node } }
end

local function editor_title()
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.12, r = 0.1, colour = G.C.BOOSTER, emboss = 0.05, minw = 15 },
		nodes = {
			{ n = G.UIT.T, config = { text = "CUSTOM RULESET", scale = 0.55, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
		},
	}
end

local function save_button()
	return UIBox_button({
		button = "mp_custom_save_and_play",
		label = { MP.CUSTOM.editor_mode == "practice" and localize("b_practice") or localize("b_create_lobby") },
		minw = 5,
		minh = 0.85,
		scale = 0.45,
		colour = MP.CUSTOM.editor_mode == "practice" and G.C.GREEN or G.C.BLUE,
		hover = true,
		shadow = true,
	})
end

function MP.UI.build_custom_ruleset_editor(mode)
	MP.CUSTOM.editor_mode = mode or "lobby"
	MP.CUSTOM.draft = MP.CUSTOM.draft or MP.CUSTOM.new_draft()
	local draft = MP.CUSTOM.draft

	local knobs = {
		knob_row(create_option_cycle({
			label = "Content set",
			scale = 0.8,
			options = content_labels(),
			current_option = content_index_for_ruleset(draft.base, 2),
			opt_callback = "mp_custom_set_base",
			w = 4,
		})),
		knob_row(UIBox_button({
			button = "mp_custom_open_collection",
			label = { "Edit bans" },
			minw = 4,
			minh = 0.8,
			scale = 0.45,
			colour = G.C.RED,
			hover = true,
			shadow = true,
		})),
		text_row("Jokers: " .. tostring(#draft.banned_jokers), 0.32, G.C.UI.TEXT_INACTIVE),
		text_row("Consumables: " .. tostring(#draft.banned_consumables), 0.32, G.C.UI.TEXT_INACTIVE),
		text_row("Vouchers: " .. tostring(#draft.banned_vouchers), 0.32, G.C.UI.TEXT_INACTIVE),
		text_row("(hover a card, press DELETE)", 0.28, G.C.UI.TEXT_DARK),
	}

	local variants_nodes = {}
	if MP.UI.build_timer_modifier_cycle then
		variants_nodes[#variants_nodes + 1] = { n = G.UIT.C, config = { align = "cm", padding = 0.1 }, nodes = { MP.UI.build_timer_modifier_cycle() } }
	end
	if MP.UI.build_glass_cycle then
		variants_nodes[#variants_nodes + 1] = { n = G.UIT.C, config = { align = "cm", padding = 0.1 }, nodes = { MP.UI.build_glass_cycle() } }
	end
	if MP.UI.build_pvp_timer_toggle then
		variants_nodes[#variants_nodes + 1] = { n = G.UIT.C, config = { align = "cm", padding = 0.1 }, nodes = { MP.UI.build_pvp_timer_toggle() } }
	end

	local modifiers_panel = {
		{ n = G.UIT.R, config = { align = "cm", padding = 0.04 }, nodes = variants_nodes },
		MP.UI.build_mutators_wall and MP.UI.build_mutators_wall() or text_row("MUTATORS", 0.5),
		{ n = G.UIT.R, config = { minh = 0.06 } },
	}
	if MP.UI.build_mutator_randomize_row then
		modifiers_panel[#modifiers_panel + 1] = MP.UI.build_mutator_randomize_row()
	end

	return {
		n = G.UIT.ROOT,
		config = { align = "cm", colour = G.C.CLEAR },
		nodes = {
			editor_title(),
			{
				n = G.UIT.R,
				config = { align = "cm" },
				nodes = {
					{ n = G.UIT.C, config = { align = "tm", minh = 6, minw = 5, padding = 0.1 }, nodes = knobs },
					{
						n = G.UIT.C,
						config = { align = "tm", minh = 6, minw = 10, padding = 0.15, r = 0.1, colour = G.C.BLACK },
						nodes = modifiers_panel,
					},
				},
			},
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.12 },
				nodes = {
					{ n = G.UIT.C, config = { align = "cm", padding = 0.06 }, nodes = { save_button() } },
				},
			},
		},
	}
end
