MP.UI = MP.UI or {}
MP.UI.MAIN_MENU_PLAY = MP.UI.MAIN_MENU_PLAY or {}

local view_model = MP.UI.MAIN_MENU_PLAY
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY or {}
local INLINE_JOIN_LOBBY_INPUT_ID = "mp_main_join_lobby_input"
local JOIN_LOBBY_BUTTON_WIDTH = 2.95
local MAIN_MENU_BUTTON_HEIGHT = 1.15
local JOIN_LOBBY_BUTTON_SCALE = 0.5
local PASTE_ICON_ATLAS_KEY = "mp_paste_icon"
local PASTE_ICON_BUTTON_WIDTH = 1.35
local PASTE_ICON_SIZE = 0.9
local LOBBY_BROWSER_ROWS_ID = "mp_lobby_browser_rows"
local LOBBY_BROWSER_NOTICE_ID = "mp_lobby_browser_notice"
local JOIN_REQUEST_NOTIFICATION_ID = "mp_join_request_notification"
local JOIN_REQUEST_CANCEL_BUTTON_WIDTH = 4.42
local LOBBY_TYPE_COLOUR = { 0.08, 0.58, 0.70, 1 }
local LOBBY_ROW_TRAY_COLOUR = { 0.13, 0.24, 0.25, 1 }
local LOBBY_ROW_TEXT_SCALE = 0.45
local LOBBY_BROWSER_ROWS_PER_PAGE = 6
local LOBBY_BROWSER_HIDDEN_NAME = "*******"

view_model.inline_join_lobby_input_active = view_model.inline_join_lobby_input_active or false
view_model.browse_lobbies_page = view_model.browse_lobbies_page or 1
view_model.browse_lobbies_notice = view_model.browse_lobbies_notice or { display = "", expires_at = 0 }
view_model.hide_browse_lobby_names = view_model.hide_browse_lobby_names or false
view_model.browse_lobby_name_toggle = view_model.browse_lobby_name_toggle or { display = "Hide Names" }

