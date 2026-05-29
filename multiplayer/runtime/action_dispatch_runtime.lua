MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}

local action_dispatch_runtime = {}

local unpack_args = table.unpack or unpack
local build_protocol_route_key = MP.PROTOCOL.build_route_key_from_message
local build_dispatch_traceback =
	(MP.UTILS and MP.UTILS.build_traceback)
	or (MP.BOOTSTRAP_INTERNAL and MP.BOOTSTRAP_INTERNAL.build_traceback)
	or function(err) return tostring(err) end

local function merge_route_group(target_routes, route_group)
	for action_name, handler in pairs(route_group or {}) do
		target_routes[action_name] = handler
	end
end

local function report_dispatch_failure(action_name, err)
	sendWarnMessage("Failed to handle multiplayer action: " .. tostring(action_name), "MULTIPLAYER")
	sendTraceMessage(tostring(err), "MULTIPLAYER")
end

local function invoke_route_handler(route_name, handler, invoke)
	local ok, err = xpcall(invoke, build_dispatch_traceback)
	if not ok then
		report_dispatch_failure(route_name, err)
		return false
	end

	return true
end

function action_dispatch_runtime.route_noargs(handler_name)
	return function()
		return MP.NETWORKING_INTERNAL[handler_name]()
	end
end

function action_dispatch_runtime.route_field(handler_name, field_name)
	return function(action)
		return MP.NETWORKING_INTERNAL[handler_name](action[field_name])
	end
end

function action_dispatch_runtime.route_fields(handler_name, field_names)
	return function(action)
		local fields = field_names or {}
		local args = {}
		for index, field_name in ipairs(fields) do
			args[index] = action[field_name]
		end

		return MP.NETWORKING_INTERNAL[handler_name](unpack_args(args, 1, #fields))
	end
end

function action_dispatch_runtime.route_action(handler_name)
	return function(action)
		return MP.NETWORKING_INTERNAL[handler_name](action)
	end
end

function action_dispatch_runtime.rebuild_feature_action_routes()
	local feature_routes = {}

	merge_route_group(feature_routes, MP.NETWORKING_INTERNAL.LOCAL_FEATURE_ACTION_ROUTES)
	merge_route_group(feature_routes, MP.NETWORKING_INTERNAL.UI_RUNTIME_FEATURE_ACTION_ROUTES)
	merge_route_group(feature_routes, MP.NETWORKING_INTERNAL.END_GAME_FEATURE_ACTION_ROUTES)

	MP.NETWORKING_INTERNAL.FEATURE_ACTION_ROUTES = feature_routes
	return feature_routes
end

function action_dispatch_runtime.rebuild_protocol_v2_routes()
	local protocol_routes = {}

	merge_route_group(protocol_routes, MP.NETWORKING_INTERNAL.PROTOCOL_V2_LOBBY_ROUTES)
	merge_route_group(protocol_routes, MP.NETWORKING_INTERNAL.PROTOCOL_V2_MATCH_ROUTES)
	merge_route_group(protocol_routes, MP.NETWORKING_INTERNAL.PROTOCOL_V2_FEATURE_ROUTES)

	MP.NETWORKING_INTERNAL.PROTOCOL_V2_ROUTES = protocol_routes
	return protocol_routes
end

function action_dispatch_runtime.rebuild_action_routes()
	if action_dispatch_runtime.rebuild_feature_action_routes then
		action_dispatch_runtime.rebuild_feature_action_routes()
	end
	if action_dispatch_runtime.rebuild_protocol_v2_routes then
		action_dispatch_runtime.rebuild_protocol_v2_routes()
	end

	local action_routes = {}
	merge_route_group(action_routes, MP.NETWORKING_INTERNAL.LOCAL_ACTION_ROUTES)

	MP.NETWORKING_INTERNAL.ACTION_ROUTES = action_routes
	return action_routes
end

function action_dispatch_runtime.dispatch_parsed_action(parsed_action)
	if
		type(parsed_action) == "table"
		and tonumber(parsed_action.version) == (MP.PROTOCOL and MP.PROTOCOL.VERSION or 2)
		and type(parsed_action.family) == "string"
	then
		local protocol_routes = MP.NETWORKING_INTERNAL.PROTOCOL_V2_ROUTES
		if not protocol_routes then
			action_dispatch_runtime.rebuild_action_routes()
			protocol_routes = MP.NETWORKING_INTERNAL.PROTOCOL_V2_ROUTES
		end
		if type(protocol_routes) ~= "table" then
			sendWarnMessage("No multiplayer protocol_v2 routes are available.", "MULTIPLAYER")
			return false
		end

		local route_key = build_protocol_route_key(parsed_action)
		local handler = protocol_routes[route_key]
		if handler then
			return invoke_route_handler(route_key, handler, function()
				handler(parsed_action.payload or {}, parsed_action)
			end)
		end

		sendWarnMessage("Unhandled multiplayer protocol_v2 route: " .. tostring(route_key), "MULTIPLAYER")
		return false
	end

	local action_routes = MP.NETWORKING_INTERNAL.ACTION_ROUTES
	if not action_routes then
		action_routes = action_dispatch_runtime.rebuild_action_routes()
	end
	if type(action_routes) ~= "table" then
		sendWarnMessage("No multiplayer action routes are available.", "MULTIPLAYER")
		return false
	end

	local action_name = parsed_action and parsed_action.action
	local handler = action_routes[action_name]
	if handler then
		return invoke_route_handler(action_name, handler, function()
			handler(parsed_action)
		end)
	end

	sendWarnMessage("Unhandled multiplayer action: " .. tostring(action_name), "MULTIPLAYER")
	return false
end

MP.NETWORKING_INTERNAL.route_noargs = action_dispatch_runtime.route_noargs
MP.NETWORKING_INTERNAL.route_field = action_dispatch_runtime.route_field
MP.NETWORKING_INTERNAL.route_fields = action_dispatch_runtime.route_fields
MP.NETWORKING_INTERNAL.route_action = action_dispatch_runtime.route_action
MP.NETWORKING_INTERNAL.rebuild_feature_action_routes = action_dispatch_runtime.rebuild_feature_action_routes
MP.NETWORKING_INTERNAL.rebuild_protocol_v2_routes = action_dispatch_runtime.rebuild_protocol_v2_routes
MP.NETWORKING_INTERNAL.rebuild_action_routes = action_dispatch_runtime.rebuild_action_routes
MP.NETWORKING_INTERNAL.dispatch_parsed_action = action_dispatch_runtime.dispatch_parsed_action
