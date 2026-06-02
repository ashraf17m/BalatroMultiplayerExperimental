MP.inject_matchmaking_standard_ruleset("smallworld", 3, "k_smallworld_description")

local function is_banned_key(key)
	return not not (key and G.GAME.banned_keys[key])
end

local function ban_key(key)
	G.GAME.banned_keys[key] = true
end

local function mark_voucher_used(key)
	G.GAME.used_vouchers[key] = true
end

local function clear_used_voucher(key)
	G.GAME.used_vouchers[key] = nil
end

local function set_current_round_voucher(voucher_key)
	G.GAME.current_round.voucher = voucher_key
end

local function set_round_reset_ante(ante)
	G.GAME.round_resets.ante = ante
end

local function set_orbital_hand(hand)
	G.orbital_hand = hand
end

local function clear_back_voucher_config(back)
	back.effect.config.vouchers = nil
	back.effect.config.voucher = nil
end

local function is_available_pool_key(key)
	return key and key ~= "UNAVAILABLE"
end

local function collect_available_pool_keys(pool)
	local available = {}
	for _, key in ipairs(pool or {}) do
		if is_available_pool_key(key) then
			available[#available + 1] = key
		end
	end
	return available
end

local function get_smallworld_replacement_pool_key(pool, pool_key)
	local available = collect_available_pool_keys(pool)
	if #available == 0 then
		return nil
	end

	local max_attempts = math.max(#pool * 2, 1)
	for attempt = 1, max_attempts do
		local seed_suffix = MP.should_use_the_order() and "" or ("_resample" .. (attempt + 1))
		local key = pseudorandom_element(pool, pseudoseed((pool_key or "smallworld_pool") .. seed_suffix))
		if is_available_pool_key(key) then
			return key
		end
	end

	return pseudorandom_element(available, pseudoseed((pool_key or "smallworld_pool") .. "_fallback"))
end

MP.register_ruleset_ban_extension("smallworld", function()
	if MP.is_ruleset_active("smallworld") then
		local tables = {}
		local requires = {}
		for k, v in pairs(G.P_CENTERS) do
			if
				v.set
				and not is_banned_key(k)
				and not (v.requires or v.hidden)
				and k ~= "j_cavendish"
				and (not v.mp_include or v:mp_include())
			then
				local index = v.set .. (v.rarity or "")
				tables[index] = tables[index] or {}
				local t = tables[index]
				t[#t + 1] = k
			end
			if v.set == "Voucher" and v.requires then requires[#requires + 1] = k end
		end
		for k, v in pairs(G.P_TAGS) do -- tag exemption
			if not is_banned_key(k) and (not v.mp_include or v:mp_include()) then
				tables["Tag"] = tables["Tag"] or {}
				local t = tables["Tag"]
				t[#t + 1] = k
			end
		end
		for k, v in pairs(tables) do
			if k ~= "Back" and k ~= "Edition" and k ~= "Enhanced" and k ~= "Default" then
				table.sort(v)
				pseudoshuffle(v, pseudoseed(k .. "_mp_smallworld"))
				local threshold = math.floor(0.5 + (#v * 0.75))
				local ii = 1
				if k == "Voucher" and not MP.legacy_smallworld() then ii = ii + 1 end
				for i, vv in ipairs(v) do
					if ii <= threshold then
						ban_key(vv)
						ii = ii + 1
					else
						break
					end
				end
			end
		end
		for i, v in ipairs(requires) do
			if is_banned_key(G.P_CENTERS[v].requires[1]) then ban_key(v) end
		end
		if is_banned_key("j_gros_michel") then ban_key("j_cavendish") end
	end
end)

MP.PLATFORM.SMODS.override_known("showman", function(showman_ref)
	return function(card_key)
		if MP.is_ruleset_active("smallworld") then return true end
		return showman_ref(card_key)
	end
end)

local function smallworld_replacements_active()
	return MP.is_ruleset_active("smallworld") and not MP.legacy_smallworld()
end

local build_traceback = MP.UTILS.build_traceback

local function get_smallworld_replacement_tag()
	local ante = G.GAME.round_resets.ante
	local tag_key = nil

	local ok, err = xpcall(function()
		if MP.should_use_the_order() then set_round_reset_ante(10) end
		tag_key = get_next_tag_key("replace")
	end, build_traceback)
	set_round_reset_ante(ante)

	if not ok then
		error(err, 0)
	end

	return tag_key
end

-- replace banned tags
MP.HOOKS.register_method_hook(Tag, "Tag", "init", "mp.ruleset.smallworld.replace_banned_tag", {
	before = function(ctx)
		local tag_key = ctx.args and ctx.args[1] or nil
		ctx.mp_smallworld_orbital_hand = G.orbital_hand

		if smallworld_replacements_active() and is_banned_key(tag_key) and not G.OVERLAY_MENU then
			tag_key = get_smallworld_replacement_tag()
			ctx.args[1] = tag_key
		end

		if tag_key == "tag_orbital" then
			set_orbital_hand(pseudorandom_element(MP.sorted_hand_list(), pseudoseed("orbital_replace")))
		end
	end,
	after = function(ctx)
		set_orbital_hand(ctx.mp_smallworld_orbital_hand)
	end,
})

local apply_to_run_ref = Back.apply_to_run
local apply_fake_back_vouchers

apply_fake_back_vouchers = function(back)
	local vouchers = {}
	if back.effect.config.voucher then vouchers = { back.effect.config.voucher } end
	if back.effect.config.vouchers or #vouchers > 0 then
		vouchers = back.effect.config.vouchers or vouchers
		local fake_back = { effect = { config = { vouchers = copy_table(vouchers) } } }
		fake_back.effect.center = G.P_CENTERS["b_red"]
		fake_back.name = "FAKE"
		clear_back_voucher_config(back)
		G.E_MANAGER:add_event(Event({
			func = function()
				for i, v in ipairs(fake_back.effect.config.vouchers) do
					local voucher = v
					if is_banned_key(v) or G.GAME.used_vouchers[v] then
						voucher = get_next_voucher_key() or v
					end
					mark_voucher_used(voucher)
					fake_back.effect.config.vouchers[i] = voucher
				end
				set_current_round_voucher(SMODS.get_next_vouchers())
				apply_to_run_ref(fake_back)
				return true
			end,
		}))
	end
end

MP.HOOKS.register_method_hook(Back, "Back", "apply_to_run", "mp.ruleset.smallworld.fake_back_vouchers", {
	before = function(ctx, self)
		if smallworld_replacements_active() then apply_fake_back_vouchers(self) end
	end,
})

local add_joker_ref = add_joker
function add_joker(joker, edition, silent, eternal)
	if MP.is_ruleset_active("smallworld") and is_banned_key(joker) then
		local pool
		local pool_key
		local rarities = { [1] = 0, [2] = 0.9, [3] = 1, [4] = 1 }
		local is_legendary_joker = G.P_CENTERS[joker].rarity == 4
		if G.P_CENTERS[joker].set == "Joker" then
			pool, pool_key = get_current_pool(
				"Joker",
				rarities[G.P_CENTERS[joker].rarity] or G.P_CENTERS[joker].rarity,
				is_legendary_joker
			)
		else
			pool, pool_key = get_current_pool(G.P_CENTERS[joker].set, nil)
		end
		joker = get_smallworld_replacement_pool_key(pool, pool_key) or joker
	end
	return add_joker_ref(joker, edition, silent, eternal)
end

MP.HOOKS.register_method_hook(Card, "Card", "apply_to_run", "mp.ruleset.smallworld.replace_banned_voucher", {
	before = function(ctx, self)
		local center = ctx.args and ctx.args[1] or nil
		if MP.is_ruleset_active("smallworld") and not self and center and is_banned_key(center.key) then
			local original_key = center.key
			clear_used_voucher(original_key)
			local replacement_key = get_next_voucher_key()
			if replacement_key and G.P_CENTERS[replacement_key] then
				center = G.P_CENTERS[replacement_key]
				mark_voucher_used(center.key)
				ctx.args[1] = center
			else
				mark_voucher_used(original_key)
			end
		end
	end,
})

function MP.legacy_smallworld()
	return MP.LOBBY.code and MP.LOBBY.config and MP.LOBBY.config.legacy_smallworld
end
