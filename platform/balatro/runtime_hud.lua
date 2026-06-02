MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.BALATRO = MP.PLATFORM.BALATRO or {}

local BALATRO = MP.PLATFORM.BALATRO
local get_root = BALATRO.get_root

function BALATRO.get_hud_blind()
	local root = get_root()
	return root and root.HUD_blind or nil
end

function BALATRO.get_hud_blind_element_by_id(id)
	local hud_blind = BALATRO.get_hud_blind()
	return hud_blind and hud_blind.get_UIE_by_ID and hud_blind:get_UIE_by_ID(id) or nil
end

function BALATRO.set_hud_blind_visible(visible)
	local hud_blind = BALATRO.get_hud_blind()
	if not (hud_blind and hud_blind.states) then
		return false
	end

	hud_blind.states.visible = not not visible
	return true
end

function BALATRO.recalculate_hud_blind()
	return BALATRO.recalculate_ui(BALATRO.get_hud_blind())
end

function BALATRO.get_hud()
	local root = get_root()
	return root and root.HUD or nil
end

function BALATRO.get_hud_element_by_id(id)
	local hud = BALATRO.get_hud()
	return hud and hud.get_UIE_by_ID and hud:get_UIE_by_ID(id) or nil
end

function BALATRO.recalculate_ui(node)
	if node and node.UIBox and node.UIBox.recalculate then
		node.UIBox:recalculate()
		return true
	end
	if node and node.recalculate then
		node:recalculate()
		return true
	end

	return false
end

function BALATRO.get_room_attach()
	local root = get_root()
	return root and root.ROOM_ATTACH or nil
end

function BALATRO.get_main_menu_ui()
	local root = get_root()
	return root and root.MAIN_MENU_UI or nil
end

function BALATRO.set_main_menu_ui(ui)
	local root = get_root()
	if not root then
		return false
	end

	root.MAIN_MENU_UI = ui
	return true
end

function BALATRO.clear_main_menu_ui()
	local main_menu_ui = BALATRO.get_main_menu_ui()
	if main_menu_ui and main_menu_ui.remove then
		main_menu_ui:remove()
	end

	return BALATRO.set_main_menu_ui(nil)
end

function BALATRO.get_ui_definition()
	local root = get_root()
	return root and root.UIDEF or nil
end

function BALATRO.create_connection_status_ui()
	local ui_definition = BALATRO.get_ui_definition()
	return ui_definition and ui_definition.get_connection_status_ui and ui_definition.get_connection_status_ui() or nil
end

function BALATRO.align_to_major(node)
	if node and node.align_to_major then
		node:align_to_major()
		return true
	end

	return false
end

function BALATRO.snap_controller_to(node)
	local root = get_root()
	if not (root and root.CONTROLLER and root.CONTROLLER.snap_to and node) then
		return false
	end

	root.CONTROLLER:snap_to({ node = node })
	return true
end

function BALATRO.snap_controller_to_ui_element(container, id)
	if not (container and container.get_UIE_by_ID and id) then
		return false
	end

	return BALATRO.snap_controller_to(container:get_UIE_by_ID(id))
end

function BALATRO.set_paused(value)
	local settings = BALATRO.get_settings and BALATRO.get_settings() or nil
	if not settings then
		return false
	end

	settings.paused = not not value
	return true
end

function BALATRO.set_no_saving(value)
	local root = get_root()
	if not root then
		return false
	end

	root.F_NO_SAVING = not not value
	return true
end

function BALATRO.get_hud_connection_status()
	local root = get_root()
	return root and root.HUD_connection_status or nil
end

function BALATRO.set_hud_connection_status(node)
	local root = get_root()
	if not root then
		return false
	end

	root.HUD_connection_status = node
	return true
end

function BALATRO.clear_hud_connection_status()
	local hud_connection_status = BALATRO.get_hud_connection_status()
	if hud_connection_status and hud_connection_status.remove then
		hud_connection_status:remove()
	end

	return BALATRO.set_hud_connection_status(nil)
end

function BALATRO.get_animation_atlas(key)
	local root = get_root()
	return root and root.ANIMATION_ATLAS and root.ANIMATION_ATLAS[key] or nil
end

function BALATRO.get_language_font(key)
	local root = get_root()
	return root and root.LANGUAGES and root.LANGUAGES[key] and root.LANGUAGES[key].font or nil
end

function BALATRO.get_controller_locks()
	local root = get_root()
	return root and root.CONTROLLER and root.CONTROLLER.locks or nil
end

function BALATRO.set_controller_lock(key, value)
	local locks = BALATRO.get_controller_locks()
	if not locks then
		return false
	end

	locks[key] = value
	return true
end

function BALATRO.clear_controller_lock(key)
	local locks = BALATRO.get_controller_locks()
	if not locks then
		return false
	end

	locks[key] = nil
	return true
end

function BALATRO.is_controller_mouse_dragging()
	local root = get_root()
	local controller = root and root.CONTROLLER or nil
	return not not (controller and controller.dragging and controller.dragging.target and not controller.using_touch)
end

function BALATRO.get_wall_time()
	if love and love.timer and love.timer.getTime then
		return love.timer.getTime()
	end

	return 0
end

return BALATRO
