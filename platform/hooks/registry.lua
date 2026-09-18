MP.HOOKS = MP.HOOKS or {}

local HOOKS = MP.HOOKS

HOOKS.method_targets = HOOKS.method_targets or {}

local pack_values = MP.BOOTSTRAP_INTERNAL.pack_values
local unpack_packed = MP.BOOTSTRAP_INTERNAL.unpack_packed

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
	local ok, err = pcall(callback, ctx, ctx and ctx.self or nil)

	if not ok then
		report_hook_error(method_state, hook_key, phase, build_hook_traceback(err))
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

local reusable_ctx = { self = nil, args = nil, results = nil, skip_original = false, in_use = false }

local function update_method_state_flags(method_state)
	local has_before = false
	local has_after = false
	for _, hook_key in ipairs(method_state.order) do
		local hook = method_state.hooks[hook_key]
		if hook then
			if hook.before then has_before = true end
			if hook.after then has_after = true end
		end
	end
	method_state.has_before = has_before
	method_state.has_after = has_after
end

local function build_method_wrapper(method_state)
	return function(self, ...)
		if not method_state.has_before and not method_state.has_after then
			return method_state.original(self, ...)
		end

		local ctx
		local used_reusable = false
		if not reusable_ctx.in_use then
			reusable_ctx.in_use = true
			reusable_ctx.self = self
			reusable_ctx.args = pack_values(...)
			reusable_ctx.results = nil
			reusable_ctx.skip_original = false
			ctx = reusable_ctx
			used_reusable = true
		else
			ctx = {
				self = self,
				args = pack_values(...),
				results = nil,
				skip_original = false,
			}
		end

		if method_state.has_before then
			for i = #method_state.order, 1, -1 do
				local hook_key = method_state.order[i]
				local hook = method_state.hooks[hook_key]
				if hook and hook.before then
					run_hook(method_state, hook_key, "before", hook.before, ctx)
				end
			end
		end

		if not ctx.skip_original then
			ctx.results = pack_values(method_state.original(self, unpack_packed(ctx.args)))
		elseif not ctx.results then
			ctx.results = { n = 0 }
		end

		if method_state.has_after then
			for i = 1, #method_state.order do
				local hook_key = method_state.order[i]
				local hook = method_state.hooks[hook_key]
				if hook and hook.after then
					run_hook(method_state, hook_key, "after", hook.after, ctx)
				end
			end
		end

		local final_results = ctx.results
		if used_reusable then
			reusable_ctx.self = nil
			reusable_ctx.args = nil
			reusable_ctx.results = nil
			reusable_ctx.in_use = false
		end

		return unpack_packed(final_results)
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
	update_method_state_flags(method_state)

	return true
end

function HOOKS.unregister_method_hook(target_table, target_name_or_method, method_or_key, hook_key)
	if type(target_table) ~= "table" then
		return false
	end

	local method_name
	if hook_key ~= nil then
		method_name = method_or_key
	else
		method_name = target_name_or_method
		hook_key = method_or_key
	end

	if type(method_name) ~= "string" or type(hook_key) ~= "string" then
		return false
	end

	local target_state = HOOKS.method_targets[target_table]
	if not target_state then
		return false
	end

	local method_state = target_state.methods[method_name]
	if not method_state or not method_state.hooks[hook_key] then
		return false
	end

	method_state.hooks[hook_key] = nil
	for i = 1, #method_state.order do
		if method_state.order[i] == hook_key then
			table.remove(method_state.order, i)
			break
		end
	end
	update_method_state_flags(method_state)

	if #method_state.order == 0 and method_state.installed then
		target_table[method_name] = method_state.original
		method_state.installed = false
	end

	return true
end

