MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.BALATRO = MP.PLATFORM.BALATRO or {}

local BALATRO = MP.PLATFORM.BALATRO
local build_traceback = MP.BOOTSTRAP_INTERNAL.build_traceback

function BALATRO.with_overlay_menu_guard(callback)
	if type(callback) ~= "function" then
		return nil
	end

	local original_overlay = BALATRO.get_overlay_menu()
	BALATRO.set_overlay_menu(original_overlay or true)

	local ok, result_a, result_b, result_c = xpcall(callback, function(err)
		return build_traceback(err)
	end)

	BALATRO.set_overlay_menu(original_overlay)

	if not ok then
		error(result_a)
	end

	return result_a, result_b, result_c
end

local wheelmoved_handlers = {}
local wheelmoved_router_installed = false

local function dispatch_wheelmoved_handlers(x, y)
	for _, handler in pairs(wheelmoved_handlers) do
		if type(handler) == "function" and handler(x, y) then
			return true
		end
	end

	return false
end

local function ensure_wheelmoved_router()
	if wheelmoved_router_installed or not (love and type(love) == "table") then
		return
	end

	if not (MP.HOOKS and MP.HOOKS.register_method_hook) then
		return
	end

	wheelmoved_router_installed = MP.HOOKS.register_method_hook(
		love,
		"love",
		"wheelmoved",
		"mp.platform.balatro.wheelmoved_router",
		{
			before = function(ctx)
				local args = ctx.args or {}
				if dispatch_wheelmoved_handlers(args[1], args[2]) then
					ctx.skip_original = true
					ctx.results = { n = 0 }
				end
			end,
		}
	)
end

function BALATRO.register_wheelmoved_handler(key, handler)
	if type(key) ~= "string" or key == "" or type(handler) ~= "function" then
		return false
	end

	ensure_wheelmoved_router()
	wheelmoved_handlers[key] = handler
	return true
end

function BALATRO.clear_wheelmoved_handler(key)
	if type(key) ~= "string" or key == "" then
		return false
	end

	wheelmoved_handlers[key] = nil
	return true
end

return BALATRO
