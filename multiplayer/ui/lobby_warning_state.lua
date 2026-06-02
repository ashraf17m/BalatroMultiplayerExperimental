local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function add_warning(warnings, text, colour, scale)
	warnings[#warnings + 1] = { text, colour, scale }
end

local function get_lobby_owner()
	for _, player in ipairs(MP.LOBBY.players or {}) do
		if player.is_owner then
			return player
		end
	end
	return nil
end

local function get_extra_credit_warning_text(key)
	return string.format(localize(key), localize("mp_sticker_extra_credit"))
end

local function stringify(value)
	if value == nil then
		return ""
	end
	return tostring(value)
end

local function get_warning_text_colour()
	return MP.PLATFORM.SMODS.get_gradient("warning_text", G.C.UI.TEXT_LIGHT)
end

local function build_player_warning_key(player)
	local config = player and player.config or {}
	local mods = config and config.Mods or {}

	return table.concat({
		stringify(player and player.id),
		stringify(player and player.is_owner),
		stringify(player and player.cached),
		stringify(config and config.unlocked),
		stringify(mods and mods.extracredit),
		stringify(mods and mods.Steamodded),
	}, "|")
end

local function build_lobby_warning_cache_key()
	local players = {}
	for _, player in ipairs(MP.LOBBY.players or {}) do
		players[#players + 1] = build_player_warning_key(player)
	end

	return table.concat({
		stringify(MP.LOBBY and MP.LOBBY.lobby_type),
		stringify(MP.LOBBY and MP.LOBBY.client and MP.LOBBY.client.username),
		stringify(MP.UTILS.unlock_check and MP.UTILS.unlock_check()),
		table.concat(players, ";"),
	}, "||")
end

local function compute_lobby_warnings()
	local warnings = {}
	local cheating_warning_added = false
	local warning_text_colour = get_warning_text_colour()

	local self_player_id = BALATRO.get_player_id and BALATRO.get_player_id() or nil
	for _, p in ipairs(MP.LOBBY.players or {}) do
		if p.id ~= self_player_id then
			if p.cached == false and not cheating_warning_added then
				local cheating_msg = string.format(localize("k_warning_cheating2"), MP.UTILS.random_message())
				add_warning(warnings, localize("k_warning_cheating1"), warning_text_colour, 0.4)
				add_warning(warnings, cheating_msg, warning_text_colour)
				cheating_warning_added = true
			end

			if p.config and p.config.unlocked == false then
				add_warning(warnings, localize("k_warning_nemesis_unlock"), warning_text_colour, 0.25)
			end
		end
	end

	local host = get_lobby_owner()

	if host and host.config and MP.LOBBY and MP.LOBBY.lobby_type == MP.LOBBY_TYPES.ONE_V_ONE then
		local guest = nil
		for _, p in ipairs(MP.LOBBY.players or {}) do
			if p.id ~= host.id then
				guest = p
				break
			end
		end

		if guest and guest.config then
			local host_extra_credit_version = host.config.Mods["extracredit"]
			local guest_extra_credit_version = guest.config.Mods["extracredit"]

			if host_extra_credit_version ~= guest_extra_credit_version then
				add_warning(
					warnings,
					get_extra_credit_warning_text("k_warning_extra_credit_mismatch"),
					warning_text_colour
				)
			elseif host_extra_credit_version ~= nil then
				add_warning(
					warnings,
					get_extra_credit_warning_text("k_warning_extra_credit_active"),
					G.C.GREEN,
					0.25
				)
			end
		end
	elseif host and host.config then
		for _, p in ipairs(MP.LOBBY.players or {}) do
			if not p.is_owner and p.config then
				local host_extra_credit = host.config.Mods["extracredit"]
				local guest_extra_credit = p.config.Mods["extracredit"]
				if host_extra_credit ~= guest_extra_credit then
					add_warning(
						warnings,
						get_extra_credit_warning_text("k_warning_extra_credit_mismatch_short"),
						warning_text_colour
					)
					break
				end
			end
		end
	end

	if host and host.config then
		local host_steamodded_version = host.config.Mods["Steamodded"]
		for _, p in ipairs(MP.LOBBY.players or {}) do
			if not p.is_owner and p.config then
				local guest_steamodded_version = p.config.Mods["Steamodded"]
				if host_steamodded_version ~= guest_steamodded_version then
					add_warning(warnings, localize("k_steamodded_warning"), warning_text_colour)
					break
				end
			end
		end
	end

	MP.PLATFORM.SMODS.set_config_value("unlocked", MP.UTILS.unlock_check())
	if not MP.PLATFORM.SMODS.get_config_value("unlocked") then
		add_warning(warnings, localize("k_warning_unlock_profile"), warning_text_colour, 0.25)
	end

	if MP.LOBBY.client.username == "Guest" then
		add_warning(warnings, localize("k_set_name"), G.C.UI.TEXT_LIGHT)
	end

	if #warnings == 0 then
		add_warning(warnings, " ", G.C.UI.TEXT_LIGHT)
	end

	return warnings
end

function MP.UI.get_lobby_warnings()
	local cache_key = build_lobby_warning_cache_key()
	local cache = MP.UI.lobby_warning_cache
	if cache and cache.key == cache_key and cache.warnings then
		return cache.warnings
	end

	local warnings = compute_lobby_warnings()
	MP.UI.lobby_warning_cache = {
		key = cache_key,
		warnings = warnings,
	}
	return warnings
end
