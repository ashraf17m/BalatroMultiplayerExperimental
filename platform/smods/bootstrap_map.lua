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
	"multiplayer/runtime/connection_flow.lua",
	"multiplayer/runtime/lobby_message_runtime.lua",
	"multiplayer/runtime/match_flow_runtime.lua",
	"multiplayer/runtime/match_message_runtime.lua",
	"multiplayer/runtime/feature_message_runtime.lua",
	"multiplayer/runtime/coop_save_message_runtime.lua",
	"multiplayer/runtime/end_game_message_runtime.lua",
}

local NETWORK_DISPATCH_FILES = {
	"multiplayer/runtime/action_dispatch_runtime.lua",
	"multiplayer/runtime/action_route_runtime.lua",
}

local NETWORK_SENDER_FILES = {
	"multiplayer/runtime/connection_action_runtime.lua",
	"multiplayer/runtime/lobby_action_runtime.lua",
	"multiplayer/runtime/match_action_runtime.lua",
	"multiplayer/runtime/feature_action_runtime.lua",
	"multiplayer/runtime/coop_save_action_runtime.lua",
}

local OBJECT_DIRECTORIES = {
	"objects/editions",
	"objects/enhancements",
	"objects/seals",
	"objects/stickers",
	"objects/blinds",
	"objects/decks",
	"objects/jokers",
	"objects/jokers/sandbox",
	"objects/jokers/sandbox/extra-credit",
	"objects/jokers/standard",
	"objects/jokers/experimental",
	"objects/stakes",
	"objects/tags",
	"objects/consumables",
	"objects/consumables/sandbox",
	"objects/boosters",
	"objects/challenges",
}

local CORE_RUNTIME_FILES = {
	"platform/hooks/local_feature_hooks.lua",
	"platform/hooks/spectator_record_hooks.lua",
	"multiplayer/runtime/runtime_policy.lua",
	"multiplayer/runtime/game_update_cycle.lua",
	"multiplayer/runtime/coop_boss_blind_runtime.lua",
	"multiplayer/runtime/deck_registry.lua",
	"multiplayer/runtime/ante_timer_runtime.lua",
	"multiplayer/runtime/local_timer_runtime.lua",
	"multiplayer/runtime/connection_feedback.lua",
	"multiplayer/runtime/network_client_state.lua",
	"multiplayer/runtime/connection_resume.lua",
	"multiplayer/runtime/session_runtime.lua",
	"multiplayer/runtime/lobby_player_snapshot.lua",
	"multiplayer/runtime/match_lifecycle.lua",
	"multiplayer/runtime/network_state_apply.lua",
	"multiplayer/runtime/resume_runtime.lua",
	"multiplayer/runtime/action_recorder.lua",
	"multiplayer/runtime/spectator_log.lua",
	"multiplayer/runtime/action_playback.lua",
	"multiplayer/coop_save_persistence.lua",
}

local RULESET_LAYER_DIRECTORIES = {
	"layers",
}

local RULESET_DIRECTORIES = {
	"rulesets",
	"rulesets/experimental",
}

local TEAM_SYNC_FEATURE_FILES = {
	"multiplayer/features/team_card_sync_snapshot.lua",
	"multiplayer/features/team_card_sync_identity.lua",
	"multiplayer/features/team_card_sync_restore.lua",
	"multiplayer/features/team_card_sync_apply.lua",
	"multiplayer/features/team_card_sync_animation.lua",
	"multiplayer/features/team_card_sync_pending.lua",
	"multiplayer/features/team_hand_level_sync.lua",
}

