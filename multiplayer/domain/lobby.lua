MP.DOMAIN = MP.DOMAIN or {}
MP.DOMAIN.LOBBY = MP.DOMAIN.LOBBY or {}

local state_loaded = MP.PLATFORM.SMODS.load_mod_file("multiplayer/domain/lobby_state.lua", { required = true })
if state_loaded == nil then return nil end

local options_loaded = MP.PLATFORM.SMODS.load_mod_file("multiplayer/domain/lobby_options.lua", { required = true })
if options_loaded == nil then return nil end

local run_deck_loaded = MP.PLATFORM.SMODS.load_mod_file("multiplayer/domain/lobby_run_deck.lua", { required = true })
if run_deck_loaded == nil then return nil end

local updates_loaded = MP.PLATFORM.SMODS.load_mod_file("multiplayer/domain/lobby_updates.lua", { required = true })
if updates_loaded == nil then return nil end

local session_loaded = MP.PLATFORM.SMODS.load_mod_file("multiplayer/domain/lobby_session.lua", { required = true })
if session_loaded == nil then return nil end

return MP.DOMAIN.LOBBY
