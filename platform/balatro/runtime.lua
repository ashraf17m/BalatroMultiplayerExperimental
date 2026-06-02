MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.BALATRO = MP.PLATFORM.BALATRO or {}

local ui_loaded = MP.PLATFORM.SMODS.load_mod_file("platform/balatro/runtime_ui.lua", { required = true })
if ui_loaded == nil then return nil end

local hud_loaded = MP.PLATFORM.SMODS.load_mod_file("platform/balatro/runtime_hud.lua", { required = true })
if hud_loaded == nil then return nil end

local save_loaded = MP.PLATFORM.SMODS.load_mod_file("platform/balatro/runtime_save.lua", { required = true })
if save_loaded == nil then return nil end

local wrappers_loaded = MP.PLATFORM.SMODS.load_mod_file("platform/balatro/runtime_wrappers.lua", { required = true })
if wrappers_loaded == nil then return nil end

local input_loaded = MP.PLATFORM.SMODS.load_mod_file("platform/balatro/runtime_input.lua", { required = true })
if input_loaded == nil then return nil end

return MP.PLATFORM.BALATRO
