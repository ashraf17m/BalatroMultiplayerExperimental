MP.BLIND_CHOICE_INTERNAL = MP.BLIND_CHOICE_INTERNAL or {}

local INTERNAL = MP.BLIND_CHOICE_INTERNAL
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

INTERNAL.original_skip_blind = INTERNAL.original_skip_blind or BALATRO.get_ui_function("skip_blind")

function INTERNAL.get_blind_choice_row_type(e)
	local el = e
	for _ = 1, 12 do
		if not el or not el.config then
			break
		end
		local id = el.config.id
		if id == "Small" or id == "Big" or id == "Boss" then
			return id
		end
		el = el.parent
	end
	return nil
end

local BLIND_KIND_BY_ROW = {
	Small = "small",
	Big = "big",
	Boss = "boss",
}

function INTERNAL.get_blind_choice_row_kind_for_row(row)
	local round_resets = BALATRO.get_round_resets and BALATRO.get_round_resets() or nil
	if not row or not round_resets then
		return nil
	end
	local rs = round_resets
	if rs.blind_choices[row] == "bl_mp_nemesis" or rs.pvp_blind_choices[row] then
		return "pvp"
	end
	return BLIND_KIND_BY_ROW[row]
end

function INTERNAL.get_blind_choice_row_kind(e)
	local row = INTERNAL.get_blind_choice_row_type(e)
	if not row then
		return nil
	end
	return INTERNAL.get_blind_choice_row_kind_for_row(row)
end

function INTERNAL.get_match_ready_blind_kind()
	local game = MP and MP.GAME or nil
	if not (game and game.ready_blind) then
		return nil
	end

	return game.ready_blind_kind
end

local function get_match_ready_blind_mode()
	local ready_blind_kind = INTERNAL.get_match_ready_blind_kind and INTERNAL.get_match_ready_blind_kind() or nil
	if ready_blind_kind == "pvp" then
		return "pvp"
	end
	if ready_blind_kind ~= nil then
		return "team"
	end

	return nil
end

function INTERNAL.is_readying_pvp_blind()
	return get_match_ready_blind_mode() == "pvp"
end

function INTERNAL.is_pvp_timer_context()
	if not (MP and MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.timer) then
		return false
	end
	if INTERNAL.is_readying_pvp_blind and INTERNAL.is_readying_pvp_blind() then
		return true
	end

	return not not (MP.GAME and MP.GAME.timer_started)
end

function INTERNAL.is_teams_cooperative_row(row)
	local blind_kind = INTERNAL.get_blind_choice_row_kind_for_row(row)
	return blind_kind == "small" or blind_kind == "big" or blind_kind == "boss"
end

function INTERNAL.is_team_skip_ready_row(row)
	return MP.LOBBY
		and MP.LOBBY.code
		and (
			MP.is_teams_mode()
			or (MP.is_coop_lobby_type and MP.is_coop_lobby_type())
		)
		and (row == "Small" or row == "Big")
		and INTERNAL.is_teams_cooperative_row(row)
end

return INTERNAL