local function append_node(contents, node)
	if node then
		contents[#contents + 1] = node
	end
end

local function get_real_time()
	if G and G.TIMERS and G.TIMERS.REAL then
		return G.TIMERS.REAL
	end
	if love and love.timer and love.timer.getTime then
		return love.timer.getTime()
	end
	return os.clock()
end

local function localize_or_default(key, fallback)
	if type(localize) ~= "function" then
		return fallback or tostring(key or "")
	end
	local text = localize(key)
	if text == nil or text == "ERROR" then
		return fallback or tostring(key or "")
	end
	return text
end

local function update_browse_lobby_name_toggle_label()
	view_model.browse_lobby_name_toggle.display = view_model.hide_browse_lobby_names and "Show Names" or "Hide Names"
end

local function try_localize(key)
	if type(localize) ~= "function" then
		return nil
	end
	local text = localize(key)
	if text == nil or text == "ERROR" then
		return nil
	end
	return text
end

local function create_text_node(text, scale, colour)
	return {
		n = G.UIT.T,
		config = {
			text = tostring(text or ""),
			scale = scale or 0.4,
			colour = colour or G.C.UI.TEXT_LIGHT,
			shadow = true,
		},
	}
end

local function create_play_button(label_key, colour, button, minh)
	return UIBox_button({
		label = { localize(label_key) },
		colour = colour,
		button = button,
		minw = 5,
		minh = minh,
	})
end

local function create_overlay_button(id, label, colour, button, minw, scale, extra_config)
	local config = {
		id = id,
		label = { label },
		colour = colour,
		button = button,
		minw = minw or 3,
		minh = 0.65,
		scale = scale or 0.42,
		hover = true,
		shadow = true,
	}

	for key, value in pairs(extra_config or {}) do
		config[key] = value
	end

	return UIBox_button(config)
end

local function create_main_menu_button(spec)
	return UIBox_button({
		id = spec.id,
		label = { localize(spec.label_key) },
		colour = spec.colour,
		button = spec.button,
		minw = spec.minw or 2.9,
		minh = spec.minh or 1.15,
		scale = spec.scale or 0.5,
		col = true,
	})
end

local function create_dynamic_button(spec)
	local config = {
		id = spec.id,
		align = "cm",
		padding = 0.05,
		r = 0.1,
		hover = true,
		shadow = true,
		colour = spec.colour,
		button = spec.button,
		minw = spec.minw or 3,
		minh = spec.minh or MAIN_MENU_BUTTON_HEIGHT,
	}

	for key, value in pairs(spec.extra_config or {}) do
		config[key] = value
	end

	return {
		n = G.UIT.C,
		config = config,
		nodes = {
			{
				n = G.UIT.O,
				config = {
					object = DynaText({
						string = {{ ref_table = spec.ref_table, ref_value = spec.ref_value or "display" }},
						colours = { spec.text_colour or G.C.UI.TEXT_LIGHT },
						shadow = true,
						silent = true,
						scale = spec.scale or 0.48,
						pop_in = 0,
					}),
				},
			},
		},
	}
end

local function create_paste_icon_sprite_node()
	local atlas = SMODS and SMODS.get_atlas and SMODS.get_atlas(PASTE_ICON_ATLAS_KEY)
	if atlas then
		if atlas.image and not atlas.mp_nearest_filter_applied then
			if atlas.image.setFilter then
				atlas.image:setFilter("nearest", "nearest")
			end
			if atlas.image.setMipmapFilter then
				pcall(function()
					atlas.image:setMipmapFilter("nearest", 0)
				end)
			end
			atlas.mp_nearest_filter_applied = true
		end

		local icon = Sprite(0, 0, PASTE_ICON_SIZE, PASTE_ICON_SIZE, atlas, { x = 0, y = 0 })
		icon.states.drag.can = false
		return { n = G.UIT.O, config = { w = PASTE_ICON_SIZE, h = PASTE_ICON_SIZE, object = icon } }
	end

	return create_text_node("V", 0.52, G.C.UI.TEXT_LIGHT)
end

local function create_paste_icon_button()
	return {
		n = G.UIT.C,
		config = { align = "cm" },
		nodes = {
			{
				n = G.UIT.C,
				config = {
					id = "mp_main_join_clipboard",
					align = "cm",
					padding = 0,
					r = 0.1,
					hover = true,
					colour = G.C.PURPLE,
					button = "join_from_clipboard",
					minw = PASTE_ICON_BUTTON_WIDTH,
					minh = MAIN_MENU_BUTTON_HEIGHT,
					shadow = true,
					on_demand_tooltip = {
						text = { try_localize("k_paste") or "Paste Code" },
					},
				},
				nodes = {
					create_paste_icon_sprite_node(),
				},
			},
		},
	}
end

local function get_pending_join_request()
	return lobby_domain.get_pending_join_request and lobby_domain.get_pending_join_request() or nil
end

local function get_join_request_remaining_seconds(request)
	if lobby_domain.get_join_request_remaining_seconds then
		return lobby_domain.get_join_request_remaining_seconds(request)
	end
	return 0
end

local function update_join_request_text(request)
	if type(request) ~= "table" then
		return 0
	end

	local remaining = get_join_request_remaining_seconds(request)
	request.remaining_display = tostring(remaining) .. "s"
	request.display = localize_or_default("b_cancel", "Cancel") .. " " .. request.remaining_display
	request.notice_display = request.remaining_display
	return remaining
end

local function create_pending_join_request_button(minw, scale)
	local request = get_pending_join_request()
	if not request then
		return nil
	end

	update_join_request_text(request)
	return create_dynamic_button({
		id = "mp_main_pending_join_request",
		ref_table = request,
		colour = G.C.ORANGE,
		button = "cancel_lobby_join_request",
		minw = minw or JOIN_REQUEST_CANCEL_BUTTON_WIDTH,
		minh = MAIN_MENU_BUTTON_HEIGHT,
		scale = scale or 0.48,
		extra_config = {
			request_id = request.requestId,
			ref_table = { request_id = request.requestId },
		},
	})
end

local function create_inline_join_lobby_input()
	if lobby_domain.ensure_setup_state then
		lobby_domain.ensure_setup_state()
	end
	MP.LOBBY = MP.LOBBY or {}
	MP.LOBBY.setup = MP.LOBBY.setup or {}
	MP.LOBBY.setup.temp_code = MP.LOBBY.setup.temp_code or ""

	local input = create_text_input({
		id = INLINE_JOIN_LOBBY_INPUT_ID,
		w = JOIN_LOBBY_BUTTON_WIDTH,
		h = MAIN_MENU_BUTTON_HEIGHT,
		max_length = 5,
		all_caps = true,
		prompt_text = localize_or_default("k_lobby_code", "Code"),
		ref_table = MP.LOBBY.setup,
		ref_value = "temp_code",
		extended_corpus = false,
		keyboard_offset = 4,
		text_scale = JOIN_LOBBY_BUTTON_SCALE,
		colour = G.C.RED,
		hooked_colour = darken(copy_table(G.C.RED), 0.3),
		callback = function()
			BALATRO.call_ui_function("submit_inline_join_lobby")
		end,
	})

	input.config.minw = JOIN_LOBBY_BUTTON_WIDTH
	input.config.maxw = JOIN_LOBBY_BUTTON_WIDTH
	input.config.minh = MAIN_MENU_BUTTON_HEIGHT
	input.config.maxh = MAIN_MENU_BUTTON_HEIGHT

	local input_body = input.nodes and input.nodes[1]
	if input_body and input_body.config then
		input_body.config.minw = JOIN_LOBBY_BUTTON_WIDTH
		input_body.config.maxw = JOIN_LOBBY_BUTTON_WIDTH
		input_body.config.minh = MAIN_MENU_BUTTON_HEIGHT
		input_body.config.maxh = MAIN_MENU_BUTTON_HEIGHT
	end

	return input
end

function view_model.get_inline_join_lobby_input_id()
	return INLINE_JOIN_LOBBY_INPUT_ID
end

function view_model.set_inline_join_lobby_input_active(active)
	view_model.inline_join_lobby_input_active = not not active
end

function view_model.is_inline_join_lobby_input_active()
	return not not view_model.inline_join_lobby_input_active
end

function view_model.cancel_inline_join_lobby_input()
	if not view_model.inline_join_lobby_input_active then
		return false
	end

	view_model.inline_join_lobby_input_active = false
	if lobby_domain.set_setup_temp_code then
		lobby_domain.set_setup_temp_code("")
	elseif MP.LOBBY and MP.LOBBY.setup then
		MP.LOBBY.setup.temp_code = ""
	end

	return true
end

local function append_play_button_if(contents, condition, label_key, colour, button, minh)
	if condition then
		append_node(contents, create_play_button(label_key, colour, button, minh))
	end
end

local function append_multiplayer_lobby_create_buttons(contents)
	if not (MP.LOBBY and MP.LOBBY.client and MP.LOBBY.client.connected) then
		return
	end

	append_node(contents, create_play_button("b_create_party", G.C.GREEN, "create_group_lobby"))
end

local function append_resume_match_button(contents)
	if not (MP.RESUME and MP.RESUME.has_saved_resume and MP.RESUME.has_saved_resume()) then
		return
	end

	append_node(contents, create_play_button("b_resume_match", G.C.GREEN, "resume_match"))
end

function view_model.build_play_options_contents()
	local contents = {}

	append_resume_match_button(contents)
	append_multiplayer_lobby_create_buttons(contents)

	local is_connected = MP.LOBBY.client.connected
	append_play_button_if(contents, is_connected, "b_browse_lobbies", G.C.BLUE, "browse_lobbies", 0.7)
	append_play_button_if(contents, is_connected, "b_join_lobby", G.C.RED, "join_lobby", 0.7)
	append_play_button_if(contents, not is_connected, "b_reconnect", G.C.RED, "reconnect")

	return contents
end

function view_model.build_main_menu_button_nodes()
	local buttons = {}

	if MP.RESUME and MP.RESUME.has_saved_resume and MP.RESUME.has_saved_resume() then
		append_node(buttons, create_main_menu_button({
			id = "mp_main_resume_match",
			label_key = "b_resume_match",
			colour = G.C.GREEN,
			button = "resume_match",
			minw = 3.65,
			scale = 0.46,
		}))
	end

	local is_connected = MP.LOBBY and MP.LOBBY.client and MP.LOBBY.client.connected
	if is_connected then
		local pending_join_request = get_pending_join_request()
		append_node(buttons, create_main_menu_button({
			id = "mp_main_create_party",
			label_key = "b_create_lobby",
			colour = G.C.GREEN,
			button = "create_group_lobby",
			minw = 3.3,
			scale = 0.5,
		}))
		append_node(buttons, create_main_menu_button({
			id = "mp_main_browse_lobbies",
			label_key = "b_browse_lobbies",
			colour = G.C.BLUE,
			button = "browse_lobbies",
			minw = 4.15,
			scale = 0.48,
		}))
		if pending_join_request then
			append_node(buttons, create_pending_join_request_button())
		elseif view_model.inline_join_lobby_input_active then
			append_node(buttons, create_inline_join_lobby_input())
		else
			append_node(buttons, create_main_menu_button({
				id = "mp_main_join_lobby",
				label_key = "b_enter_code",
				colour = G.C.RED,
				button = "join_lobby",
				minw = JOIN_LOBBY_BUTTON_WIDTH,
				minh = MAIN_MENU_BUTTON_HEIGHT,
				scale = JOIN_LOBBY_BUTTON_SCALE,
			}))
		end
		if not pending_join_request then
			append_node(buttons, create_paste_icon_button())
		end
	else
		append_node(buttons, create_main_menu_button({
			id = "mp_main_reconnect",
			label_key = "b_reconnect",
			colour = G.C.RED,
			button = "reconnect",
			minw = 3.15,
			scale = 0.52,
		}))
	end

	return buttons
end

function view_model.create_main_menu_button_row()
	local buttons = view_model.build_main_menu_button_nodes()
	if not buttons or #buttons == 0 then
		return nil
	end

	return {
		n = G.UIT.R,
		config = {
			align = "cm",
			padding = 0.12,
			colour = G.C.CLEAR,
		},
		nodes = buttons,
	}
end

function view_model.create_play_options_overlay()
	return create_UIBox_generic_options({
		contents = view_model.build_play_options_contents(),
	})
end

local function shorten_text(text, max_length)
	text = tostring(text or "")
	max_length = max_length or 16
	if #text <= max_length then
		return text
	end
	return text:sub(1, math.max(1, max_length - 3)) .. "..."
end

local function title_case_key(value)
	local label = tostring(value or "?"):gsub("_", " ")
	return (label:gsub("^%l", string.upper))
end

local function display_ruleset(ruleset_key)
	local key = tostring(ruleset_key or "")
	if key == "" then
		return "?"
	end

	local ruleset = MP.Rulesets and MP.Rulesets[key] or nil
	if ruleset and ruleset.name then
		return tostring(ruleset.name)
	end

	local suffix = key:gsub("^ruleset_mp_", "")
	return try_localize("k_" .. suffix) or title_case_key(suffix)
end

local function display_gamemode(game_mode)
	local key = tostring(game_mode or "")
	if key == "" then
		return "?"
	end

	local full_key = key:find("^gamemode_mp_") and key or ("gamemode_mp_" .. key)
	local gamemode = MP.Gamemodes and MP.Gamemodes[full_key] or nil
	if gamemode and gamemode.name then
		return tostring(gamemode.name)
	end

	if key == "attrition" then
		return localize_or_default("k_attrition_name", "Attrition")
	elseif key == "coop" then
		return localize_or_default("k_cooperative", "Co-op")
	end
	return title_case_key(key:gsub("^gamemode_mp_", ""))
end

local function display_lobby_type(lobby_type)
	local key = tostring(lobby_type or "")
	if key == "1v1" then
		return "1v1"
	elseif key == "ffa" then
		return "FFA"
	elseif key == "teams" then
		return "Teams"
	elseif key == "duels" then
		return "Duels"
	elseif key == "coop" then
		return "Co-op"
	end
	return title_case_key(key)
end

local function get_lobby_browser_owner_display(lobby)
	if view_model.hide_browse_lobby_names then
		return LOBBY_BROWSER_HIDDEN_NAME
	end

	return shorten_text(lobby.ownerUsername or lobby.owner_username or "Guest", 12)
end

local function create_lobby_row_spacer(width)
	return { n = G.UIT.B, config = { w = width or 0.08, h = 0.01 } }
end

local function create_lobby_row_pill(nodes, width, align, colour)
	return {
		n = G.UIT.C,
		config = {
			align = align or "cm",
			minw = width,
			maxw = width,
			minh = 0.58,
			padding = 0.03,
			r = 0.08,
			colour = colour,
			line_emboss = 0.35,
		},
		nodes = nodes,
	}
end

local function create_lobby_row_tray(nodes)
	return {
		n = G.UIT.R,
		config = {
			align = "cm",
			minw = 12.3,
			maxw = 12.3,
			minh = 0.76,
			padding = 0.04,
			r = 0.1,
			colour = LOBBY_ROW_TRAY_COLOUR,
			line_emboss = 0.25,
		},
		nodes = nodes,
	}
end

local function create_lobby_row_text_pill(text, width, align, scale, colour)
	return create_lobby_row_pill({
		create_text_node(text, scale or LOBBY_ROW_TEXT_SCALE, G.C.UI.TEXT_LIGHT),
	}, width, align, colour)
end

local function create_lobby_row_dynamic_pill(ref_table, ref_value, width, align, scale, colour)
	return create_lobby_row_pill({
		{
			n = G.UIT.O,
			config = {
				object = DynaText({
					string = {{ ref_table = ref_table, ref_value = ref_value or "display" }},
					colours = { G.C.UI.TEXT_LIGHT },
					shadow = true,
					silent = true,
					scale = scale or LOBBY_ROW_TEXT_SCALE,
					pop_in = 0,
				}),
			},
		},
	}, width, align, colour)
end

local function lobby_browser_row_colour(access_mode)
	if access_mode == "ask_first" then
		return G.C.BLUE
	elseif access_mode == "private" then
		return G.C.PURPLE
	end

	return G.C.GREEN
end

local function display_lobby_access(access_mode)
	if access_mode == "ask_first" then
		return "Ask First"
	elseif access_mode == "private" then
		return "Private"
	end

	return "Public"
end

local function build_lobby_browser_row(lobby, index)
	local access_mode = tostring(lobby.accessMode or lobby.access_mode or "public")
	local access_colour = lobby_browser_row_colour(access_mode)
	local access_label = display_lobby_access(access_mode)
	local code = tostring(lobby.code or "")
	local pending_request = get_pending_join_request()
	local pending_code = pending_request and tostring(pending_request.code or ""):upper() or nil
	local is_pending_lobby = pending_code and pending_code == code:upper()
	local owner = get_lobby_browser_owner_display(lobby)
	local player_count = tostring(lobby.playerCount or lobby.player_count or "?")
	local max_players = tostring(lobby.maxPlayers or lobby.max_players or "?")
	local lobby_type = shorten_text(display_lobby_type(lobby.lobbyType or lobby.lobby_type), 8)
	local ruleset = shorten_text(display_ruleset(lobby.ruleset), 16)
	local gamemode = shorten_text(display_gamemode(lobby.gameMode or lobby.game_mode), 11)
	if is_pending_lobby then
		update_join_request_text(pending_request)
	end

	return {
		n = G.UIT.R,
		config = {
			id = "browse_lobby_" .. tostring(index),
			button = is_pending_lobby and "cancel_lobby_join_request" or "join_browsed_lobby",
			lobby_code = code,
			request_id = is_pending_lobby and pending_request.requestId or nil,
			align = "cm",
			padding = 0,
			minw = 12.5,
			minh = 0.78,
			colour = G.C.CLEAR,
			hover = true,
		},
		nodes = {
			create_lobby_row_tray({
				create_lobby_row_text_pill(owner, 2.65, "cm", LOBBY_ROW_TEXT_SCALE, G.C.BLUE),
				create_lobby_row_spacer(0.06),
				create_lobby_row_text_pill(player_count .. "/" .. max_players, 0.95, "cm", LOBBY_ROW_TEXT_SCALE, G.C.RED),
				create_lobby_row_spacer(0.06),
				create_lobby_row_text_pill(lobby_type, 1.05, "cm", LOBBY_ROW_TEXT_SCALE, LOBBY_TYPE_COLOUR),
				create_lobby_row_spacer(0.06),
				create_lobby_row_text_pill(ruleset, 2.85, "cm", LOBBY_ROW_TEXT_SCALE, G.C.RED),
				create_lobby_row_spacer(0.06),
				create_lobby_row_text_pill(gamemode, 2.25, "cm", LOBBY_ROW_TEXT_SCALE, G.C.ORANGE),
				create_lobby_row_spacer(0.06),
				is_pending_lobby and create_lobby_row_dynamic_pill(pending_request, "display", 1.75, "cm", LOBBY_ROW_TEXT_SCALE, access_colour)
					or create_lobby_row_text_pill(access_label, 1.75, "cm", LOBBY_ROW_TEXT_SCALE, access_colour),
			}),
		},
	}
end

local function get_lobby_browser_page(total_pages)
	total_pages = math.max(1, tonumber(total_pages) or 1)
	local page = math.floor(tonumber(view_model.browse_lobbies_page) or 1)
	page = math.min(math.max(1, page), total_pages)
	view_model.browse_lobbies_page = page
	return page
end

function view_model.set_browse_lobbies_page(page)
	view_model.browse_lobbies_page = math.max(1, math.floor(tonumber(page) or 1))
	return view_model.browse_lobbies_page
end

function view_model.step_browse_lobbies_page(delta)
	local lobbies = lobby_domain.get_browser_lobbies and lobby_domain.get_browser_lobbies() or {}
	local total_pages = math.max(1, math.ceil(#lobbies / LOBBY_BROWSER_ROWS_PER_PAGE))
	local page = get_lobby_browser_page(total_pages) + (tonumber(delta) or 0)
	view_model.browse_lobbies_page = math.min(math.max(1, page), total_pages)
	if view_model.refresh_browse_lobbies_overlay then
		view_model.refresh_browse_lobbies_overlay()
	end
	return view_model.browse_lobbies_page
end

function view_model.toggle_browse_lobby_names()
	view_model.hide_browse_lobby_names = not view_model.hide_browse_lobby_names
	update_browse_lobby_name_toggle_label()
	if view_model.refresh_browse_lobbies_overlay then
		view_model.refresh_browse_lobbies_overlay()
	end
	return view_model.hide_browse_lobby_names
end

local function build_lobby_browser_page_button(label, button)
	return {
		n = G.UIT.C,
		config = {
			align = "cm",
			minw = 0.68,
			minh = 0.58,
			padding = 0.025,
			r = 0.08,
			colour = G.C.PURPLE,
			line_emboss = 0.3,
			shadow = true,
			hover = true,
			button = button,
		},
		nodes = {
			create_text_node(label, 0.45, G.C.UI.TEXT_LIGHT),
		},
	}
end

local function build_lobby_browser_page_switcher(current_page, total_pages)
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.1, minw = 12.3 },
		nodes = {
			build_lobby_browser_page_button("<", "browse_lobbies_prev_page"),
			create_lobby_row_spacer(0.08),
			{
				n = G.UIT.C,
				config = {
					align = "cm",
					minw = 1.35,
					minh = 0.58,
					padding = 0.025,
					r = 0.08,
					colour = LOBBY_ROW_TRAY_COLOUR,
					line_emboss = 0.25,
				},
				nodes = {
					create_text_node(tostring(current_page) .. "/" .. tostring(total_pages), 0.45, G.C.UI.TEXT_LIGHT),
				},
			},
			create_lobby_row_spacer(0.08),
			build_lobby_browser_page_button(">", "browse_lobbies_next_page"),
		},
	}
end

local function build_lobby_browser_empty_row_slot()
	return {
		n = G.UIT.R,
		config = {
			align = "cm",
			padding = 0,
			minw = 12.5,
			minh = 0.78,
			colour = G.C.CLEAR,
		},
		nodes = {
			{ n = G.UIT.B, config = { w = 0.01, h = 0.01 } },
		},
	}
end

local function build_lobby_browser_rows()
	local rows = {}
	if lobby_domain.is_browser_pending and lobby_domain.is_browser_pending() then
		return {
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.3, minw = 10.3, minh = 4.6 },
				nodes = {
					create_text_node(localize_or_default("k_loading_lobbies", "Loading lobbies..."), 0.48, G.C.UI.TEXT_INACTIVE),
				},
			},
		}
	end

	local lobbies = lobby_domain.get_browser_lobbies and lobby_domain.get_browser_lobbies() or {}
	if #lobbies == 0 then
		return {
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.3, minw = 10.3, minh = 4.6 },
				nodes = {
					create_text_node(localize_or_default("k_no_public_lobbies", "No lobbies found"), 0.46, G.C.UI.TEXT_INACTIVE),
				},
			},
		}
	end

	local total_pages = math.max(1, math.ceil(#lobbies / LOBBY_BROWSER_ROWS_PER_PAGE))
	local current_page = get_lobby_browser_page(total_pages)
	local first_index = ((current_page - 1) * LOBBY_BROWSER_ROWS_PER_PAGE) + 1
	local last_index = math.min(#lobbies, first_index + LOBBY_BROWSER_ROWS_PER_PAGE - 1)
	for index = first_index, last_index do
		rows[#rows + 1] = build_lobby_browser_row(lobbies[index], index)
	end
	if total_pages > 1 then
		local visible_rows = last_index - first_index + 1
		for _ = visible_rows + 1, LOBBY_BROWSER_ROWS_PER_PAGE do
			rows[#rows + 1] = build_lobby_browser_empty_row_slot()
		end
		rows[#rows + 1] = build_lobby_browser_page_switcher(current_page, total_pages)
	end
	return rows
end

local function build_lobby_browser_footer_button()
	return create_overlay_button(
		"refresh_lobbies_button",
		localize_or_default("b_refresh_lobbies", "Refresh"),
		G.C.ORANGE,
		"refresh_lobbies",
		3.45,
		0.5
	)
end

local function build_lobby_browser_name_toggle_button()
	update_browse_lobby_name_toggle_label()
	return create_dynamic_button({
		id = "hide_browse_lobby_names_button",
		ref_table = view_model.browse_lobby_name_toggle,
		ref_value = "display",
		colour = G.C.BLUE,
		button = "toggle_browse_lobby_names",
		minw = 2.35,
		minh = 0.68,
		scale = 0.45,
	})
end

local function build_lobby_browser_title_row()
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.08, minw = 12.8 },
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm", minw = 2.35 },
				nodes = {
					{ n = G.UIT.B, config = { w = 0.01, h = 0.01 } },
				},
			},
			{
				n = G.UIT.C,
				config = { align = "cm", minw = 8.1 },
				nodes = {
					create_text_node(localize_or_default("k_browse_lobbies", "Browse Lobbies"), 0.62),
				},
			},
			{
				n = G.UIT.C,
				config = { align = "cm", minw = 2.35 },
				nodes = {
					build_lobby_browser_name_toggle_button(),
				},
			},
		},
	}
end

local function build_lobby_browser_notice_row()
	return {
		n = G.UIT.R,
		config = {
			id = LOBBY_BROWSER_NOTICE_ID,
			align = "cm",
			padding = 0.02,
			minh = 0.42,
			minw = 12.8,
		},
		nodes = {
			{
				n = G.UIT.O,
				config = {
					object = DynaText({
						string = {{ ref_table = view_model.browse_lobbies_notice, ref_value = "display" }},
						colours = { G.C.UI.TEXT_LIGHT },
						shadow = true,
						silent = true,
						scale = LOBBY_ROW_TEXT_SCALE,
						maxw = 12.2,
						pop_in = 0,
					}),
				},
			},
		},
	}
end

local function lobby_browser_panel_height(rows)
	return 5.7
end

local function set_overlay_marker(marker_name)
	if BALATRO.set_overlay_property then
		BALATRO.set_overlay_property(marker_name, true)
	elseif G and G.OVERLAY_MENU then
		G.OVERLAY_MENU[marker_name] = true
	end
end

function view_model.is_browse_lobbies_overlay_open()
	local overlay = BALATRO.get_overlay_menu and BALATRO.get_overlay_menu() or G.OVERLAY_MENU
	return not not (overlay and overlay.is_mp_lobby_browser)
end

local function normalize_browse_lobbies_notice_message(message)
	return tostring(message or ""):gsub("\r\n", "\n"):gsub("\n", "  ")
end

function view_model.show_browse_lobbies_notice(message, duration)
	if not view_model.is_browse_lobbies_overlay_open() then
		return false
	end

	view_model.browse_lobbies_notice.display = normalize_browse_lobbies_notice_message(message)
	view_model.browse_lobbies_notice.expires_at = get_real_time() + (tonumber(duration) or 4)
	return true
end

function view_model.clear_browse_lobbies_notice()
	view_model.browse_lobbies_notice.display = ""
	view_model.browse_lobbies_notice.expires_at = 0
end

function view_model.update_browse_lobbies_notice()
	local notice = view_model.browse_lobbies_notice
	if
		notice
		and notice.display
		and notice.display ~= ""
		and tonumber(notice.expires_at)
		and get_real_time() >= tonumber(notice.expires_at)
	then
		view_model.clear_browse_lobbies_notice()
	end
end

function view_model.create_browse_lobbies_overlay()
	local browser_rows = build_lobby_browser_rows()
	return create_UIBox_generic_options({
		back_func = "exit_overlay_menu",
		contents = {
			build_lobby_browser_title_row(),
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.08 },
				nodes = {
					{
						n = G.UIT.C,
						config = {
							id = LOBBY_BROWSER_ROWS_ID,
							align = "tm",
							padding = 0.12,
							r = 0.1,
							minw = 12.8,
							minh = lobby_browser_panel_height(browser_rows),
							colour = G.C.CLEAR,
						},
						nodes = browser_rows,
					},
				},
			},
			build_lobby_browser_notice_row(),
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.08 },
				nodes = {
					build_lobby_browser_footer_button(),
				},
			},
		},
	})
