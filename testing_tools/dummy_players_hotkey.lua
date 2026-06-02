local HOTKEY = "f9"
local NAME_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

MP.TESTING = MP.TESTING or {}
local testing = MP.TESTING
local testing_dummy_players = {
	players = {},
	counter = 0,
}

local function get_runtime()
	return testing_dummy_players
end

local function random_dummy_name()
	local name = {}
	for i = 1, 5 do
		local index = math.random(1, #NAME_CHARS)
		name[i] = NAME_CHARS:sub(index, index)
	end
	return table.concat(name)
end

local function get_dummy_lives()
	local lobby_config = MP.LOBBY and MP.LOBBY.config or {}
	return lobby_config.starting_lives or MP.DEFAULT_STARTING_LIVES or 4
end

local function create_dummy_player()
	local runtime = get_runtime()
	runtime.counter = (runtime.counter or 0) + 1
	local team = ((runtime.counter - 1) % (MP.MAX_TEAMS or 4)) + 1

	return {
		id = "mp_testing_dummy_" .. tostring(runtime.counter),
		username = random_dummy_name(),
		blind_col = math.random(1, 25),
		location = MP.UI and MP.UI.localize_location and MP.UI.localize_location("loc_selecting") or "Selecting a Blind",
		raw_location = "loc_selecting",
		config = { Mods = {} },
		cached = true,
		is_owner = false,
		is_ready = false,
		is_in_match = true,
		is_disconnected = false,
		is_team_locked = true,
		is_dummy = true,
		can_kick = false,
		can_make_host = false,
		mod_count = 0,
		team = team,
		team_name = MP.TEAM_NAMES and MP.TEAM_NAMES[team] or "TEAM",
		score_text = "0",
		hands = MP.DEFAULT_HANDS_PER_ROUND or 4,
		lives = get_dummy_lives(),
	}
end

function testing.get_dummy_players()
	local runtime = get_runtime()
	return runtime.players or {}
end

local function request_dummy_player_refresh()
	if MP.GAME and MP.is_pvp_boss and MP.is_pvp_boss() then
		if MP.UI and MP.UI.request_player_list_refresh then
			MP.UI.request_player_list_refresh()
		end
	end

	if MP.UI and MP.UI.request_match_lobby_info_refresh then
		MP.UI.request_match_lobby_info_refresh()
	end

	if MP.UI and MP.UI.request_lobby_overlay_refresh then
		MP.UI.request_lobby_overlay_refresh()
	end
end

local function show_dummy_notice(player, count)
	if testing.show_notice then
		testing.show_notice(
			"Testing dummy: " .. tostring(player.username) .. " (" .. tostring(count) .. ")"
		)
	end
end

local function add_testing_dummy_player()
	local runtime = get_runtime()
	runtime.players = runtime.players or {}
	local player = create_dummy_player()
	runtime.players[#runtime.players + 1] = player
	request_dummy_player_refresh()
	show_dummy_notice(player, #runtime.players)
	return player
end

if MP.HOOKS and MP.HOOKS.register_method_hook and love and type(love.keypressed) == "function" then
	MP.HOOKS.register_method_hook(love, "love", "keypressed", "mp.testing_tools.dummy_players_hotkey", {
		before = function(ctx)
			local args = ctx.args or {}
			local key = tostring(args[1] or ""):lower()
			if key == HOTKEY then
				add_testing_dummy_player()
				ctx.skip_original = true
				ctx.results = { n = 0 }
			end
		end,
	})
end

return true
