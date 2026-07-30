local teams_domain = MP.DOMAIN and MP.DOMAIN.TEAMS or {}

function MP.should_use_the_order()
	return MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.the_order and MP.LOBBY.code
end

function MP.is_major_league_ruleset()
	return MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.ruleset == "ruleset_mp_majorleague" and MP.LOBBY.code
end

function MP.is_ffa_mode()
	return MP.LOBBY and MP.LOBBY.lobby_type == MP.LOBBY_TYPES.FFA
end

function MP.is_duels_mode()
	return MP.LOBBY and MP.LOBBY.lobby_type == MP.LOBBY_TYPES.DUELS
end

local function get_lobby_type_spec(lobby_type)
	return MP.get_lobby_type_spec and MP.get_lobby_type_spec(lobby_type) or nil
end

local function lobby_type_uses_teams(lobby_type)
	local spec = get_lobby_type_spec(lobby_type)
	return not not (spec and spec.uses_teams)
end

function MP.is_teams_mode()
	return MP.LOBBY and lobby_type_uses_teams(MP.LOBBY.lobby_type)
end

function MP.is_coop_lobby_type()
	return MP.LOBBY and MP.LOBBY.lobby_type == MP.LOBBY_TYPES.COOP
end

function MP.is_duels_bye()
	if MP.GAME and MP.GAME.duel_blind_role == "bye" then
		return true
	elseif MP.GAME and MP.GAME.duel_blind_role == "pair" then
		return false
	end

	local opponents = MP.OPPONENTS or {}
	return (MP.is_duels_mode and MP.is_duels_mode())
		and not (opponents.get_nemesis_lobby_player and opponents.get_nemesis_lobby_player())
end

local function get_round_resets()
	local balatro = MP.PLATFORM and MP.PLATFORM.BALATRO or nil
	return balatro and balatro.get_round_resets and balatro.get_round_resets() or nil
end

function MP.is_duel_bye_blind_row(row)
	local round_resets = get_round_resets()
	local duel_bye_blind_choices = round_resets and round_resets.duel_bye_blind_choices or nil
	return not not (
		MP.is_duels_mode
		and MP.is_duels_mode()
		and duel_bye_blind_choices
		and duel_bye_blind_choices[row]
	)
end

function MP.is_duel_bye_blind()
	local row = teams_domain.get_current_blind_row and teams_domain.get_current_blind_row() or nil
	return row and MP.is_duel_bye_blind_row and MP.is_duel_bye_blind_row(row)
end

local function is_lobby_config_enabled(option_key)
	return not (MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config[option_key] == false)
end

local function get_active_gamemode_key()
	if MP.get_active_gamemode then
		local active_gamemode = MP.get_active_gamemode()
		if active_gamemode then return active_gamemode end
	end
	return MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.gamemode
end

function MP.is_coop_gamemode()
	return get_active_gamemode_key() == "gamemode_mp_coop"
end

function MP.is_coop_run()
	return (MP.is_coop_gamemode and MP.is_coop_gamemode())
		and (MP.is_coop_lobby_type and MP.is_coop_lobby_type())
end

function MP.is_survival_gamemode()
	return get_active_gamemode_key() == "gamemode_mp_survival"
end

function MP.get_lobby_capabilities()
	local is_teams_mode = not not (MP.is_teams_mode and MP.is_teams_mode())
	local is_coop_gamemode = not not (MP.is_coop_gamemode and MP.is_coop_gamemode())
	local is_coop_lobby_type = not not (MP.is_coop_lobby_type and MP.is_coop_lobby_type())
	local uses_shared_sync_group = is_teams_mode or is_coop_lobby_type
	local can_show_shared_progress_options = not not MP.LOBBY
	local card_sync_option_enabled = is_lobby_config_enabled("team_card_sync")
	local hand_level_sync_option_enabled = is_lobby_config_enabled("team_hand_level_sync")
	local money_sync_option_enabled = is_lobby_config_enabled("team_money_sync")

	return {
		is_teams_mode = is_teams_mode,
		is_coop_gamemode = is_coop_gamemode,
		is_coop_lobby_type = is_coop_lobby_type,
		uses_shared_sync_group = uses_shared_sync_group,
		shows_team_identity = is_teams_mode,
		uses_team_colours = is_teams_mode,
		can_show_shared_progress_options = can_show_shared_progress_options,
		can_show_team_options = is_teams_mode,
		shared_card_sync_enabled = can_show_shared_progress_options and card_sync_option_enabled,
		shared_hand_level_sync_enabled = uses_shared_sync_group and hand_level_sync_option_enabled,
		shared_money_sync_enabled = uses_shared_sync_group and money_sync_option_enabled,
		can_show_shared_money_actions = uses_shared_sync_group and money_sync_option_enabled,
	}