end

function view_model.open_browse_lobbies_overlay()
	BALATRO.set_paused(true)
	BALATRO.open_overlay_menu({
		definition = view_model.create_browse_lobbies_overlay(),
	})
	set_overlay_marker("is_mp_lobby_browser")
	return true
end

function view_model.refresh_browse_lobbies_overlay()
	local overlay = BALATRO.get_overlay_menu and BALATRO.get_overlay_menu() or G.OVERLAY_MENU
	if not (overlay and overlay.is_mp_lobby_browser) then
		return false
	end
	local rows_container = overlay.get_UIE_by_ID and overlay:get_UIE_by_ID(LOBBY_BROWSER_ROWS_ID) or nil
	if not (rows_container and rows_container.children and rows_container.UIBox and rows_container.UIBox.set_parent_child) then
		if BALATRO.exit_overlay_menu then
			BALATRO.exit_overlay_menu()
		end
		return view_model.open_browse_lobbies_overlay()
	end

	for i = #rows_container.children, 1, -1 do
		rows_container.children[i]:remove()
		table.remove(rows_container.children, i)
	end
	local browser_rows = build_lobby_browser_rows()
	rows_container.config.minh = lobby_browser_panel_height(browser_rows)
	for _, node in ipairs(browser_rows) do
		rows_container.UIBox:set_parent_child(node, rows_container)
	end
	rows_container.UIBox:recalculate()
	return true
