-- Credit to @MathIsFun_ for creating TheOrder, which this integration is a modified copy of

local function require_the_order_module(relative_path)
	local loaded = MP.PLATFORM.SMODS.load_mod_file(relative_path, { required = true })
	if loaded == nil then
		sendWarnMessage("Failed to load required The Order compatibility module: " .. relative_path, "MULTIPLAYER")
		return false
	end

	return true
end

local the_order_modules = {
	"compatibility/the_order/helpers.lua",
	"compatibility/the_order/card_generation.lua",
	"compatibility/the_order/round_targets.lua",
	"compatibility/the_order/shop_queues.lua",
	"compatibility/the_order/randomness.lua",
}

for _, relative_path in ipairs(the_order_modules) do
	if not require_the_order_module(relative_path) then
		return
	end
end