local TEAM_SYNC_DIAGNOSTIC_FILES = {
	"testing_tools/diagnostics/team_card_sync.lua",
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
	"multiplayer/ui/main_menu_dev_warning.lua",
	"multiplayer/ui/ui_background_grouping.lua",
	"multiplayer/ui/ui_disableable_button.lua",
	"multiplayer/ui/ui_disableable_option_cycle.lua",
	"multiplayer/ui/ui_disableable_toggle.lua",
	"multiplayer/ui/ui_modlist_views.lua",
	"multiplayer/ui/end_game_view_api.lua",
	"multiplayer/ui/lobby_menu_hooks.lua",
	"multiplayer/ui/lobby_main_button_state.lua",
	"multiplayer/ui/lobby_deck_stake_button.lua",
	"multiplayer/ui/lobby_actions.lua",
	"multiplayer/ui/shortcuts_menu.lua",
	"multiplayer/ui/lobby_overlays.lua",
	"multiplayer/ui/lobby_menu.lua",
	"multiplayer/ui/players_hud_shared_score_view.lua",
	"multiplayer/ui/player_row_layout.lua",
	"multiplayer/ui/lobby_view_model.lua",
	"multiplayer/ui/player_row_view_model.lua",
	"multiplayer/ui/match_lobby_info_player_row_view_model.lua",
	"multiplayer/ui/lobby_players_rows_view.lua",
	"multiplayer/ui/lobby_players_display.lua",
	"multiplayer/ui/lobby_players_team_picker.lua",
	"multiplayer/ui/lobby_players_moderation_actions.lua",
	"multiplayer/ui/lobby_start_ready_button.lua",
	"multiplayer/ui/lobby_group_options.lua",
	"multiplayer/ui/lobby_warning_state.lua",
	"multiplayer/ui/version_mismatch_warning.lua",
	"multiplayer/ui/lobby_options_main.lua",
	"multiplayer/ui/lobby_options_advanced_tab.lua",
	"multiplayer/ui/end_game_view_model.lua",
	"multiplayer/ui/end_game_overlay_view.lua",
	"multiplayer/ui/end_game_overlay_controller.lua",
	"multiplayer/ui/end_game_overlay_hooks.lua",
	"multiplayer/ui/end_game_deck_overlay.lua",
	"multiplayer/ui/spectator_viewport_view.lua",
	"multiplayer/ui/lobby_option_state.lua",
	"multiplayer/ui/lobby_option_controls.lua",
	"multiplayer/ui/party_custom_winners_control.lua",
	"multiplayer/ui/lobby_option_controller.lua",
	"multiplayer/ui/main_menu_play_view_model.lua",
	"multiplayer/ui/main_menu_play_controller.lua",
	"multiplayer/ui/main_menu_selection_option_view.lua",
	"multiplayer/ui/main_menu_selection_info_view.lua",
	"multiplayer/ui/main_menu_modifiers_overlay.lua",
	"multiplayer/ui/main_menu_mutators_wall.lua",
	"multiplayer/ui/main_menu_custom_ruleset_editor.lua",
	"multiplayer/ui/main_menu_selection_cardarea_view.lua",
	"multiplayer/ui/main_menu_selection_view_model.lua",
	"multiplayer/ui/main_menu_selection_controller.lua",
	"multiplayer/ui/main_menu_title_card.lua",
	"multiplayer/ui/main_menu_shell.lua",
	"multiplayer/ui/players_hud_shared_teammate_view.lua",
	"multiplayer/ui/players_hud_view_model.lua",
	"multiplayer/ui/players_hud_blind_row_layout.lua",
	"multiplayer/ui/players_hud_shared_layout_view.lua",
	"multiplayer/ui/players_hud_ffa_view.lua",
	"multiplayer/ui/players_hud_teams_view.lua",
	"multiplayer/ui/players_hud_overlay_controller.lua",
	"multiplayer/ui/match_lobby_info_overlay.lua",
	"multiplayer/ui/match_lobby_info_team_money_state.lua",
	"multiplayer/ui/match_lobby_info_team_money_popup.lua",
	"multiplayer/ui/match_lobby_info_team_money.lua",
	"multiplayer/ui/match_lobby_info_players_view.lua",
	"multiplayer/ui/match_lobby_info_settings_view.lua",
	"multiplayer/ui/blind_chip_view.lua",
	"multiplayer/ui/blind_hud_controller.lua",
	"multiplayer/ui/timer_hud_view.lua",
	"multiplayer/ui/shared_score_hud_view.lua",
	"multiplayer/ui/game_ui_effects.lua",
	"multiplayer/ui/state_apply_effects.lua",
	"multiplayer/ui/blind_choice_state.lua",
	"multiplayer/ui/blind_choice_preview_view.lua",
	"multiplayer/ui/blind_choice_overlay_view.lua",
	"multiplayer/ui/blind_choice_view_model.lua",
	"multiplayer/ui/blind_choice_rows.lua",
	"multiplayer/ui/blind_choice_text.lua",
	"multiplayer/ui/blind_choice_ready.lua",
	"multiplayer/ui/blind_choice_skip.lua",
	"multiplayer/ui/blind_choice_controller.lua",
	"multiplayer/ui/confirmation_overlay.lua",
	"multiplayer/ui/ruleset_info_view.lua",
	"multiplayer/ui/jimbo_overlay.lua",
	"multiplayer/ui/smods_config_tab.lua",
	"multiplayer/ui/smods_credits_tab.lua",
	"multiplayer/ui/smods_customization_tab.lua",
	"multiplayer/ui/smods_menu_hooks.lua",
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
bootstrap_map.TEAM_SYNC_DIAGNOSTIC_FILES = TEAM_SYNC_DIAGNOSTIC_FILES
bootstrap_map.PROTOCOL_BOUNDARY_FILES = PROTOCOL_BOUNDARY_FILES
bootstrap_map.UI_BOUNDARY_FILES = UI_BOUNDARY_FILES
bootstrap_map.CONTENT_ADAPTER_FILES = CONTENT_ADAPTER_FILES
