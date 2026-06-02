local HOTKEY = "f8"
local USERNAME_LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
local MIN_SUFFIX = 0
local MAX_SUFFIX = 99

local function random_testing_username()
    local letter_index = math.random(1, #USERNAME_LETTERS)
    local letter = USERNAME_LETTERS:sub(letter_index, letter_index)
    return letter .. string.format("%02d", math.random(MIN_SUFFIX, MAX_SUFFIX))
end

local function show_username_notice(username)
	if MP.TESTING and MP.TESTING.show_notice then
		MP.TESTING.show_notice("Testing username: " .. tostring(username))
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