end

function view_model.create_join_request_notification(request)
	request = request or {}
	local username = shorten_text(request.username or "Guest", 18)
	update_join_request_text(request)
	return {
		n = G.UIT.ROOT,
		config = {
			id = JOIN_REQUEST_NOTIFICATION_ID,
			align = "cm",
			padding = 0.1,
			r = 0.12,
			minw = 5.7,
			colour = G.C.L_BLACK,
			outline = 1,
			outline_colour = G.C.WHITE,
			line_emboss = 0.5,
			emboss = 0.05,
			shadow = true,
		},
		nodes = {
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.08, maxw = 5.2 },
				nodes = {
					create_text_node(username, 0.42, G.C.GREEN),
					create_text_node(" " .. localize_or_default("k_wants_to_join", "wants to join"), 0.42, G.C.UI.TEXT_LIGHT),
				},
			},
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.02 },
				nodes = {
					{
						n = G.UIT.O,
						config = {
							object = DynaText({
								string = {{ ref_table = request, ref_value = "notice_display" }},
								colours = { G.C.UI.TEXT_LIGHT },
								shadow = true,
								silent = true,
								scale = 0.42,
								pop_in = 0,
							}),
						},
					},
				},
			},
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.06 },
				nodes = {
					create_overlay_button(
						"approve_lobby_join_request_button",
						localize_or_default("b_accept", "Accept"),
						G.C.GREEN,
						"approve_lobby_join_request",
						1.45,
						0.38,
						{ request_id = request.requestId, ref_table = { request_id = request.requestId }, col = true }
					),
					create_overlay_button(
						"deny_lobby_join_request_button",
						localize_or_default("b_deny", "Deny"),
						G.C.RED,
						"deny_lobby_join_request",
						1.35,
						0.38,
						{ request_id = request.requestId, ref_table = { request_id = request.requestId }, col = true }
					),
					create_overlay_button(
						"block_lobby_join_request_button",
						localize_or_default("b_block", "Block"),
						G.C.PURPLE,
						"block_lobby_join_request",
						1.45,
						0.38,
						{ request_id = request.requestId, ref_table = { request_id = request.requestId }, col = true }
					),
				},
			},
		},
	}
