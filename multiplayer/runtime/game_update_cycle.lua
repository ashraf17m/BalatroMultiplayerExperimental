MP.GAME_UPDATE_CYCLE = MP.GAME_UPDATE_CYCLE or {}

local UPDATE_CYCLE = MP.GAME_UPDATE_CYCLE
local build_cycle_traceback =
	(MP.UTILS and MP.UTILS.build_traceback)
	or (MP.BOOTSTRAP_INTERNAL and MP.BOOTSTRAP_INTERNAL.build_traceback)
	or function(err) return tostring(err) end

UPDATE_CYCLE.before_steps = UPDATE_CYCLE.before_steps or {}
UPDATE_CYCLE.after_steps = UPDATE_CYCLE.after_steps or {}
UPDATE_CYCLE.step_sequence = UPDATE_CYCLE.step_sequence or 0
UPDATE_CYCLE.installed = UPDATE_CYCLE.installed or false

local function warn_cycle(message)
	if sendWarnMessage then
		sendWarnMessage(message, "MULTIPLAYER")
	end
end

local function trace_cycle(message)
	if sendTraceMessage then
		sendTraceMessage(message, "MULTIPLAYER")
	end
end

local function sort_steps(steps)
	table.sort(steps, function(a, b)
		if a.order == b.order then
			return a.sequence < b.sequence
		end

		return a.order < b.order
	end)
end

local function register_step(steps, key, callback, order)
	if type(key) ~= "string" or key == "" then
		warn_cycle("Attempted to register unnamed multiplayer game update step.")
		return false
	end

	if type(callback) ~= "function" then
		warn_cycle("Attempted to register non-function multiplayer game update step: " .. key)
		return false
	end

	local step_order = tonumber(order) or 100
	for _, step in ipairs(steps) do
		if step.key == key then
			step.callback = callback
			step.order = step_order
			sort_steps(steps)
			return true
		end
	end

	UPDATE_CYCLE.step_sequence = UPDATE_CYCLE.step_sequence + 1
	steps[#steps + 1] = {
		key = key,
		callback = callback,
		order = step_order,
		sequence = UPDATE_CYCLE.step_sequence,
	}
	sort_steps(steps)
	return true
end

local function run_steps(steps, phase, ctx)
	for _, step in ipairs(steps) do
		local ok, err = xpcall(function()
			step.callback(ctx, ctx and ctx.self or nil)
		end, build_cycle_traceback)

		if not ok then
			warn_cycle("Multiplayer game update step failed (" .. step.key .. ":" .. phase .. ")")
			trace_cycle(tostring(err))
		end
	end
end

function UPDATE_CYCLE.register_before(key, callback, order)
	return register_step(UPDATE_CYCLE.before_steps, key, callback, order)
end

function UPDATE_CYCLE.register_after(key, callback, order)
	return register_step(UPDATE_CYCLE.after_steps, key, callback, order)
end

function UPDATE_CYCLE.run_before(ctx)
	run_steps(UPDATE_CYCLE.before_steps, "before", ctx)
end

function UPDATE_CYCLE.run_after(ctx)
	run_steps(UPDATE_CYCLE.after_steps, "after", ctx)
end

function UPDATE_CYCLE.install()
	if UPDATE_CYCLE.installed then
		return true
	end

	if not (MP.HOOKS and MP.HOOKS.register_method_hook) then
		warn_cycle("Missing hook registry for multiplayer game update cycle.")
		return false
	end

	local installed = MP.HOOKS.register_method_hook(Game, "Game", "update", "mp.runtime.game_update_cycle", {
		before = function(ctx)
			UPDATE_CYCLE.run_before(ctx)
		end,
		after = function(ctx)
			UPDATE_CYCLE.run_after(ctx)
		end,
	})

	UPDATE_CYCLE.installed = installed == true
	return UPDATE_CYCLE.installed
end

return UPDATE_CYCLE
