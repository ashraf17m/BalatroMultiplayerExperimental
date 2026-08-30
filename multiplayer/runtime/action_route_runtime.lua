MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}

local action_route_runtime = {}

local SYSTEM_HELLO_ACK_SCHEMA_ID = MP.PROTOCOL.get_schema_id("system", "hello_ack") or "system.helloAck.v2"
local LOBBY_SNAPSHOT_SCHEMA_ID = MP.PROTOCOL.get_schema_id("lobby", "snapshot") or "lobby.snapshot.v2"
local MATCH_STATE_SCHEMA_ID = MP.PROTOCOL.get_schema_id("match", "state") or "match.state.v2"
local TEAM_STATE_SCHEMA_ID = MP.PROTOCOL.get_schema_id("team", "state") or "team.state.v2"
local SYNC_STATE_SCHEMA_ID = MP.PROTOCOL.get_schema_id("sync", "state") or "sync.state.v2"
local ENDGAME_STATE_SCHEMA_ID = MP.PROTOCOL.get_schema_id("endgame", "state") or "endgame.state.v2"
local FEATURE_EVENT_SCHEMA_ID = MP.PROTOCOL.get_schema_id("feature", "event") or "feature.event.v2"
local COOP_SAVE_STATE_SCHEMA_ID = MP.PROTOCOL.get_schema_id("coopSave", "state") or "coopSave.state.v2"
local build_protocol_route_key = MP.PROTOCOL.build_route_key

local function get_route_helpers()
	return
		MP.NETWORKING_INTERNAL.route_noargs,
		MP.NETWORKING_INTERNAL.route_field,
		MP.NETWORKING_INTERNAL.route_fields,
		MP.NETWORKING_INTERNAL.route_action
end

function action_route_runtime.build_local_action_routes()
	local route_noargs, route_field = get_route_helpers()

	return {
		disconnected = route_noargs("handle_disconnected"),
		reconnecting = route_noargs("handle_reconnecting"),
		error = route_field("handle_error", "message"),
		keepAlive = route_noargs("handle_keep_alive"),
		keepAliveAck = function()
		end,
	}
end

