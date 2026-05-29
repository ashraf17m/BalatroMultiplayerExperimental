local HOTKEY = "f8"
local USERNAME_PREFIX = "Testing"
local MIN_SUFFIX = 100000
local MAX_SUFFIX = 999999

local function random_testing_username()
	return USERNAME_PREFIX .. tostring(math.random(MIN_SUFFIX, MAX_SUFFIX))
end

local function show_username_notice(username)
	local message = "Testing username: " .. tostring(username)
	if type(attention_text) == "function" and G and G.C then
		attention_text({
			text = message,
			scale = 0.8,
			hold = 1,
			align = "cm",
			backdrop_colour = G.C.SECONDARY_SET and G.C.SECONDARY_SET.Tarot or G.C.BLUE,
			silent = true,
		})
	elseif sendDebugMessage then
		sendDebugMessage(message, "MULTIPLAYER")
	end
end

local function save_testing_username(username)
	if MP.UTILS and MP.UTILS.save_username then
		MP.UTILS.save_username(username)
	elseif MP.PLATFORM and MP.PLATFORM.SMODS and MP.PLATFORM.SMODS.set_config_value then
		MP.PLATFORM.SMODS.set_config_value("username", username, MP)
	end

	if MP.save_current_config then
		MP.save_current_config()
	end
end

local function apply_random_testing_username()
	local username = random_testing_username()
	save_testing_username(username)
	show_username_notice(username)
	return username
end

if MP.HOOKS and MP.HOOKS.register_method_hook and love and type(love.keypressed) == "function" then
	MP.HOOKS.register_method_hook(love, "love", "keypressed", "mp.testing_tools.temp_username_hotkey", {
		before = function(ctx)
			local args = ctx.args or {}
			local key = tostring(args[1] or ""):lower()
			if key == HOTKEY then
				apply_random_testing_username()
				ctx.skip_original = true
				ctx.results = { n = 0 }
			end
		end,
	})
end

return true
