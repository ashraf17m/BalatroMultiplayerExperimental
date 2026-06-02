local DEFAULT_BLIND_COL = 1
local BLIND_COLOUR_KEYS = {
	"tooth",
	"small",
	"big",
	"hook",
	"ox",
	"house",
	"wall",
	"wheel",
	"arm",
	"club",
	"fish",
	"psychic",
	"goad",
	"water",
	"window",
	"manacle",
	"eye",
	"mouth",
	"plant",
	"serpent",
	"pillar",
	"needle",
	"head",
	"flint",
	"mark",
}

function MP.UTILS.save_username(text)
	MP.ACTIONS.set_username(text)
	MP.PLATFORM.SMODS.set_config_value("username", text)
end

function MP.UTILS.get_username()
	return MP.PLATFORM.SMODS.get_config_value("username")
end

function MP.UTILS.get_blind_col_count()
	return #BLIND_COLOUR_KEYS
end

function MP.UTILS.clamp_blind_col(num)
	local blind_col = math.floor(tonumber(num) or DEFAULT_BLIND_COL)
	return math.max(DEFAULT_BLIND_COL, math.min(blind_col, #BLIND_COLOUR_KEYS))
end

function MP.UTILS.save_blind_col(num)
	local blind_col = MP.UTILS.clamp_blind_col(num)
	MP.ACTIONS.set_blind_col(blind_col)
	MP.PLATFORM.SMODS.set_config_value("blind_col", blind_col)
	return blind_col
end

function MP.UTILS.get_blind_col()
	return MP.UTILS.clamp_blind_col(MP.PLATFORM.SMODS.get_config_value("blind_col"))
end

function MP.UTILS.blind_col_numtokey(num)
	return "bl_" .. BLIND_COLOUR_KEYS[MP.UTILS.clamp_blind_col(num)]
end

function MP.UTILS.get_pvp_blind_key() -- calling this function assumes the user is currently in a multiplayer game
	local opponents = MP.OPPONENTS or {}
	local nemesis_player = opponents.get_nemesis_lobby_player and opponents.get_nemesis_lobby_player() or nil
	local ret = MP.UTILS.blind_col_numtokey((nemesis_player and nemesis_player.blind_col) or 1)
	local enemy_view = opponents.get_primary_enemy_state and opponents.get_primary_enemy_state()
	if enemy_view and tonumber(enemy_view.lives) <= 1 and tonumber(MP.GAME.lives) <= 1 then
		if G.STATE ~= G.STATES.ROUND_EVAL then
			ret = "bl_final_heart"
		end
	end
	return ret
end

local DEFAULT_CALCULATOR_LABELS = {
	text = "CALCULATING",
	button = "Calculate Score",
}

local function get_non_empty_config_string(path)
	local value = MP.PLATFORM.SMODS.get_config_value(path)
	if type(value) == "string" and #value > 0 then
		return value
	end
	return nil
end

function MP.UTILS.save_calculator_labels(labels)
	for key in pairs(DEFAULT_CALCULATOR_LABELS) do
		MP.PLATFORM.SMODS.set_config_value({ "calculator", key }, labels and labels[key] or "")
	end
end

function MP.UTILS.get_calculator_label(index)
	return get_non_empty_config_string({ "calculator", index })
		or get_non_empty_config_string({ "preview", index })
		or DEFAULT_CALCULATOR_LABELS[index]
		or ""
end

function MP.UTILS.copy_to_clipboard(text)
	if G.F_LOCAL_CLIPBOARD then
		G.CLIPBOARD = text
	else
		love.system.setClipboardText(text)
	end
end

function MP.UTILS.get_from_clipboard()
	if G.F_LOCAL_CLIPBOARD then
		return G.F_LOCAL_CLIPBOARD
	else
		return love.system.getClipboardText()
	end
end

function MP.UTILS.random_message()
	local messages = {
		localize("k_message1"),
		localize("k_message2"),
		localize("k_message3"),
		localize("k_message4"),
		localize("k_message5"),
		localize("k_message6"),
		localize("k_message7"),
		localize("k_message8"),
		localize("k_message9"),
	}
	return messages[math.random(1, #messages)]
end
