local function normalize_money_value(value)
	local numeric_value = tonumber(value) or tonumber(tostring(value))
	if numeric_value == nil
		or numeric_value ~= numeric_value
		or numeric_value == math.huge
		or numeric_value == -math.huge then
		return nil
	end
	return numeric_value
end

local function get_visible_game_money()
	if G and G.GAME and G.GAME.dollars ~= nil then
		local live = normalize_money_value(G.GAME.dollars)
		if live ~= nil then
			return live
		end
	end

	return nil
end

function MP.get_local_money()
	local live = get_visible_game_money()
	if live ~= nil then
		return live
	end

	if MP.GAME and MP.GAME.real_money ~= nil then
		local tracked = normalize_money_value(MP.GAME.real_money)
		if tracked ~= nil then
			return tracked
		end
	end

	return 0
end

local function refresh_local_money_state()
	local live = get_visible_game_money()
	if live == nil or not MP.GAME then
		return nil
	end

	MP.GAME.real_money = tostring(live)
	return live
end

function MP.sync_local_money_state(options)
	local money = refresh_local_money_state()
	if money == nil then
		return false
	end

	options = options or {}
	if options.skip_send or (MP.GAME and MP.GAME.applying_remote_money) then
		return true
	end

	if MP.uses_shared_sync_group() and not MP.is_shared_money_sync_enabled() then
		return true
	end

	if not (MP.LOBBY and MP.LOBBY.code and MP.ACTIONS and MP.ACTIONS.sync_money) then
		return true
	end

	return MP.ACTIONS.sync_money(money)
end