function action_route_runtime.build_protocol_v2_lobby_routes()
	local route_noargs, route_field, route_fields, route_action = get_route_helpers()

	return {
		[build_protocol_route_key("system", "connected", SYSTEM_HELLO_ACK_SCHEMA_ID)] = route_noargs("handle_connected"),
		[build_protocol_route_key("system", "requestVersion", SYSTEM_HELLO_ACK_SCHEMA_ID)] = route_noargs("handle_version"),
		[build_protocol_route_key("system", "error", SYSTEM_HELLO_ACK_SCHEMA_ID)] = route_fields(
			"handle_error",
			{ "message", "display" }
		),
		[build_protocol_route_key("lobby", "joined", LOBBY_SNAPSHOT_SCHEMA_ID)] = route_fields("handle_joined_lobby", {
			"code",
			"type",
			"lobbyType",
			"reconnectToken",
			"playerId",
			"options",
			"players",
			"isHost",
			"isInGame",
			"isCoopSaveRestore",
		}),
		[build_protocol_route_key("lobby", "rejoined", LOBBY_SNAPSHOT_SCHEMA_ID)] = route_fields("handle_rejoined_lobby", {
			"code",
			"type",
			"lobbyType",
			"reconnectToken",
			"playerId",
			"options",
			"players",
			"isHost",
			"isInGame",
			"isCoopSaveRestore",
		}),
		[build_protocol_route_key("lobby", "snapshot", LOBBY_SNAPSHOT_SCHEMA_ID)] = route_fields("handle_lobby_info", {
			"players",
			"isHost",
			"isInGame",
			"lobbyType",
			"isCoopSaveRestore",
		}),
		[build_protocol_route_key("lobby", "list", LOBBY_SNAPSHOT_SCHEMA_ID)] = route_field(
			"handle_lobby_list",
			"lobbies"
		),
		[build_protocol_route_key("lobby", "joinRequest", LOBBY_SNAPSHOT_SCHEMA_ID)] = route_field(
			"handle_lobby_join_request_received",
			"request"
		),
		[build_protocol_route_key("lobby", "joinPending", LOBBY_SNAPSHOT_SCHEMA_ID)] = route_fields(
			"handle_lobby_join_request_pending",
			{ "code", "requestId", "expiresAt", "expiresInMs" }
		),
		[build_protocol_route_key("lobby", "joinRejected", LOBBY_SNAPSHOT_SCHEMA_ID)] = route_fields(
			"handle_lobby_join_request_rejected",
			{ "code", "message", "requestId", "reason" }
		),
		[build_protocol_route_key("lobby", "joinRequestClosed", LOBBY_SNAPSHOT_SCHEMA_ID)] = route_fields(
			"handle_lobby_join_request_closed",
			{ "code", "requestId", "reason" }
		),
		[build_protocol_route_key("lobby", "playerJoined", LOBBY_SNAPSHOT_SCHEMA_ID)] = route_field(
			"handle_lobby_player_joined",
			"player"
		),
		[build_protocol_route_key("lobby", "playerUpdated", LOBBY_SNAPSHOT_SCHEMA_ID)] = route_field(
			"handle_lobby_player_updated",
			"player"
		),
		[build_protocol_route_key("lobby", "playerLeft", LOBBY_SNAPSHOT_SCHEMA_ID)] = route_fields(
			"handle_lobby_player_left",
			{ "playerId", "isHost", "ownerPlayerId", "assignments" }
		),
		[build_protocol_route_key("lobby", "typeChanged", LOBBY_SNAPSHOT_SCHEMA_ID)] = route_fields(
			"handle_lobby_type_changed",
			{ "lobbyType", "players" }
		),
		[build_protocol_route_key("lobby", "playerTeam", LOBBY_SNAPSHOT_SCHEMA_ID)] = route_fields("handle_lobby_player_team", {
			"playerId",
			"team",
		}),
		[build_protocol_route_key("lobby", "nemesisAssignments", LOBBY_SNAPSHOT_SCHEMA_ID)] = route_field(
			"handle_lobby_nemesis_assignments",
			"assignments"
		),
		[build_protocol_route_key("lobby", "options", LOBBY_SNAPSHOT_SCHEMA_ID)] = route_action("handle_lobby_options"),
		[build_protocol_route_key("lobby", "enemyDisconnected", LOBBY_SNAPSHOT_SCHEMA_ID)] = route_fields(
			"handle_enemy_disconnected",
			{ "username", "timeout", "playerId" }
		),
		[build_protocol_route_key("lobby", "enemyReconnected", LOBBY_SNAPSHOT_SCHEMA_ID)] = route_fields(
			"handle_enemy_reconnected",
			{ "username", "playerId" }
		),
		[build_protocol_route_key("lobby", "kicked", LOBBY_SNAPSHOT_SCHEMA_ID)] = route_field("handle_kicked_from_lobby", "message"),
	}
end

