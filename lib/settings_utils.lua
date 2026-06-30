local function parse_env_override_value(value)
	if value == "true" then
		return true
	end

	if value == "false" then
		return false
	end

	return value
end

local ENV_OVERRIDE_FILE = "developer.env"

local function read_experimental_env_overrides()
	local env_path = MP.path .. "/" .. ENV_OVERRIDE_FILE
	if NFS.getInfo(env_path) then
		return NFS.read(env_path), ENV_OVERRIDE_FILE
	end

	return nil, nil
end

function MP.initialize_multiplayer_settings()
	MP.INTEGRATIONS = {
		Preview = MP.PLATFORM.SMODS.get_config_value("integrations.Preview"),
	}

	MP.CALCULATOR_LABELS = {
		text = MP.UTILS.get_calculator_label and MP.UTILS.get_calculator_label("text")
			or MP.PLATFORM.SMODS.get_config_value("calculator.text", MP.PLATFORM.SMODS.get_config_value("preview.text")),
		button = MP.UTILS.get_calculator_label and MP.UTILS.get_calculator_label("button")
			or MP.PLATFORM.SMODS.get_config_value("calculator.button", MP.PLATFORM.SMODS.get_config_value("preview.button")),
	}

	MP.EXPERIMENTAL = {
		show_hidden_collection_content = false,
		show_sandbox_collection = false,
		alt_stakes = false,
		testing_tools = false,
		runtime_trace_logging = false,
		calculator_trace_logging = false,
		suppress_dev_warning = false,
		mem_debug = false,
	}
	MP.ENV = MP.ENV or {}
end

function MP.show_hidden_collection_content()
	return MP.EXPERIMENTAL and MP.EXPERIMENTAL.show_hidden_collection_content == true
end

function MP.should_hide_collection_item()
	return not MP.show_hidden_collection_content()
end

function MP.should_hide_sandbox_collection()
	return not (
		MP.show_hidden_collection_content()
		or (MP.EXPERIMENTAL and MP.EXPERIMENTAL.show_sandbox_collection == true)
	)
end

function MP.apply_experimental_env_overrides()
	local content, source_file = read_experimental_env_overrides()
	if not content then
		return
	end

	for line in content:gmatch("[^\r\n]+") do
		line = line:match("^%s*(.-)%s*$")
		if line ~= "" and not line:match("^#") then
			local key, value = line:match("^([%w_]+)%s*=%s*(.+)$")
			if key then
				local parsed_value = parse_env_override_value(value)
				MP.ENV[key] = parsed_value
				if MP.EXPERIMENTAL[key] ~= nil then
					MP.EXPERIMENTAL[key] = parsed_value
				end
			end
		end
	end

	sendDebugMessage("Loaded " .. tostring(source_file) .. " multiplayer environment overrides", "MULTIPLAYER")
end
