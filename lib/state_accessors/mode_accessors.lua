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
	return MP.LOBBY and (
		MP.LOBBY.lobby_type == (MP.LOBBY_TYPES and MP.LOBBY_TYPES.COOP)
		or MP.LOBBY.lobby_type == "coop"
		or MP.LOBBY.lobby_type == "lobby_mp_coop"
	)
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
	return (G and G.GAME and G.GAME.round_resets or nil)
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
	local key = get_active_gamemode_key()
		or (MP.LOBBY and (MP.LOBBY.gamemode or (MP.LOBBY.config and MP.LOBBY.config.gamemode)))
	return key == "gamemode_mp_coop" or key == "coop"
end

function MP.is_coop_run()
	return not not (
		(MP.is_coop_gamemode and MP.is_coop_gamemode())
		or (MP.is_coop_lobby_type and MP.is_coop_lobby_type())
	)
end

function MP.is_survival_gamemode()
	return get_active_gamemode_key() == "gamemode_mp_survival"
end

function MP.get_lobby_capabilities()
	local is_teams_mode = not not (MP.is_teams_mode and MP.is_teams_mode())
	local is_coop_gamemode = not not (MP.is_coop_gamemode and MP.is_coop_gamemode())
	local is_coop_lobby_type = not not (MP.is_coop_lobby_type and MP.is_coop_lobby_type())
	local uses_shared_sync_group = is_teams_mode or is_coop_lobby_type or is_coop_gamemode
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

	if lobby_capabilities.is_coop_lobby_type or lobby_capabilities.is_coop_gamemode then
		return true
	end

	if not lobby_capabilities.is_teams_mode then
		return false
	end

	return ((left and left.team) or 1) == ((right and right.team) or 1)
end

local function count_active_coop_players_in_list(list)
	local count = 0
	for _, player in pairs(list or {}) do
		if player and player.is_disconnected ~= true and not (player.is_spectator or player.role == "spectator" or player.spectator == true) then
			count = count + 1
		end
	end
	return count
end

local function get_coop_player_count()
	local count = 0
	if MP.LOBBY and MP.LOBBY.players and next(MP.LOBBY.players) then
		count = count_active_coop_players_in_list(MP.LOBBY.players)
	end

	if count == 0 and MP.GAME and MP.GAME.enemies then
		local enemies_count = 0
		for _, enemy in pairs(MP.GAME.enemies) do
			if enemy and enemy.disconnected ~= true and enemy.is_disconnected ~= true and not (enemy.spectator or enemy.is_spectator) then
				enemies_count = enemies_count + 1
			end
		end
		count = 1 + enemies_count
	end

	return math.max(1, count)
end

MP.get_coop_player_count = get_coop_player_count

local function get_coop_target_multiplier(custom_count)
	local count = math.max(1, custom_count or get_coop_player_count())
	local per_player = tonumber(MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.coop_blind_scaling_per_player) or 1
	per_player = math.max(0, per_player)
	local target_multiplier = count * per_player
	local start_multiplier = 1.0
	return target_multiplier, start_multiplier, per_player
end

local function get_coop_curve_exponent()
	local exponent = tonumber(MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.coop_blind_scaling_curve)
	if not exponent or exponent <= 0 then
		exponent = 1.4
	end
	return exponent
end

local function get_coop_effective_ante(ante)
	if type(ante) == "number" and ante >= 1 then
		return ante
	end
	local round_resets = (BALATRO and (G and G.GAME and G.GAME.round_resets))
		or (G and G.GAME and G.GAME.round_resets)
		or nil
	local game_ante = (round_resets and (round_resets.blind_ante or round_resets.ante))
		or (BALATRO and (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante or nil))
		or 1
	return math.max(1, tonumber(game_ante) or 1)
end

local function get_coop_blind_multiplier(ante, custom_count)
	local target_multiplier, start_multiplier, per_player = get_coop_target_multiplier(custom_count)
	if target_multiplier <= 1 and start_multiplier <= 1 then
		return 1
	end

	local current_ante = get_coop_effective_ante(ante)
	if current_ante <= 1 then
		return start_multiplier
	end

	local t = math.min(1, (current_ante - 1) / 7)
	local exponent = get_coop_curve_exponent()
	local progress = t ^ exponent
	return start_multiplier + (target_multiplier - start_multiplier) * progress
end

local function to_lua_number(value)
	if type(value) == "number" then
		return value
	end
	if type(to_number) == "function" then
		local ok, n = pcall(to_number, value)
		if ok and type(n) == "number" then
			return n
		end
	end
	if type(value) == "string" then
		return tonumber((string.gsub(value, ",", "")))
	end
	if value == nil then
		return nil
	end
	return tonumber(value) or tonumber((string.gsub(tostring(value), ",", "")))
end

local function round_coop_blind_amount(value, ante)
	if ante ~= nil and get_coop_effective_ante(ante) > 8 then
		return to_lua_number(value) or value
	end

	local num = to_lua_number(value)
	if not num or num <= 0 then
		return value
	end

	local mag = 10 ^ math.floor(math.log10(num) - 1)
	local step = math.max(50, mag)
	return math.ceil(num / step) * step
end

MP.get_coop_target_multiplier = get_coop_target_multiplier
MP.get_coop_blind_multiplier = get_coop_blind_multiplier
MP.round_coop_blind_amount = round_coop_blind_amount


function MP.scale_coop_blind_amount(amount, ante, blind_mult)
	if not (MP.is_coop_run and MP.is_coop_run()) then
		return amount
	end
	if amount == nil then
		return amount
	end

	local coop_mult = get_coop_blind_multiplier(ante)
	if not coop_mult or coop_mult <= 1 then
		return amount
	end

	local num_amount = to_lua_number(amount)
	if not num_amount then
		return amount
	end

	-- Round the 1x small-blind unit, then apply Small/Big/Boss (or special boss) mult.
	local row_mult = to_lua_number(blind_mult)
	if not row_mult or row_mult <= 0 then
		row_mult = 1
	end
	local unit = num_amount / row_mult
	return round_coop_blind_amount(unit * coop_mult, ante) * row_mult
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