function action_route_runtime.build_protocol_v2_match_routes()
	local route_noargs, route_field, route_fields, route_action = get_route_helpers()

	return {
		[build_protocol_route_key("match", "startGame", MATCH_STATE_SCHEMA_ID)] = route_fields("handle_start_game", {
			"seed",
			"stake",
			"back",
			"challenge",
			"sleeve",
			"cocktail",
		}),
		[build_protocol_route_key("match", "startBlind", MATCH_STATE_SCHEMA_ID)] = route_fields("handle_start_blind", {
			"blindRow",
			"blindKind",
			"duelRole",
			"blindTarget",
		}),
		[build_protocol_route_key("match", "endPvp", MATCH_STATE_SCHEMA_ID)] = route_fields(
			"handle_end_pvp",
			{ "lost", "pvpTimerLost" }
		),
		[build_protocol_route_key("match", "endCoopBlind", MATCH_STATE_SCHEMA_ID)] = route_field(
			"handle_end_coop_blind",
			"lost"
		),
		[build_protocol_route_key("match", "enemyInfo", MATCH_STATE_SCHEMA_ID)] = route_action("handle_enemy_info"),
		[build_protocol_route_key("match", "playerInfo", MATCH_STATE_SCHEMA_ID)] = route_fields("handle_player_info", {
			"lives",
			"lifeLossReason",
			"previousLives",
			"team",
		}),
		[build_protocol_route_key("team", "moneyUpdate", TEAM_STATE_SCHEMA_ID)] = route_fields(
			"handle_money_update",
			{ "money", "delta", "sourcePlayerId" }
		),
		[build_protocol_route_key("match", "enemyLocation", MATCH_STATE_SCHEMA_ID)] = route_action("handle_enemy_location"),
		[build_protocol_route_key("match", "coopBlindPreview", MATCH_STATE_SCHEMA_ID)] = route_fields(
			"handle_coop_blind_preview",
			{ "previewKey", "targets" }
		),
		[build_protocol_route_key("match", "coopBossBlind", MATCH_STATE_SCHEMA_ID)] = route_fields(
			"handle_coop_boss_blind",
			{ "phase", "ante", "revision", "sourcePlayerId", "bossKey", "isReroll" }
		),
		[build_protocol_route_key("team", "skipBlind", TEAM_STATE_SCHEMA_ID)] = route_fields(
			"handle_team_skip_blind",
			{ "blindRow", "ante" }
		),
		[build_protocol_route_key("sync", "teamCard", SYNC_STATE_SCHEMA_ID)] = route_action("handle_team_card_sync"),
		[build_protocol_route_key("sync", "teamHandLevel", SYNC_STATE_SCHEMA_ID)] = route_action("handle_team_hand_level_sync"),
		[build_protocol_route_key("match", "startAnteTimer", MATCH_STATE_SCHEMA_ID)] = route_fields(
			"handle_start_ante_timer",
			{ "time", "serverNow", "deadlineAt", "timerGeneration" }
		),
		[build_protocol_route_key("match", "pauseAnteTimer", MATCH_STATE_SCHEMA_ID)] = route_fields(
			"handle_pause_ante_timer",
			{ "time", "serverNow", "deadlineAt", "timerGeneration" }
		),
		[build_protocol_route_key("match", "speedrun", MATCH_STATE_SCHEMA_ID)] = route_noargs("handle_speedrun"),
	}
end

