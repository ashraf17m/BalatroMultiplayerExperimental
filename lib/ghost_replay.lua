-- Ghost Replay: load and play back PvP hands from replay files in practice mode.

MP.GHOST = MP.GHOST or {}

local GHOST = MP.GHOST
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

GHOST.active = GHOST.active or false
GHOST.replay = GHOST.replay or nil
GHOST.flipped = GHOST.flipped or false
GHOST.gamemode = GHOST.gamemode or nil
GHOST._hands = GHOST._hands or {}
GHOST._hand_idx = GHOST._hand_idx or 0
GHOST._advancing = GHOST._advancing or false

local function is_ghost_active()
	return GHOST.active and GHOST.replay ~= nil
end

function MP.is_mp_or_ghost()
	return not not ((MP.LOBBY and MP.LOBBY.code) or is_ghost_active())
end

local function get_lobby_config()
	MP.LOBBY = MP.LOBBY or {}
	MP.LOBBY.config = MP.LOBBY.config or (MP.build_lobby_option_defaults and MP.build_lobby_option_defaults()) or {}
	return MP.LOBBY.config
end

local function get_config_value(key, default)
	local config = get_lobby_config()
	if config[key] == nil then
		return default
	end
	return config[key]
end

local function normalize_ruleset_key(ruleset_key)
	if not ruleset_key or ruleset_key == "" then
		return MP.DEFAULT_LOBBY_CREATION_RULESET or "ruleset_mp_standard_ranked"
	end
	ruleset_key = tostring(ruleset_key)
	if string.sub(ruleset_key, 1, 11) == "ruleset_mp_" then
		return ruleset_key
	end
	return "ruleset_mp_" .. ruleset_key
end

local function normalize_gamemode_key(gamemode_key)
	if not gamemode_key or gamemode_key == "" then
		return MP.DEFAULT_LOBBY_CREATION_GAMEMODE or "gamemode_mp_attrition"
	end
	gamemode_key = tostring(gamemode_key)
	if string.sub(gamemode_key, 1, 12) == "gamemode_mp_" then
		return gamemode_key
	end
	return "gamemode_mp_" .. gamemode_key
end

local function get_match_domain()
	return MP.DOMAIN and MP.DOMAIN.MATCH or nil
end

local function get_enemy_state()
	MP.GAME = MP.GAME or {}
	MP.GAME.enemy = MP.GAME.enemy or {}
	return MP.GAME.enemy
end

local function refresh_enemy_view(enemy)
	if MP.OPPONENTS and MP.OPPONENTS.refresh_primary_enemy_view then
		MP.OPPONENTS.refresh_primary_enemy_view(enemy)
	end
end

local function score_from_string(score_text)
	if MP.INSANE_INT and MP.INSANE_INT.from_string then
		return MP.INSANE_INT.from_string(tostring(score_text or "0"))
	end
	return tostring(score_text or "0")
end

local function score_to_string(score)
	if MP.INSANE_INT and MP.INSANE_INT.to_string then
		return MP.INSANE_INT.to_string(score)
	end
	return tostring(score or "0")
end

local function score_to_big(score_text)
	if type(to_big) ~= "function" then
		return tonumber(score_text) or 0
	end

	local score = score_from_string(score_text)
	if MP.INSANE_INT and MP.INSANE_INT.to_safe_number then
		local safe_number = MP.INSANE_INT.to_safe_number(score)
		if safe_number ~= nil then
			return to_big(safe_number)
		end
	end

	local coefficient = score and (score.coefficient or score.coeffiocient) or 0
	local exponent = score and score.exponent or 0
	local ok, big_score = pcall(to_big, tostring(coefficient or 0) .. "e" .. tostring(exponent or 0))
	if ok and big_score then
		return big_score
	end
	return to_big(0)
end

