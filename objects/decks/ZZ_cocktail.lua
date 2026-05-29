local runtime = MP.PLATFORM.SMODS.load_mod_file("objects/decks/cocktail/runtime.lua", { required = true })
if runtime == nil then return nil end

local selector = MP.PLATFORM.SMODS.load_mod_file("objects/decks/cocktail/selector.lua", { required = true })
if selector == nil or type(selector.install) ~= "function" or selector.install(runtime) == false then
	return nil
end

local display = MP.PLATFORM.SMODS.load_mod_file("objects/decks/cocktail/display.lua", { required = true })
if display == nil or type(display.install) ~= "function" or display.install(runtime) == false then
	return nil
end

return runtime
