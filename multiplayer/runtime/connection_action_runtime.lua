MP.ACTIONS = MP.ACTIONS or {}

local connection_action_runtime = {}
local cached_network_client_state = nil
local has_required_methods = MP.UTILS.has_required_methods

local CONNECTION_IDENTITY_METHODS = {
	"is_player_id_valid",
	"set_username",
	"set_blind_col",
}

local function ensure_network_client_state()
	if cached_network_client_state then
		return cached_network_client_state
	end

	local loaded = MP.PLATFORM.SMODS.load_mod_file("multiplayer/runtime/network_client_state.lua", { required = true })
	if
		type(loaded) == "table"
		and has_required_methods(MP.CONNECTION_IDENTITY, CONNECTION_IDENTITY_METHODS)
	then
		cached_network_client_state = loaded
		return loaded
	end

	return nil
end

function connection_action_runtime.connect()
	MP.CONNECTION_WIRE.send_connect()
end

function connection_action_runtime.update_player_usernames()
	if MP.UI and MP.UI.request_lobby_main_menu_refresh then
		MP.UI.request_lobby_main_menu_refresh()
	else
		MP.refresh_lobby_main_menu()
	end
end

function connection_action_runtime.is_player_id_valid()
	if not ensure_network_client_state() then
		return false
	end

	return MP.CONNECTION_IDENTITY.is_player_id_valid()
end

function connection_action_runtime.set_username(username)
	if not ensure_network_client_state() then
		return nil
	end

	return MP.CONNECTION_IDENTITY.set_username(username)
end

function connection_action_runtime.set_blind_col(num)
	if not ensure_network_client_state() then
		return nil
	end

	return MP.CONNECTION_IDENTITY.set_blind_col(num)
end

MP.ACTIONS.connect = connection_action_runtime.connect
MP.ACTIONS.update_player_usernames = connection_action_runtime.update_player_usernames
MP.is_player_id_valid = connection_action_runtime.is_player_id_valid
MP.ACTIONS.set_username = connection_action_runtime.set_username
MP.ACTIONS.set_blind_col = connection_action_runtime.set_blind_col