local function apply_enemy_score(score_text, hands_left)
	local score = score_from_string(score_text)
	local enemy = get_enemy_state()
	enemy.score = score
	enemy.synced_score = score
	enemy.score_text = score_to_string(score)
	enemy.hands = tonumber(hands_left) or 0
	enemy.username = GHOST.get_nemesis_name and GHOST.get_nemesis_name() or enemy.username or localize("k_ghost")
	enemy.raw_location = "loc_playing-bl_mp_nemesis"
	enemy.location = MP.UI and MP.UI.localize_location and MP.UI.localize_location(enemy.raw_location) or "Playing PvP"

	MP.GAME.enemies = MP.GAME.enemies or {}
	MP.GAME.enemies.ghost = enemy
	refresh_enemy_view(enemy)
	return enemy
end

local function set_enemy_lives(lives)
	local enemy = get_enemy_state()
	enemy.lives = lives
	enemy.team_lives = lives
	refresh_enemy_view(enemy)
	return enemy
end

local function get_starting_lives(replay)
	local from_replay = tonumber(replay and replay.starting_lives)
	if from_replay then return from_replay end
	return tonumber(get_config_value("starting_lives", MP.DEFAULT_STARTING_LIVES or 4)) or (MP.DEFAULT_STARTING_LIVES or 4)
end

function GHOST.load(replay)
	GHOST.active = true
	GHOST.replay = replay
	GHOST.flipped = false
	GHOST.gamemode = normalize_gamemode_key(replay and replay.gamemode)
	GHOST._hands = {}
	GHOST._hand_idx = 0
	GHOST._advancing = false
end

function GHOST.clear()
	GHOST.active = false
	GHOST.replay = nil
	GHOST.flipped = false
	GHOST.gamemode = nil
	GHOST._hands = {}
	GHOST._hand_idx = 0
	GHOST._advancing = false
end

function GHOST.flip()
	GHOST.flipped = not GHOST.flipped
end

function GHOST.is_active()
	return is_ghost_active()
end

