-- Shared calculator HUD insertion.

MP = MP or {}
MP.CALCULATOR = MP.CALCULATOR or {}

local CORE = MP.CALCULATOR

local function get_hud_column_nodes(contents)
	return contents
		and contents.nodes
		and contents.nodes[1]
		and contents.nodes[1].nodes
		and contents.nodes[1].nodes[1]
		and contents.nodes[1].nodes[1].nodes
end

local function insert_after_hand_text_area(contents, node)
	local hud_nodes = get_hud_column_nodes(contents)
	if not hud_nodes then return false end

	for index, child in ipairs(hud_nodes) do
		if child.config and child.config.id == "hand_text_area" then
			table.insert(hud_nodes, index + 1, node)
			return true
		end
	end

	table.insert(hud_nodes, node)
	return true
end

local function should_show_calculator()
	return type(CORE.enabled) == "function"
		and CORE.enabled()
		and type(CORE.get_hud_node) == "function"
end

if not CORE.hud_interface_installed then
	CORE.hud_interface_installed = true
	CORE.hud_interface_ref = create_UIBox_HUD
	function create_UIBox_HUD()
		local contents = CORE.hud_interface_ref()
		if not should_show_calculator() then return contents end

		insert_after_hand_text_area(contents, CORE.get_hud_node())

		return contents
	end
end
