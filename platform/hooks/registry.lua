MP.HOOKS = MP.HOOKS or {}

local HOOKS = MP.HOOKS
local unpack_values = table.unpack or unpack

HOOKS.method_targets = HOOKS.method_targets or {}

local function pack_values(...)
	return { n = select("#", ...), ... }
end

local function unpack_packed(values)
	if not values then
		return
	end

	return unpack_values(values, 1, values.n or #values)
end

local build_hook_traceback =
	(MP.BOOTSTRAP_INTERNAL and MP.BOOTSTRAP_INTERNAL.build_traceback)
	or function(err) return tostring(err) end

local function emit_hook_diagnostic(message, warning)
	if warning and sendWarnMessage then
		sendWarnMessage(message, "MULTIPLAYER")
		return
	end

	if not warning and sendTraceMessage then
		sendTraceMessage(message, "MULTIPLAYER")
		return
	end

	if sendDebugMessage then
		sendDebugMessage(message, "MULTIPLAYER")
	end
end

local function report_hook_error(method_state, hook_key, phase, details)
	local summary = string.format(
		"Multiplayer hook failed (%s.%s:%s:%s)",
		tostring(method_state.target_name),
		tostring(method_state.method_name),
		tostring(hook_key),
		tostring(phase)
	)

	emit_hook_diagnostic(summary, true)

	if details and details ~= summary then
		emit_hook_diagnostic(details, false)
	end
end

local function run_hook(method_state, hook_key, phase, callback, ctx)
	local ok, err = xpcall(function()
		callback(ctx, ctx.self)
	end, build_hook_traceback)

	if not ok then
		report_hook_error(method_state, hook_key, phase, err)
	end
end

local function get_method_state(target_table, target_name, method_name)
	local target_state = HOOKS.method_targets[target_table]
	if not target_state then
		target_state = {
			name = target_name or tostring(target_table),
			methods = {},
		}
		HOOKS.method_targets[target_table] = target_state
	elseif target_name and not target_state.name then
		target_state.name = target_name
	end

	local method_state = target_state.methods[method_name]
	if not method_state then
		method_state = {
			target_table = target_table,
			target_name = target_state.name or target_name or tostring(target_table),
			method_name = method_name,
			order = {},
			hooks = {},
			installed = false,
		}
		target_state.methods[method_name] = method_state
	end

	return method_state
end

local function build_method_wrapper(method_state)
	return function(self, ...)
		local ctx = {
			self = self,
			args = pack_values(...),
			results = nil,
			skip_original = false,
		}

		for i = #method_state.order, 1, -1 do
			local hook_key = method_state.order[i]
			local hook = method_state.hooks[hook_key]
			if hook and hook.before then
				run_hook(method_state, hook_key, "before", hook.before, ctx)
			end
		end

		if not ctx.skip_original then
			ctx.results = pack_values(method_state.original(self, unpack_packed(ctx.args)))
		elseif not ctx.results then
			ctx.results = { n = 0 }
		end

		for i = 1, #method_state.order do
			local hook_key = method_state.order[i]
			local hook = method_state.hooks[hook_key]
			if hook and hook.after then
				run_hook(method_state, hook_key, "after", hook.after, ctx)
			end
		end

		return unpack_packed(ctx.results)
	end
end

function HOOKS.register_method_hook(target_table, target_name, method_name, hook_key, callbacks)
	if type(target_table) ~= "table" then
		return false
	end

	if type(method_name) ~= "string" or method_name == "" then
		return false
	end

	if type(hook_key) ~= "string" or hook_key == "" then
		return false
	end

	callbacks = callbacks or {}

	local original = target_table[method_name]
	if type(original) ~= "function" then
		report_hook_error({
			target_name = target_name or tostring(target_table),
			method_name = method_name,
		}, hook_key, "register", "Attempted to hook a non-function target.")
		return false
	end

	local method_state = get_method_state(target_table, target_name, method_name)
	if not method_state.installed then
		method_state.original = original
		method_state.wrapper = build_method_wrapper(method_state)
		target_table[method_name] = method_state.wrapper
		method_state.installed = true
	end

	if not method_state.hooks[hook_key] then
		method_state.order[#method_state.order + 1] = hook_key
	end

	method_state.hooks[hook_key] = {
		before = type(callbacks.before) == "function" and callbacks.before or nil,
		after = type(callbacks.after) == "function" and callbacks.after or nil,
	}

	return true
end
