MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.BALATRO = MP.PLATFORM.BALATRO or {}

local BALATRO = MP.PLATFORM.BALATRO
local get_root = BALATRO.get_root

function BALATRO.ensure_ui_functions()
	local root = get_root()
	if not root then
		return nil
	end

	root.FUNCS = root.FUNCS or {}
	return root.FUNCS
end

function BALATRO.set_ui_function(name, fn)
	local funcs = BALATRO.ensure_ui_functions()
	if not funcs or type(name) ~= "string" or name == "" then
		return nil
	end

	funcs[name] = fn
	return fn
end

function BALATRO.get_ui_function(name)
	local funcs = BALATRO.ensure_ui_functions()
	if not funcs or type(name) ~= "string" or name == "" then
		return nil
	end

	return funcs[name]
end

function BALATRO.call_ui_function(name, ...)
	local funcs = BALATRO.ensure_ui_functions()
	local fn = funcs and funcs[name] or nil
	if type(fn) ~= "function" then
		return nil
	end

	return fn(...)
end

function BALATRO.create_event(config)
	return Event(config)
end

function BALATRO.add_event(event, queue, front)
	local root = get_root()
	if not (root and root.E_MANAGER and event) then
		return false
	end

	root.E_MANAGER:add_event(event, queue, front)
	return true
end

function BALATRO.queue_event(config, queue, front)
	return BALATRO.add_event(BALATRO.create_event(config), queue, front)
end

function BALATRO.get_overlay_menu()
	local root = get_root()
	return root and root.OVERLAY_MENU or nil
end

function BALATRO.open_overlay_menu(definition_or_payload, config)
	if definition_or_payload == nil then
		return nil
	end

	local payload = definition_or_payload
	if type(definition_or_payload) ~= "table" or definition_or_payload.definition == nil then
		payload = {
			definition = definition_or_payload,
			config = config,
		}
	end

	return BALATRO.call_ui_function("overlay_menu", payload)
end

function BALATRO.set_overlay_menu(value)
	local root = get_root()
	if not root then
		return false
	end

	root.OVERLAY_MENU = value
	return true
end

function BALATRO.get_overlay_element_by_id(id)
	local overlay = BALATRO.get_overlay_menu()
	return overlay and overlay.get_UIE_by_ID and overlay:get_UIE_by_ID(id) or nil
end

function BALATRO.get_overlay_property(name)
	local overlay = BALATRO.get_overlay_menu()
	return overlay and overlay[name] or nil
end

function BALATRO.set_overlay_property(name, value)
	local overlay = BALATRO.get_overlay_menu()
	if not overlay or type(name) ~= "string" or name == "" then
		return false
	end

	overlay[name] = value
	return true
end

function BALATRO.exit_overlay_menu()
	return BALATRO.call_ui_function("exit_overlay_menu")
end

function BALATRO.go_to_menu()
	return BALATRO.call_ui_function("go_to_menu")
end

function BALATRO.select_blind(context)
	return BALATRO.call_ui_function("select_blind", context)
end

function BALATRO.start_lobby_run(options)
	return BALATRO.call_ui_function("lobby_start_run", nil, options)
end

function BALATRO.start_run(options)
	return BALATRO.call_ui_function("start_run", nil, options)
end

function BALATRO.select_text_input(node)
	return BALATRO.call_ui_function("select_text_input", node)
end

function BALATRO.select_overlay_text_input_by_id(id)
	local node = BALATRO.get_overlay_element_by_id(id)
	if not node then
		return nil
	end

	BALATRO.select_text_input(node)
	return node
end

return BALATRO