end

local function get_lobby_capability_value(key)
	local capabilities = MP.get_lobby_capabilities and MP.get_lobby_capabilities() or {}
	return not not capabilities[key]
end

function MP.uses_shared_sync_group()
	return get_lobby_capability_value("uses_shared_sync_group")
end

function MP.is_shared_card_sync_enabled()
	return get_lobby_capability_value("shared_card_sync_enabled")
end

function MP.is_shared_hand_level_sync_enabled()
	return get_lobby_capability_value("shared_hand_level_sync_enabled")
end

function MP.is_shared_money_sync_enabled()
	return get_lobby_capability_value("shared_money_sync_enabled")
end

function MP.lobby_players_share_sync_group(left, right, capabilities)
	local lobby_capabilities = capabilities or (MP.get_lobby_capabilities and MP.get_lobby_capabilities()) or {}
	if not lobby_capabilities.uses_shared_sync_group then
		return false
	end

	if lobby_capabilities.is_coop_lobby_type then
		return true
	end

	if not lobby_capabilities.is_teams_mode then
		return false
	end

	return ((left and left.team) or 1) == ((right and right.team) or 1)
end

local function get_coop_player_count()
	local count = 0
	for _, player in pairs((MP.LOBBY and MP.LOBBY.players) or {}) do
		if player and player.is_in_match ~= false and player.is_disconnected ~= true then
			count = count + 1
		end
	end
	return math.max(1, count)
end

local function get_coop_blind_multiplier()
	local per_player = tonumber(MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.coop_blind_scaling_per_player) or 1
	per_player = math.max(0, per_player)
	return math.max(1, get_coop_player_count() * per_player)
end

local function is_big_number(value)
	if type(is_big) == "function" then
		local ok, result = pcall(is_big, value)
		if ok and result then return true end
	end

	if Big and type(Big.is) == "function" then
		local ok, result = pcall(Big.is, value)
		if ok and result then return true end
	end

	if type(is_number) == "function" then
		local ok, result = pcall(is_number, value)
		if ok and result and type(value) ~= "number" then return true end
	end

	if type(value) == "table" and ((value.m ~= nil and value.e ~= nil) or (value.array ~= nil and value.sign ~= nil)) then
		return true
	end

	return false
end

local function is_scalable_score_amount(value)
	return type(value) == "number" or is_big_number(value)
end

local function one_like_score(value)
	if is_big_number(value) and type(to_big) == "function" then
		local ok, one = pcall(to_big, 1)
		if ok and one then return one end
	end

	return 1
end

local function floor_score_amount(value)
	local ok, floored = pcall(math.floor, value)
	if ok then return floored end

	return value
end

local function max_score_amount(left, right)
	local ok, result = pcall(math.max, left, right)
	if ok then return result end

	local ok_compare, left_is_smaller = pcall(function()
		return left < right
	end)
	if ok_compare and left_is_smaller then return right end

	return left
end

function MP.scale_coop_blind_amount(amount)
	if not (MP.is_coop_run and MP.is_coop_run()) then return amount end

	if not is_scalable_score_amount(amount) then return amount end

	local scaled_amount = floor_score_amount(amount * get_coop_blind_multiplier() + 0.5)
	return max_score_amount(one_like_score(scaled_amount), scaled_amount)
end

function MP.is_coop_blind()
	return (MP.is_coop_run and MP.is_coop_run())
		and not (MP.is_pvp_boss and MP.is_pvp_boss())
end

function MP.is_server_resolved_blind()
	if MP.is_survival_gamemode and MP.is_survival_gamemode() then
		return MP.is_pvp_boss()
	end

	return MP.is_pvp_boss()
		or (teams_domain.is_cooperative_blind and teams_domain.is_cooperative_blind())
		or (MP.is_coop_run and MP.is_coop_run())
end