function GHOST.get_enemy_hands(ante)
	if not (GHOST.replay and GHOST.replay.ante_snapshots) then return {} end
	local snapshot = GHOST.replay.ante_snapshots[ante] or GHOST.replay.ante_snapshots[tostring(ante)]
	if not (snapshot and snapshot.hands) then return {} end

	local enemy_side = GHOST.flipped and "player" or "enemy"
	local out = {}
	for _, hand in ipairs(snapshot.hands) do
		if hand.side == enemy_side then
			out[#out + 1] = hand
		end
	end
	return out
end

function GHOST.init_playback(ante)
	local hands = GHOST.get_enemy_hands(ante)
	GHOST._hands = hands
	GHOST._hand_idx = 0
	GHOST._advancing = false

	if #hands > 0 then
		GHOST._hand_idx = 1
		apply_enemy_score(hands[1].score, hands[1].hands_left)
		return true
	end

	apply_enemy_score("0", 0)
	return false
end

function GHOST.advance_hand()
	if GHOST._hand_idx >= #GHOST._hands then return false end
	GHOST._hand_idx = GHOST._hand_idx + 1

	local entry = GHOST._hands[GHOST._hand_idx]
	local score = score_from_string(entry.score)
	local enemy = get_enemy_state()

	if not (
		type(score) == "table"
		and enemy.score
		and MP.INSANE_INT
		and MP.INSANE_INT.ease_display_score
		and MP.INSANE_INT.ease_display_score(enemy.score, score, { delay = 0.5 })
	) then
		enemy.score = score
	end

	enemy.synced_score = score
	enemy.hands = tonumber(entry.hands_left) or 0
	enemy.score_text = score_to_string(score)
	refresh_enemy_view(enemy)
	if MP.UI and MP.UI.juice_up_pvp_hud then MP.UI.juice_up_pvp_hud() end
	return true
end

function GHOST.playback_exhausted()
	return #GHOST._hands == 0 or GHOST._hand_idx >= #GHOST._hands
end

function GHOST.has_hand_data()
	return #GHOST._hands > 0
end

function GHOST.current_target_big()
	if GHOST._hand_idx < 1 or GHOST._hand_idx > #GHOST._hands then
		return type(to_big) == "function" and to_big(0) or 0
	end
	return score_to_big(GHOST._hands[GHOST._hand_idx].score)
end

function GHOST.get_nemesis_name()
	if not GHOST.replay then return nil end
	if GHOST.flipped then
		return GHOST.replay.player_name or localize("k_ghost")
	end
	return GHOST.replay.nemesis_name or localize("k_ghost")
end

function GHOST.get_blind_name_ui()
	return { { string = GHOST.get_nemesis_name() } }
end

local function lose_local_life()
	if get_config_value("gold_on_life_loss", true) then
		MP.GAME.comeback_bonus_given = false
		MP.GAME.comeback_bonus = (MP.GAME.comeback_bonus or 0) + 1
	end
	MP.GAME.lives = (tonumber(MP.GAME.lives) or 0) - 1
	if MP.UI and MP.UI.ease_lives then MP.UI.ease_lives(-1) end
	if get_config_value("no_gold_on_round_loss", false) and G and G.GAME and G.GAME.blind and G.GAME.blind.dollars then
		G.GAME.blind.dollars = 0
	end
	return tonumber(MP.GAME.lives) or 0
end

local function lose_enemy_life()
	local enemy = get_enemy_state()
	enemy.lives = (tonumber(enemy.lives) or 0) - 1
	enemy.team_lives = enemy.lives
	refresh_enemy_view(enemy)
	return enemy.lives
end

function GHOST.resolve_pvp_hands_exhausted(chips)
	local beat_current = score_to_big(chips) >= GHOST.current_target_big()
	local all_exhausted = GHOST.playback_exhausted()

	if beat_current and all_exhausted then
		if lose_enemy_life() <= 0 then
			MP.GAME.won = true
			return "won"
		end
	else
		if lose_local_life() <= 0 then
			return "game_over"
		end
	end

	MP.GAME.end_pvp = true
	return "continue"
end

function GHOST.resolve_pvp_mid_hand(chips)
	if not GHOST.has_hand_data() then return false end

	local beat_current = score_to_big(chips) >= GHOST.current_target_big()
	if beat_current and GHOST.playback_exhausted() then
		if lose_enemy_life() <= 0 then
			MP.GAME.won = true
			if win_game then win_game() end
			return true
		end
		MP.GAME.end_pvp = true
		return true
	elseif beat_current and not GHOST.playback_exhausted() and not GHOST._advancing then
		GHOST._start_advance_sequence()
	end
	return false
end

function GHOST._start_advance_sequence()
	GHOST._advancing = true

	local function step()
		GHOST.advance_hand()
		G.E_MANAGER:add_event(Event({
			blockable = false,
			blocking = false,
			trigger = "after",
			delay = 0.6,
			func = function()
				if score_to_big(G.GAME.chips) >= GHOST.current_target_big() and not GHOST.playback_exhausted() then
					step()
				else
					if score_to_big(G.GAME.chips) >= GHOST.current_target_big() and GHOST.playback_exhausted() then
						if lose_enemy_life() <= 0 then
							MP.GAME.won = true
							if win_game then win_game() end
							GHOST._advancing = false
							return true
						end
						MP.GAME.end_pvp = true
					end
					GHOST._advancing = false
				end
				return true
			end,
		}))
	end

	G.E_MANAGER:add_event(Event({
		blockable = false,
		blocking = false,
		trigger = "after",
		delay = 0.5,
		func = function()
			step()
			return true
		end,
	}))
end

function GHOST.resolve_round_fail()
	if get_config_value("death_on_round_loss", true) and G.GAME.current_round.hands_played > 0 then
		if lose_local_life() <= 0 then
			return "game_over"
		end
	end
	return nil
end

function GHOST.seed_match_state()
	if not GHOST.is_active() then return false end

	local match_domain = get_match_domain()
	if match_domain and match_domain.reset_state then
		match_domain.reset_state()
	end

	MP.GAME = MP.GAME or {}
	local starting_lives = get_starting_lives(GHOST.replay)
	MP.GAME.lives = starting_lives
	MP.GAME.team_lives = starting_lives
	MP.GAME.enemies = MP.GAME.enemies or {}
	MP.GAME.enemy = MP.GAME.enemy or {}
	MP.GAME.empty_enemy = MP.GAME.empty_enemy or {}

	local enemy = set_enemy_lives(starting_lives)
	enemy.username = GHOST.get_nemesis_name() or localize("k_ghost")
	enemy.in_match = true
	enemy.is_disconnected = false
	apply_enemy_score("0", MP.DEFAULT_HANDS_PER_ROUND or 4)

	return true
end

function GHOST.start_practice_run(e)
	if not GHOST.is_active() then return false end

	local replay = GHOST.replay
	GHOST.seed_match_state()

	local ruleset_key = normalize_ruleset_key(replay.ruleset or (MP.SP and MP.SP.ruleset))
	if MP.set_practice_ruleset then
		MP.set_practice_ruleset(ruleset_key, { preserve_modifiers = true })
	elseif MP.SP then
		MP.SP.ruleset = ruleset_key
		MP.SP.practice = true
	end
	if MP.SP then
		MP.SP.gamemode = normalize_gamemode_key(replay.gamemode)
	end

	local deck_key = MP.UTILS and MP.UTILS.get_deck_key_from_name and MP.UTILS.get_deck_key_from_name(replay.deck)
	if deck_key and G and G.P_CENTERS and G.P_CENTERS[deck_key] then
		if Back and get_deck_from_name then
			G.GAME.viewed_back = Back(get_deck_from_name(replay.deck))
		else
			G.GAME.viewed_back = G.P_CENTERS[deck_key]
		end
	end

	if BALATRO.exit_overlay_menu then BALATRO.exit_overlay_menu() end
	if G and G.FUNCS and G.FUNCS.start_run then
		G.FUNCS.start_run(e, {
			seed = replay.seed,
			stake = tonumber(replay.stake) or 1,
		})
	else
		BALATRO.start_run({
			seed = replay.seed,
			stake = tonumber(replay.stake) or 1,
		})
	end

	if MP.UI and MP.UI.refresh_lives_hud_binding then
		MP.UI.refresh_lives_hud_binding({ force = true })
	end
	return true
end

function GHOST.is_ruleset_supported(replay)
	if not (replay and replay.ruleset) then return true end
	return MP.Rulesets and MP.Rulesets[normalize_ruleset_key(replay.ruleset)] ~= nil
end

function GHOST.format_score(score_text)
	local score = score_from_string(score_text)
	if MP.INSANE_INT and MP.INSANE_INT.to_string then
		return MP.INSANE_INT.to_string(score)
	end
	return tostring(score_text or "0")
end

function GHOST.build_label(replay)
	local result_text = replay.winner == "player" and "W" or "L"
	local player_display = replay.player_name or "?"
	local nemesis_display = replay.nemesis_name or "?"
	local ante_display = tostring(replay.final_ante or "?")
	local timestamp_display = replay.timestamp and os.date("%m/%d", replay.timestamp) or ""
	local game_tag = ""
	if replay._game_index and replay._game_count and replay._game_count > 1 then
		game_tag = string.format(" [%d/%d]", replay._game_index, replay._game_count)
	end

	return string.format(
		"%s %s v %s A%s %s%s",
		result_text,
		player_display,
		nemesis_display,
		ante_display,
		timestamp_display,
		game_tag
	)
end

local function get_log_parser()
	if MP.LOG_PARSER then return MP.LOG_PARSER end
	if MP.PLATFORM and MP.PLATFORM.SMODS and MP.PLATFORM.SMODS.load_mod_file then
		return MP.PLATFORM.SMODS.load_mod_file("lib/log_parser.lua", { required = false })
	end
	return nil
end

local function load_json_replay(filepath, filename)
	local ok_json, json = pcall(require, "json")
	if not ok_json or not json or not json.decode then return nil end
	local content = NFS and NFS.read and NFS.read(filepath) or nil
	if not content then return nil end

	local ok, replay = pcall(json.decode, content)
	if not ok or not replay or not replay.ante_snapshots then
		sendWarnMessage("Failed to parse replay: " .. tostring(filename), "MULTIPLAYER")
		return nil
	end

	local fixed = {}
	for key, value in pairs(replay.ante_snapshots) do
		fixed[tonumber(key) or key] = value
	end
	replay.ante_snapshots = fixed
	replay.ruleset = normalize_ruleset_key(replay.ruleset)
	replay.gamemode = normalize_gamemode_key(replay.gamemode)
	replay._source = "file"
	replay._filename = filename
	return replay
end

local function parse_log_into_replays(log_parser, content, filename, source)
	local out = {}
	if not (content and log_parser) then return out end

	local ok, game_records = pcall(log_parser.process_log, content)
	if not (ok and game_records) then
		sendWarnMessage("Failed to parse log: " .. tostring(filename), "MULTIPLAYER")
		return out
	end

	local total = #game_records
	for index, game in ipairs(game_records) do
		local ok_replay, replay = pcall(log_parser.to_replay, game)
		if ok_replay and replay and replay.ante_snapshots and next(replay.ante_snapshots) then
			replay._source = source
			replay._filename = filename
			replay._game_index = index
			replay._game_count = total
			out[#out + 1] = replay
		end
	end
	return out
end

function GHOST.load_folder_replays()
	local log_parser = get_log_parser()
	local replays_dir = MP.path .. "/replays"
	if not (NFS and NFS.getInfo and NFS.getDirectoryItemsInfo) then return {} end

	local dir_info = NFS.getInfo(replays_dir)
	if not dir_info or dir_info.type ~= "directory" then return {} end

	local ok_items, items = pcall(NFS.getDirectoryItemsInfo, replays_dir)
	if not ok_items or type(items) ~= "table" then return {} end

	local results = {}
	for _, item in ipairs(items) do
		if item.type == "file" and item.name:match("%.log$") then
			local content = NFS.read(replays_dir .. "/" .. item.name)
			for _, replay in ipairs(parse_log_into_replays(log_parser, content, item.name, "file")) do
				results[#results + 1] = replay
			end
		elseif item.type == "file" and item.name:match("%.json$") then
			local replay = load_json_replay(replays_dir .. "/" .. item.name, item.name)
			if replay then results[#results + 1] = replay end
		end
	end

	table.sort(results, function(a, b)
		return (a.timestamp or 0) > (b.timestamp or 0)
	end)
	return results
end

local function lovely_log_dir()
	local ok, lovely = pcall(require, "lovely")
	if not (ok and lovely and lovely.log_path) then return nil end
	local dir = lovely.log_path:match("(.*)[/\\]")
	if not dir or dir == "" then return nil end
	return dir
end

function GHOST.load_lovely_log_replays(limit)
	limit = limit or 10
	local dir = lovely_log_dir()
	if not (dir and NFS and NFS.getDirectoryItemsInfo and NFS.read) then return {} end

	local ok_items, items = pcall(NFS.getDirectoryItemsInfo, dir)
	if not ok_items or type(items) ~= "table" then return {} end

	local logs = {}
	for _, item in ipairs(items) do
		if item.type == "file" and item.name:match("%.log$") then
			logs[#logs + 1] = item
		end
	end
	table.sort(logs, function(a, b)
		return (a.modtime or 0) > (b.modtime or 0)
	end)

	local log_parser = get_log_parser()
	local results = {}
	for _, item in ipairs(logs) do
		local content = NFS.read(dir .. "/" .. item.name)
		for _, replay in ipairs(parse_log_into_replays(log_parser, content, item.name, "lovely_log")) do
			results[#results + 1] = replay
		end
		if #results >= limit then break end
	end

	table.sort(results, function(a, b)
		return (a.timestamp or 0) > (b.timestamp or 0)
	end)
	while #results > limit do
		results[#results] = nil
	end
	return results
end

return GHOST
