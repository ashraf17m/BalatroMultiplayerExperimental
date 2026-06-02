MP.UTILS = {}

local RUNTIME_TRACE_LOG_FILE = "mp_runtime_trace.log"
local MAX_RUNTIME_TRACE_LOG_BYTES = 2 * 1024 * 1024

local function get_runtime_trace_config()
	if MP.EXPERIMENTAL and MP.EXPERIMENTAL.runtime_trace_logging == true then
		return true
	end

	local smods = MP.PLATFORM and MP.PLATFORM.SMODS or nil
	if smods and type(smods.get_config_value) == "function" then
		return smods.get_config_value("logging", false, MP)
	end

	return MP.config and MP.config.logging
end

local function format_runtime_trace_value(value)
	local value_type = type(value)
	if value_type == "string" or value_type == "number" or value_type == "boolean" then
		return tostring(value)
	end
	if value == nil then
		return "nil"
	end
	return "<" .. value_type .. ">"
end

local function trim_runtime_trace_log_if_needed()
	if not (love and love.filesystem and love.filesystem.getInfo and love.filesystem.remove) then
		return
	end

	local ok, info = pcall(love.filesystem.getInfo, RUNTIME_TRACE_LOG_FILE)
	if ok and info and tonumber(info.size) and tonumber(info.size) > MAX_RUNTIME_TRACE_LOG_BYTES then
		pcall(love.filesystem.remove, RUNTIME_TRACE_LOG_FILE)
	end
end

local function append_runtime_trace_log(message)
	if not (love and love.filesystem and love.filesystem.append) then
		return false
	end

	trim_runtime_trace_log_if_needed()
	local ok = pcall(love.filesystem.append, RUNTIME_TRACE_LOG_FILE, message .. "\n")
	return ok == true
end

function MP.UTILS.is_runtime_trace_enabled()
	return get_runtime_trace_config() == true
end

function MP.UTILS.trace_runtime_event(event, fields)
	if not MP.UTILS.is_runtime_trace_enabled() then
		return false
	end

	local message = "[runtime] " .. tostring(event or "event")
	if type(fields) == "table" then
		local keys = {}
		for key, _ in pairs(fields) do
			table.insert(keys, key)
		end
		table.sort(keys)

		for _, key in ipairs(keys) do
			message = message
				.. " "
				.. tostring(key)
				.. "="
				.. format_runtime_trace_value(fields[key])
		end
	end

	local emitted = append_runtime_trace_log(message)
	if type(sendTraceMessage) == "function" then
		local ok = pcall(sendTraceMessage, message, "MULTIPLAYER")
		emitted = emitted or ok == true
	end
	return emitted
end

MP.UTILS.build_traceback = (MP.BOOTSTRAP_INTERNAL and MP.BOOTSTRAP_INTERNAL.build_traceback) or function(err)
	if debug and debug.traceback then
		return debug.traceback(tostring(err), 2)
	end

	return tostring(err)
end

local unpack_values = table.unpack or unpack

function MP.UTILS.pack_values(...)
	return { n = select("#", ...), ... }
end

function MP.UTILS.unpack_packed(values)
	if not values then
		return
	end

	return unpack_values(values, 1, values.n or #values)
end

function MP.UTILS.has_required_methods(surface, methods)
	if type(surface) ~= "table" then
		return false
	end
	if not methods then
		return true
	end
	if type(methods) == "string" then
		return type(surface[methods]) == "function"
	end
	if type(methods) ~= "table" then
		return false
	end
	for _, method_name in ipairs(methods) do
		if type(surface[method_name]) ~= "function" then
			return false
		end
	end
	return true
end

function MP.UTILS.load_required_domain(domain_key, required_field, file_path, warning_message)
	local domain = MP.DOMAIN and MP.DOMAIN[domain_key] or nil
	if MP.UTILS.has_required_methods(domain, required_field) then
		return domain
	end

	local loaded = MP.PLATFORM.SMODS.load_mod_file(file_path, { required = true })
	if loaded == nil then
		return nil
	end
	if MP.UTILS.has_required_methods(loaded, required_field) then
		return loaded
	end

	domain = MP.DOMAIN and MP.DOMAIN[domain_key] or nil
	if MP.UTILS.has_required_methods(domain, required_field) then
		return domain
	end

	sendWarnMessage(warning_message, "MULTIPLAYER")
	return nil
end

function MP.UTILS.load_required_service(file_path, required_methods, warning_message, resolve)
	local service = type(resolve) == "function" and resolve() or nil
	if MP.UTILS.has_required_methods(service, required_methods) then
		return service
	end

	local loaded = MP.PLATFORM.SMODS.load_mod_file(file_path, { required = true })
	if loaded == nil then
		return nil
	end
	if MP.UTILS.has_required_methods(loaded, required_methods) then
		return loaded
	end

	service = type(resolve) == "function" and resolve() or nil
	if MP.UTILS.has_required_methods(service, required_methods) then
		return service
	end

	sendWarnMessage(warning_message, "MULTIPLAYER")
	return nil
end

local function get_localization_dictionary()
	return G and G.localization and G.localization.misc and G.localization.misc.dictionary or {}
end

local function resolve_team_row_location_label(row_key)
	local dictionary = get_localization_dictionary()
	local row_label = dictionary["k_mp_team_ready_row_" .. tostring(row_key or "")]
	if row_label then
		return row_label
	end

	return tostring(row_key or "") .. " Blind"
end

function MP.UTILS.resolve_location_text(location_str)
	if not location_str then
		return nil, "Unknown"
	end

	local dictionary = get_localization_dictionary()
	local location = tostring(location_str)
	local value = ""

	if location == "loc_disconnected" then
		return location, "Disconnected"
	end

	local split_location, split_value = location:match("^([^-]+)%-(.*)$")
	if split_location then
		location = split_location
		value = split_value or ""
	end

	if (location == "loc_ready_for_team_row" or location == "loc_ready_to_skip_for_team_row")
		and value and value ~= "" then
		local location_text = dictionary[location]
		if location_text == nil and location == "loc_ready_for_team_row" then
			location_text = "Ready for "
		elseif location_text == nil and location == "loc_ready_to_skip_for_team_row" then
			location_text = "wants to skip "
		end

		return location, location_text .. resolve_team_row_location_label(value)
	end

	if location == "loc_playing" and value == "bl_mp_nemesis" then
		value = "PvP"
	else
		local loc_name = localize and localize({ type = "name_text", key = value, set = "Blind" }) or "ERROR"
		if loc_name ~= "ERROR" then
			value = loc_name
		else
			value = (G and G.P_BLINDS and G.P_BLINDS[value] and G.P_BLINDS[value].name) or value
		end
	end

	local location_text = dictionary[location]
	if location_text == nil and location == "loc_ready_to_skip_for_team_row" then
		location_text = "wants to skip "
	end
	if location_text == nil then
		location_text = location or "Unknown"
	end

	return location, location_text .. value
end