function action_route_runtime.build_protocol_v2_feature_routes()
	local route_noargs, route_field, route_fields, route_action = get_route_helpers()

	return {
		[build_protocol_route_key("endgame", "win", ENDGAME_STATE_SCHEMA_ID)] = route_noargs("handle_win_game"),
		[build_protocol_route_key("endgame", "alone", ENDGAME_STATE_SCHEMA_ID)] = route_noargs("handle_alone_game"),
		[build_protocol_route_key("endgame", "lose", ENDGAME_STATE_SCHEMA_ID)] = route_noargs("handle_lose_game"),
		[build_protocol_route_key("endgame", "spectatorEnd", ENDGAME_STATE_SCHEMA_ID)] = route_noargs("handle_match_ended"),
		[build_protocol_route_key("feature", "sendPhantom", FEATURE_EVENT_SCHEMA_ID)] = route_fields(
			"handle_send_phantom",
			{ "key", "playerId" }
		),
		[build_protocol_route_key("feature", "removePhantom", FEATURE_EVENT_SCHEMA_ID)] = route_fields(
			"handle_remove_phantom",
			{ "key", "playerId" }
		),
		[build_protocol_route_key("feature", "asteroid", FEATURE_EVENT_SCHEMA_ID)] = route_noargs("handle_asteroid"),
		[build_protocol_route_key("feature", "letsGoGamblingNemesis", FEATURE_EVENT_SCHEMA_ID)] = route_noargs(
			"handle_lets_go_gambling_nemesis"
		),
		[build_protocol_route_key("feature", "eatPizza", FEATURE_EVENT_SCHEMA_ID)] = route_field("handle_eat_pizza", "whole"),
		[build_protocol_route_key("feature", "soldJoker", FEATURE_EVENT_SCHEMA_ID)] = route_field("handle_sold_joker", "playerId"),
		[build_protocol_route_key("feature", "spentLastShop", FEATURE_EVENT_SCHEMA_ID)] = route_fields(
			"handle_spent_last_shop",
			{ "playerId", "amount" }
		),
		[build_protocol_route_key("feature", "magnet", FEATURE_EVENT_SCHEMA_ID)] = route_noargs("handle_magnet"),
		[build_protocol_route_key("feature", "magnetResponse", FEATURE_EVENT_SCHEMA_ID)] = route_field(
			"handle_magnet_response",
			"key"
		),
		[build_protocol_route_key("feature", "moddedAction", FEATURE_EVENT_SCHEMA_ID)] = route_action("handle_modded_action"),
		[build_protocol_route_key("endgame", "getEndGameJokers", ENDGAME_STATE_SCHEMA_ID)] = route_field(
			"handle_get_end_game_jokers",
			"requesterPlayerId"
		),
		[build_protocol_route_key("endgame", "receiveEndGameJokers", ENDGAME_STATE_SCHEMA_ID)] = route_fields(
			"handle_receive_end_game_jokers",
			{ "keys", "sourcePlayerId" }
		),
		[build_protocol_route_key("endgame", "getNemesisDeck", ENDGAME_STATE_SCHEMA_ID)] = route_field(
			"handle_get_nemesis_deck",
			"requesterPlayerId"
		),
		[build_protocol_route_key("endgame", "receiveNemesisDeck", ENDGAME_STATE_SCHEMA_ID)] = route_fields(
			"handle_receive_nemesis_deck",
			{ "cards", "sourcePlayerId" }
		),
		[build_protocol_route_key("endgame", "getEndGameSummary", ENDGAME_STATE_SCHEMA_ID)] = route_field(
			"handle_get_end_game_summary",
			"requesterPlayerId"
		),
		[build_protocol_route_key("endgame", "receiveEndGameSummary", ENDGAME_STATE_SCHEMA_ID)] = route_fields(
			"handle_receive_end_game_summary",
			{ "summary", "sourcePlayerId" }
		),
		[build_protocol_route_key("feature", "jimboAppear", FEATURE_EVENT_SCHEMA_ID)] = route_fields(
			"handle_jimbo_appear",
			{ "pos", "text" }
		),
		[build_protocol_route_key("feature", "jimboTalk", FEATURE_EVENT_SCHEMA_ID)] = route_field("handle_jimbo_talk", "text"),
		[build_protocol_route_key("feature", "jimboMove", FEATURE_EVENT_SCHEMA_ID)] = route_field("handle_jimbo_move", "pos"),
		[build_protocol_route_key("feature", "jimboRemove", FEATURE_EVENT_SCHEMA_ID)] = route_noargs("handle_jimbo_remove"),
		[build_protocol_route_key("feature", "spectatorActionStream", FEATURE_EVENT_SCHEMA_ID)] = route_action(
			"handle_spectator_action_stream"
		),
		[build_protocol_route_key("feature", "spectatorHistory", FEATURE_EVENT_SCHEMA_ID)] = route_action(
			"handle_spectator_history"
		),
		[build_protocol_route_key("feature", "spectatorRequestSnapshot", FEATURE_EVENT_SCHEMA_ID)] = route_action(
			"handle_spectator_request_snapshot"
		),
		[build_protocol_route_key("feature", "spectatorReceiveSnapshot", FEATURE_EVENT_SCHEMA_ID)] = route_action(
			"handle_spectator_receive_snapshot"
		),
	}
end

function action_route_runtime.build_protocol_v2_coop_save_routes()
	local _, _, route_fields, route_action = get_route_helpers()

	return {
		[build_protocol_route_key("coopSave", "vote", COOP_SAVE_STATE_SCHEMA_ID)] = route_fields(
			"handle_coop_save_vote",
			{ "voters", "required", "committed", "saveId", "save" }
		),
		[build_protocol_route_key("coopSave", "start", COOP_SAVE_STATE_SCHEMA_ID)] = route_action(
			"handle_start_coop_save"
		),
	}
end

MP.NETWORKING_INTERNAL.LOCAL_ACTION_ROUTES = action_route_runtime.build_local_action_routes()
MP.NETWORKING_INTERNAL.PROTOCOL_V2_LOBBY_ROUTES = action_route_runtime.build_protocol_v2_lobby_routes()
MP.NETWORKING_INTERNAL.PROTOCOL_V2_MATCH_ROUTES = action_route_runtime.build_protocol_v2_match_routes()
MP.NETWORKING_INTERNAL.PROTOCOL_V2_FEATURE_ROUTES = action_route_runtime.build_protocol_v2_feature_routes()
MP.NETWORKING_INTERNAL.PROTOCOL_V2_COOP_SAVE_ROUTES = action_route_runtime.build_protocol_v2_coop_save_routes()
