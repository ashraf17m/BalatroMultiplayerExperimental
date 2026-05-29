-- small file because it feels wrong to add it somewhere else

local non_mp_center_pools = {}
local non_mp_challenges = nil

local pack_values = MP.UTILS.pack_values
local unpack_packed = MP.UTILS.unpack_packed
local build_traceback = MP.UTILS.build_traceback

local function should_hide_mp_content()
	local lobby = MP.LOBBY or {}
	local rulesets = MP.Rulesets or {}
	local active_ruleset = rulesets[lobby.config and lobby.config.ruleset]
	if (not lobby.code) or not (active_ruleset and active_ruleset.multiplayer_content) then -- check for vanilla context
		if MP.PLATFORM.SMODS.get_config_value("hide_mp_content") then return true end
	end
	return false
end

local hidden_tbl = { "Stake", "Back" } -- Challenges are at bottom of file

local function call_with_restored_value(read_value, write_value, temporary_value, fn, ...)
	local original_value = read_value()
	local args = pack_values(...)
	local results = nil

	write_value(temporary_value)

	local ok, err = xpcall(function()
		results = pack_values(fn(unpack_packed(args)))
	end, build_traceback)

	write_value(original_value)

	if not ok then
		error(err, 0)
	end

	return unpack_packed(results)
end

local function build_non_mp_center_pool(center_type)
	local non_mp_pool = {}
	for _, center in ipairs(G.P_CENTER_POOLS[center_type]) do
		if not center.mod or center.mod.id ~= MP.id then
			table.insert(non_mp_pool, center)
		end
	end
	non_mp_center_pools[center_type] = non_mp_pool
	return non_mp_pool
end

local function build_non_mp_challenges()
	local filtered_challenges = {}
	for _, challenge in ipairs(G.CHALLENGES) do
		if not challenge.mod or challenge.mod.id ~= MP.id then
			table.insert(filtered_challenges, challenge)
		end
	end
	non_mp_challenges = filtered_challenges
	return non_mp_challenges
end

MP.PLATFORM.SMODS.override_known("injectItems", function(inject_ref)
	return function(...)
		local ret = inject_ref(...)
		for _, hidden in ipairs(hidden_tbl) do
			build_non_mp_center_pool(hidden)
		end
		build_non_mp_challenges()
		return ret
	end
end)

local function with_hidden_center_pool(center_type, fn, ...)
	if not should_hide_mp_content() then
		return fn(...)
	end

	local hidden_pool = non_mp_center_pools[center_type] or build_non_mp_center_pool(center_type)
	return call_with_restored_value(
		function()
			return G.P_CENTER_POOLS[center_type]
		end,
		function(value)
			G.P_CENTER_POOLS[center_type] = value
		end,
		hidden_pool,
		fn,
		...
	)
end

local function hook(orig, center_type)
	return function(...)
		return with_hidden_center_pool(center_type, orig, ...)
	end
end

local hooks = {
	Stake = {
		{ tbl = G.UIDEF, str = "deck_stake_column" },
		{ tbl = G.UIDEF, str = "current_stake" },
		{ tbl = G.UIDEF, str = "stake_option" },
		{ tbl = G.UIDEF, str = "run_setup_option" },
	},
	Back = {
		{ tbl = G.UIDEF, str = "run_setup_option" },
		{ tbl = G.FUNCS, str = "change_viewed_back" },
		{ tbl = G.FUNCS, str = "change_selected_back" },
	},
}

for k, v in pairs(hooks) do
	for i, vv in ipairs(v) do
		local orig = vv.tbl[vv.str]
		vv.tbl[vv.str] = hook(orig, k)
	end
end

-- slightly modified exception code for challenges

local ch_hooks = {
	{ tbl = G.UIDEF, str = "challenges" },
	{ tbl = G.UIDEF, str = "challenge_list" },
	{ tbl = G.UIDEF, str = "challenge_list_page" },
}

local function with_hidden_challenges(fn, ...)
	if not should_hide_mp_content() then
		return fn(...)
	end

	local hidden_challenges = non_mp_challenges or build_non_mp_challenges()
	return call_with_restored_value(
		function()
			return G.CHALLENGES
		end,
		function(value)
			G.CHALLENGES = value
		end,
		hidden_challenges,
		fn,
		...
	)
end

local function ch_hook(orig)
	return function(...)
		return with_hidden_challenges(orig, ...)
	end
end

for i, v in pairs(ch_hooks) do
	local orig = v.tbl[v.str]
	v.tbl[v.str] = ch_hook(orig)
end
