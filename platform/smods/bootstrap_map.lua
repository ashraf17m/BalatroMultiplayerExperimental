MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.SMODS = MP.PLATFORM.SMODS or {}

local bootstrap_map = MP.PLATFORM.SMODS.BOOTSTRAP_MAP or {}
MP.PLATFORM.SMODS.BOOTSTRAP_MAP = bootstrap_map

if bootstrap_map._loaded then
	return
end
bootstrap_map._loaded = true

local NETWORK_RUNTIME_FILES = {
	"networking/action_handlers.lua",
	"multiplayer/runtime/network_runtime_loop.lua",
	"multiplayer/runtime/feature_runtime.lua",
	"multiplayer/runtime/coop_save_runtime.lua",
	"multiplayer/runtime/end_game_runtime.lua",
}

local NETWORK_DISPATCH_FILES = {
	"multiplayer/runtime/action_dispatch.lua",
}

local NETWORK_SENDER_FILES = {}

local OBJECT_DIRECTORIES = {
	"objects",
}

local CORE_RUNTIME_FILES = {
	"platform/hooks/local_feature_hooks.lua",
	"platform/hooks/spectator_record_hooks.lua",
	"multiplayer/runtime/game_update_cycle.lua",
	"multiplayer/runtime/coop_boss_blind_runtime.lua",
	"multiplayer/runtime/deck_registry.lua",
	"multiplayer/runtime/ante_timer_runtime.lua",
	"multiplayer/runtime/local_timer_runtime.lua",
	"multiplayer/runtime/session_runtime.lua",
	"multiplayer/runtime/connection_flow.lua",
	"multiplayer/runtime/lobby_runtime.lua",
	"multiplayer/runtime/match_runtime.lua",
	"multiplayer/runtime/network_state_apply.lua",
	"multiplayer/runtime/resume_runtime.lua",
	"multiplayer/runtime/action_recorder.lua",
	"multiplayer/runtime/action_playback.lua",
	"multiplayer/coop_save_persistence.lua",
}

local RULESET_LAYER_DIRECTORIES = {
	"layers",
}

local RULESET_DIRECTORIES = {
	"rulesets",
}

local TEAM_SYNC_FEATURE_FILES = {
	"multiplayer/features/team_card_sync.lua",
	"multiplayer/features/team_hand_level_sync.lua",
}

local PROTOCOL_BOUNDARY_FILES = {
	"multiplayer/protocol/_init.lua",
	"multiplayer/protocol/manifest.lua",
	"multiplayer/protocol/schema_flags.lua",
	"multiplayer/protocol/decoder.lua",
	"multiplayer/protocol/adapter.lua",
	"multiplayer/protocol/connection_wire.lua",
	"multiplayer/protocol/lobby_wire.lua",
	"multiplayer/protocol/match_wire.lua",
	"multiplayer/protocol/feature_wire.lua",
	"multiplayer/protocol/coop_save_wire.lua",
}

local UI_BOUNDARY_FILES = {
	"multiplayer/ui/runtime_api.lua",
	"multiplayer/ui/ui_utils.lua",
	"multiplayer/ui/overlays.lua",
	"multiplayer/ui/lobby_menu.lua",
	"multiplayer/ui/players_hud.lua",
	"multiplayer/ui/lobby_players.lua",
	"multiplayer/ui/lobby_options.lua",
	"multiplayer/ui/end_game_overlay.lua",
	"multiplayer/ui/spectator_viewport_view.lua",
	"multiplayer/ui/coop_blind_curve_preview.lua",
	"multiplayer/ui/main_menu_selection.lua",
	"multiplayer/ui/main_menu_custom_ruleset_editor.lua",
	"multiplayer/ui/main_menu.lua",
	"multiplayer/ui/match_lobby_info.lua",
	"multiplayer/ui/blind_hud_controller.lua",
	"multiplayer/ui/timer_hud_view.lua",
	"multiplayer/ui/shared_score_hud_view.lua",
	"multiplayer/ui/game_ui_effects.lua",
	"multiplayer/ui/blind_choice.lua",
	"multiplayer/ui/smods_menu.lua",
}

local CONTENT_ADAPTER_FILES = {
	"multiplayer/content/runtime_adapter.lua",
}

bootstrap_map.NETWORK_RUNTIME_FILES = NETWORK_RUNTIME_FILES
bootstrap_map.NETWORK_DISPATCH_FILES = NETWORK_DISPATCH_FILES
bootstrap_map.NETWORK_SENDER_FILES = NETWORK_SENDER_FILES
bootstrap_map.OBJECT_DIRECTORIES = OBJECT_DIRECTORIES
bootstrap_map.CORE_RUNTIME_FILES = CORE_RUNTIME_FILES
bootstrap_map.RULESET_LAYER_DIRECTORIES = RULESET_LAYER_DIRECTORIES
bootstrap_map.RULESET_DIRECTORIES = RULESET_DIRECTORIES
bootstrap_map.TEAM_SYNC_FEATURE_FILES = TEAM_SYNC_FEATURE_FILES
bootstrap_map.PROTOCOL_BOUNDARY_FILES = PROTOCOL_BOUNDARY_FILES
bootstrap_map.UI_BOUNDARY_FILES = UI_BOUNDARY_FILES
bootstrap_map.CONTENT_ADAPTER_FILES = CONTENT_ADAPTER_FILES