end

local function remove_join_request_notification_immediate()
	if G.MP_JOIN_REQUEST_NOTIFICATION_UI then
		G.MP_JOIN_REQUEST_NOTIFICATION_UI:remove()
		G.MP_JOIN_REQUEST_NOTIFICATION_UI = nil
	end
	G.MP_JOIN_REQUEST_NOTIFICATION = nil
	G.MP_JOIN_REQUEST_NOTIFICATION_CLOSING = nil
end

local function collect_live_join_requests()
	local requests = lobby_domain.get_pending_join_requests and lobby_domain.get_pending_join_requests() or {}
	local queued = {}
	for _, request in pairs(requests) do
		if type(request) == "table" and request.requestId then
			if update_join_request_text(request) <= 0 then
				if lobby_domain.remove_join_request then
					lobby_domain.remove_join_request(request.requestId)
				end
			else
				queued[#queued + 1] = request
			end
		end
	end

	table.sort(queued, function(left, right)
		local left_order = tonumber(left.queueOrder) or tonumber(left.expiresAt) or 0
		local right_order = tonumber(right.queueOrder) or tonumber(right.expiresAt) or 0
		return left_order < right_order
	end)

	return queued
end

function view_model.show_next_join_request_notification()
	if G.MP_JOIN_REQUEST_NOTIFICATION_UI or G.MP_JOIN_REQUEST_NOTIFICATION or G.MP_JOIN_REQUEST_NOTIFICATION_CLOSING then
		return false
	end

	local queued = collect_live_join_requests()
	if #queued == 0 then
		return false
	end

	return view_model.open_join_request_notification(queued[1])
end

function view_model.close_join_request_notification(request_id)
	local active_request = G.MP_JOIN_REQUEST_NOTIFICATION
	if active_request and request_id and tostring(active_request.requestId) ~= tostring(request_id) then
		return false
	end

	local notification = G.MP_JOIN_REQUEST_NOTIFICATION_UI
	if not notification then
		G.MP_JOIN_REQUEST_NOTIFICATION = nil
		return false
	end

	G.MP_JOIN_REQUEST_NOTIFICATION_UI = nil
	G.MP_JOIN_REQUEST_NOTIFICATION = nil
	G.MP_JOIN_REQUEST_NOTIFICATION_CLOSING = true
	if notification.alignment and notification.alignment.offset then
		BALATRO.queue_event({
			trigger = "ease",
			timer = "REAL",
			blockable = false,
			blocking = false,
			ref_table = notification.alignment.offset,
			ref_value = "x",
			ease_to = 4.0,
			delay = 0.08,
			func = function(t)
				return t
			end,
		})
		BALATRO.queue_event({
			trigger = "after",
			timer = "REAL",
			blockable = false,
			blocking = false,
			delay = 0.1,
			func = function()
				notification:remove()
				G.MP_JOIN_REQUEST_NOTIFICATION_CLOSING = nil
				view_model.show_next_join_request_notification()
				return true
			end,
		})
	else
		notification:remove()
		G.MP_JOIN_REQUEST_NOTIFICATION_CLOSING = nil
		view_model.show_next_join_request_notification()
	end
	return true
end

function view_model.open_join_request_notification(request)
	if not (request and request.requestId) then
		return false
	end
	if G.MP_JOIN_REQUEST_NOTIFICATION_UI or G.MP_JOIN_REQUEST_NOTIFICATION or G.MP_JOIN_REQUEST_NOTIFICATION_CLOSING then
		return true
	end
	remove_join_request_notification_immediate()
	G.MP_JOIN_REQUEST_NOTIFICATION = request
	G.MP_JOIN_REQUEST_NOTIFICATION_UI = UIBox({
		definition = view_model.create_join_request_notification(request),
		config = {
			align = "cri",
			bond = "Weak",
			offset = { x = 4.0, y = -1.1 },
			major = G.ROOM_ATTACH,
		},
	})
	if G.MP_JOIN_REQUEST_NOTIFICATION_UI and G.MP_JOIN_REQUEST_NOTIFICATION_UI.alignment then
		BALATRO.queue_event({
			trigger = "ease",
			timer = "REAL",
			blockable = false,
			blocking = false,
			ref_table = G.MP_JOIN_REQUEST_NOTIFICATION_UI.alignment.offset,
			ref_value = "x",
			ease_to = -0.15,
			delay = 0.08,
			func = function(t)
				return t
			end,
		})
	end
	return true
end

function view_model.update_join_request_ui()
	local pending_request = get_pending_join_request()
	if pending_request then
		if update_join_request_text(pending_request) <= 0 then
			if lobby_domain.clear_pending_join_request then
				lobby_domain.clear_pending_join_request(pending_request.requestId)
			end
			if MP.UI and MP.UI.refresh_main_menu_multiplayer_buttons then
				MP.UI.refresh_main_menu_multiplayer_buttons()
			end
			view_model.refresh_browse_lobbies_overlay()
		end
	end

	local notification_request = G.MP_JOIN_REQUEST_NOTIFICATION
	if notification_request then
		if update_join_request_text(notification_request) <= 0 then
			if lobby_domain.remove_join_request then
				lobby_domain.remove_join_request(notification_request.requestId)
			end
			view_model.close_join_request_notification(notification_request.requestId)
		end
	elseif not G.MP_JOIN_REQUEST_NOTIFICATION_CLOSING then
		view_model.show_next_join_request_notification()
	end
end

if MP.GAME_UPDATE_CYCLE and MP.GAME_UPDATE_CYCLE.register_after then
	MP.GAME_UPDATE_CYCLE.register_after("mp.ui.join_request_notifications", function()
		view_model.update_join_request_ui()
	end, 90)
	MP.GAME_UPDATE_CYCLE.register_after("mp.ui.browse_lobbies_notice", function()
		view_model.update_browse_lobbies_notice()
	end, 91)
end

function view_model.create_join_lobby_overlay()
	return create_UIBox_generic_options({
		back_func = "exit_overlay_menu",
		contents = {
			{
				n = G.UIT.R,
				config = {
					padding = 0,
					align = "cm",
				},
				nodes = {
					{
						n = G.UIT.R,
						config = {
							padding = 0.5,
							align = "cm",
						},
						nodes = {
							create_text_input({
								w = 4,
								h = 1,
								max_length = 5,
								all_caps = true,
								prompt_text = localize("k_enter_lobby_code"),
								ref_table = MP.LOBBY.setup,
								ref_value = "temp_code",
								extended_corpus = false,
								keyboard_offset = 4,
								minw = 5,
								callback = function()
									MP.ACTIONS.join_lobby(MP.LOBBY.setup.temp_code)
								end,
							}),
						},
					},
				},
			},
		},
	})
end

function view_model.create_weekly_interrupt_overlay()
	return create_UIBox_generic_options({
		back_func = "create_group_lobby",
		contents = {
			{
				n = G.UIT.R,
				config = {
					align = "cm",
					padding = 0.1,
				},
				nodes = {
					{
						n = G.UIT.T,
						config = {
							text = "A new weekly ruleset is available!",
							colour = G.C.UI.TEXT_LIGHT,
							scale = 0.45,
						},
					},
				},
			},
			{
				n = G.UIT.R,
				config = {
					align = "cm",
					padding = 0.2,
				},
				nodes = {
					{
						n = G.UIT.T,
						config = {
							text = localize("k_currently_colon") .. localize("k_weekly_" .. MP.LOBBY.setup.fetched_weekly),
							colour = darken(G.C.UI.TEXT_LIGHT, 0.2),
							scale = 0.35,
						},
					},
				},
			},
			create_play_button("k_sync_locally", G.C.DARK_EDITION, "set_weekly"),
		},
	})
end

G.UIDEF.override_main_menu_play_button = view_model.create_play_options_overlay
G.UIDEF.create_UIBox_join_lobby_button = view_model.create_join_lobby_overlay
G.UIDEF.weekly_interrupt = view_model.create_weekly_interrupt_overlay
