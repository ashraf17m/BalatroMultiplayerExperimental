local function require_state_accessor_module(relative_path)
	local loaded = MP.PLATFORM.SMODS.load_mod_file(relative_path, { required = true })
	if loaded == nil then
		sendWarnMessage("Failed to load required state accessor module: " .. relative_path, "MULTIPLAYER")
		return false
	end

	return true
end

local state_accessor_modules = {
	"lib/state_accessors/mode_accessors.lua",
	"lib/state_accessors/lobby_accessors.lua",
	"lib/state_accessors/team_accessors.lua",
	"lib/state_accessors/opponent_accessors.lua",
	"lib/state_accessors/money_accessors.lua",
}

for _, relative_path in ipairs(state_accessor_modules) do
	if not require_state_accessor_module(relative_path) then
		return
	end
end
