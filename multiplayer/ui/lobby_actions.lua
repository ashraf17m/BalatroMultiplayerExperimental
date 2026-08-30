local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function open_overlay_definition(definition)
	G.FUNCS.overlay_menu({
		definition = definition,
	})
end

local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY or {}
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}

local function request_lobby_main_menu_refresh()
	if MP.UI and MP.UI.request_lobby_main_menu_refresh then
		return MP.UI.request_lobby_main_menu_refresh()
	end
	return false
end

local function apply_local_ready_state(player, is_ready)
	if not player then
		return false
	end

	player.is_ready = not not is_ready
	if MP.lobby_uses_ready and MP.lobby_uses_ready() then
		player.status_text = player.is_ready and localize("b_ready") or localize("b_unready")
		player.status_kind = player.is_ready and "ready" or "waiting"
	end

	return true
end

local function toggle_lobby_ready()
	if not MP.lobby_uses_ready() then
		return false
	end
	if MP.LOBBY.client and MP.LOBBY.client.pending_lobby_ready ~= nil then
		return false
	end

	local self_player = MP.get_self_lobby_player and MP.get_self_lobby_player() or nil
	local is_ready = not (self_player and self_player.is_ready)
	if lobby_domain.set_pending_ready then
		lobby_domain.set_pending_ready(is_ready)
	end
	apply_local_ready_state(self_player, is_ready)
	request_lobby_main_menu_refresh()

	if is_ready then
		MP.ACTIONS.ready_lobby()
	else
		MP.ACTIONS.unready_lobby()
	end

	return true
end

local function open_lobby_options_overlay(preserve_active_tab)
	if MP.is_lobby_match_in_progress() then
		return false
	end

	if not preserve_active_tab and MP.UI and MP.UI.LOBBY_VIEW_MODEL then
		MP.UI.LOBBY_VIEW_MODEL.active_lobby_options_tab = "general"
	end
	open_overlay_definition(G.UIDEF.create_UIBox_lobby_options())

	return true
end

local function finalize_lobby_leave()
	G.FUNCS.exit_overlay_menu()
	if MP.UI and MP.UI.reset_version_mismatch_warning then
		MP.UI.reset_version_mismatch_warning()
	end
	if MP.COOP_SAVE and MP.COOP_SAVE.consume_active_resumed_save then
		MP.COOP_SAVE.consume_active_resumed_save()
	end
	if MP.MATCH_LIFECYCLE and MP.MATCH_LIFECYCLE.suspend_team_card_sync then
		MP.MATCH_LIFECYCLE.suspend_team_card_sync()
	end
	MP.ACTIONS.leave_lobby()
	if MP.CONNECTION_SESSION and MP.CONNECTION_SESSION.clear_local_lobby_session then
		MP.CONNECTION_SESSION.clear_local_lobby_session({
			clear_reconnect = false,
		})
	end

	if G.STAGE ~= G.STAGES.MAIN_MENU then
		G.FUNCS.go_to_menu()
		match_domain.reset_state()
	else
		G.STATE = G.STATES.MENU
	end
end

local function leave_lobby()
	if G.STAGE ~= G.STAGES.MAIN_MENU then
		G.FUNCS.confirm_selection(function()
			finalize_lobby_leave()
		end)
	else
		finalize_lobby_leave()
	end
end

local function process_pending_lobby_option_failure()
	local runtime = MP.UI and MP.UI.get_lobby_session_runtime and MP.UI.get_lobby_session_runtime() or nil
	local failure_message = runtime and runtime.pending_option_failure_message or nil
	if not failure_message then
		return false
	end

	runtime.pending_option_failure_message = nil
	leave_lobby()

	if MP.UI and MP.UI.UTILS and MP.UI.UTILS.overlay_message then
		MP.UI.UTILS.overlay_message(failure_message)
	end

	return true
end

local function update_coop_save_button_label(e)
	if MP.COOP_SAVE and MP.COOP_SAVE.update_button_node then
		return MP.COOP_SAVE.update_button_node(e)
	end

	return false
end

local function can_choose_lobby_deck()
	if not MP.LOBBY or MP.LOBBY.is_saved_coop_restore then
		return false
	end

	return MP.LOBBY.is_host or (MP.LOBBY.config and MP.LOBBY.config.different_decks)
end

local function get_center(key)
	return BALATRO.get_center and BALATRO.get_center(key) or G and G.P_CENTERS and G.P_CENTERS[key] or nil
end

local function append_back_name(names, seen, center)
	local name = center and center.name or nil
	if name and name ~= "" and not seen[name] then
		seen[name] = true
		names[#names + 1] = name
	end
end

local function get_cocktail_deck_keys()
	local content_runtime = MP.CONTENT and MP.CONTENT.RUNTIME or {}
	if content_runtime.get_cocktail_decks then
		local deck_keys = content_runtime.get_cocktail_decks(false)
		if type(deck_keys) == "table" then
			return deck_keys
		end
	end

	if MP.get_cocktail_decks then
		local deck_keys = MP.get_cocktail_decks(false)
		if type(deck_keys) == "table" then
			return deck_keys
		end
	end

	return nil
end

local function get_random_back_pool()
	local names, seen = {}, {}
	local cocktail_deck_keys = get_cocktail_deck_keys()

	for _, key in ipairs(cocktail_deck_keys or {}) do
		append_back_name(names, seen, get_center(key))
	end
	append_back_name(names, seen, get_center("b_mp_cocktail"))

	if #names == 0 and G and G.P_CENTER_POOLS and G.P_CENTER_POOLS.Back then
		for _, center in ipairs(G.P_CENTER_POOLS.Back) do
			if center.unlocked and center.name ~= "Challenge Deck" and center.name ~= "Random Deck" then
				append_back_name(names, seen, center)
			end
		end
	end

	return names
end

local function scoped_random(seed, salt, max)
	max = math.max(1, math.floor(tonumber(max) or 1))
	if seed and seed ~= "" and pseudohash then
		math.randomseed(pseudohash(seed .. "_mp_random_" .. tostring(salt or "")))
	end
	return math.random(1, max)
end

local function roll_random_back_name(seed, salt)
	local names = get_random_back_pool()
	if #names == 0 then
		return "Red Deck"
	end
	return names[scoped_random(seed, "deck_" .. tostring(salt or ""), #names)]
end

local function roll_random_stake(seed, salt)
	local max_stake = MP.DECK and tonumber(MP.DECK.MAX_STAKE) or 0
	local cap = max_stake > 0 and max_stake or 8
	return scoped_random(seed, "stake_" .. tostring(salt or ""), cap)
end

local function get_random_loadout_salt()
	local client = MP.LOBBY and MP.LOBBY.client or nil
	if client and client.username then
		return client.username
	end
	if MP.LOBBY and MP.LOBBY.username then
		return MP.LOBBY.username
	end
	return BALATRO.get_player_id and BALATRO.get_player_id() or ""
end

local function build_random_loadout(seed, salt)
	local config = MP.LOBBY and MP.LOBBY.config or {}
	local run_deck = lobby_domain.get_run_deck and lobby_domain.get_run_deck() or MP.LOBBY and MP.LOBBY.run_deck or {}

	return {
		back = roll_random_back_name(seed, salt),
		challenge = "",
		stake = roll_random_stake(seed, salt),
		sleeve = run_deck.sleeve or config.sleeve or "sleeve_casl_none",
		cocktail = run_deck.cocktail or config.cocktail or "",
	}
end

local function apply_random_loadout_to_run_deck(loadout)
	if lobby_domain.update_run_deck then
		return lobby_domain.update_run_deck(loadout)
	end
	if MP.LOBBY then
		MP.LOBBY.run_deck = loadout
	end
	return loadout
end

local function apply_shared_random_loadout()
	local loadout = build_random_loadout()
	local config = MP.LOBBY and MP.LOBBY.config or nil
	if config then
		for key, value in pairs(loadout) do
			config[key] = value
		end
	end
	apply_random_loadout_to_run_deck(loadout)

	if MP.ACTIONS and MP.ACTIONS.lobby_options then
		MP.ACTIONS.lobby_options(loadout)
	end
	request_lobby_main_menu_refresh()
	return loadout
end

---@type fun(e: table | nil, args: { deck: string, stake: number | nil, seed: string | nil })
function G.FUNCS.lobby_start_run(e, args)
	args = args or {}
	local config = MP.LOBBY and MP.LOBBY.config or {}

	if config.different_decks == false and lobby_domain.sync_run_deck_from_config then
		lobby_domain.sync_run_deck_from_config()
	elseif config.different_decks and config.random_loadout then
		apply_random_loadout_to_run_deck(build_random_loadout(args.seed, get_random_loadout_salt()))
	end

	local run_deck = lobby_domain.get_run_deck and lobby_domain.get_run_deck() or MP.LOBBY.run_deck

	local challenge = nil
	if run_deck.back == "Challenge Deck" then
		challenge = G.CHALLENGES[get_challenge_int_from_id(run_deck.challenge)]
	else
		BALATRO.set_game_value("viewed_back", BALATRO.get_center(MP.UTILS.get_deck_key_from_name(run_deck.back)))
	end

	G.FUNCS.start_run(e, {
		mp_start = true,
		challenge = challenge,
		stake = tonumber(run_deck.stake),
		seed = args.seed,
		savetext = args.savetext,
	})
end

MP.HOOKS.register_method_hook(Back, "Back", "generate_UI", "mp.lobby_actions.challenge_deck_overlay", {
	before = function(ctx, self)
		local other = ctx.args[1]
		local challenge = ctx.args[4]
		local name = other and other.name or self.name
		if not (not challenge and name == "Challenge Deck" and MP.LOBBY.code) then
			return
		end

		local run_deck = lobby_domain.get_run_deck and lobby_domain.get_run_deck() or MP.LOBBY.run_deck
		ctx.args[4] = run_deck and run_deck.challenge -- very generous assumption
		if (ctx.args.n or 0) < 4 then
			ctx.args.n = 4
		end
		ctx.mp_lobby_challenge_overlay = true
	end,
	after = function(ctx)
		if not ctx.mp_lobby_challenge_overlay then
			return
		end

		-- essentially the button opens the correct challenge menu
		-- exiting this challenge menu results in a crash that's difficult to figure out
		-- (some sort of jank when removing the ui elements)
		-- Force the borrowed challenge overlay to exit cleanly instead of tearing down stale UI.
		local ret = ctx.results and ctx.results[1]
		ret.nodes[1].nodes[1].config.button = "exit_overlay_menu"
	end,
})

function G.FUNCS.lobby_start_game(e)
	if MP.UI and MP.UI.show_version_mismatch_if_needed and MP.UI.show_version_mismatch_if_needed() then
		return
	end

	if
		MP.LOBBY
		and MP.LOBBY.is_host
		and MP.LOBBY.config
		and MP.LOBBY.config.random_loadout
		and not MP.LOBBY.config.different_decks
	then
		apply_shared_random_loadout()
	end

	MP.ACTIONS.start_game()
end

function G.FUNCS.lobby_ready_up(e)
	if MP.UI and MP.UI.show_version_mismatch_if_needed and MP.UI.show_version_mismatch_if_needed() then
		return
	end

	toggle_lobby_ready()
end

function G.FUNCS.lobby_options(e)
	if MP.LOBBY and MP.LOBBY.is_saved_coop_restore then
		return
	end

	local preserve_active_tab = e and e.config and e.config.preserve_active_lobby_options_tab
	open_lobby_options_overlay(preserve_active_tab)
end

function G.FUNCS.view_code(e)
	local text_config = e.children[1].children[1].config
	if text_config.text ~= MP.LOBBY.code then
		e.config.colour = G.C.ETERNAL
		text_config.text = MP.LOBBY.code
	else
		e.config.colour = G.C.GREEN
		text_config.text = localize("b_view_code")
	end
	e.UIBox:recalculate()
end

function G.FUNCS.lobby_leave(e)
	leave_lobby()
end

function G.FUNCS.mp_end_game_leave_lobby(e)
	finalize_lobby_leave()
end

MP.UI.process_pending_lobby_option_failure = process_pending_lobby_option_failure

function G.FUNCS.lobby_choose_deck(e)
	if not can_choose_lobby_deck() then
		return
	end

	G.FUNCS.setup_run(e)
	if G.OVERLAY_MENU then
		G.OVERLAY_MENU:get_UIE_by_ID("run_setup_seed"):remove()
	end
end

MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "start_run", "mp.lobby_actions.start_run", {
	before = function(ctx, e)
		local args = ctx.args[1] or {}
		ctx.args[1] = args
		if (ctx.args.n or 0) < 1 then
			ctx.args.n = 1
		end

		if not MP.LOBBY.code then
			return
		end

		if args.mp_resume then
			return
		end

		if MP.LOBBY.is_saved_coop_restore and not args.mp_start then
			ctx.skip_original = true
			ctx.results = { n = 0 }
			return
		end

		if not args.mp_start then
			G.FUNCS.exit_overlay_menu()
			local chosen_stake = args.stake
			if MP.DECK.MAX_STAKE > 0 and chosen_stake > MP.DECK.MAX_STAKE then
				MP.UI.UTILS.overlay_message(
					"Selected stake is incompatible with Multiplayer, stake set to "
						.. MP.PLATFORM.SMODS.get_stake_key(MP.DECK.MAX_STAKE)
				)
				chosen_stake = MP.DECK.MAX_STAKE
			end

			local content_runtime = MP.CONTENT and MP.CONTENT.RUNTIME or {}
			local selected_cocktail = content_runtime.get_cocktail_config and content_runtime.get_cocktail_config()
				or MP.LOBBY.config.cocktail
			local run_deck = lobby_domain.get_run_deck and lobby_domain.get_run_deck() or MP.LOBBY.run_deck or {}
			local selected_back = args.challenge and "Challenge Deck"
				or (args.deck and args.deck.name)
				or (BALATRO.get_game_value and BALATRO.get_game_value("viewed_back", nil) or {}).name
				or run_deck.back
				or "Red Deck"
			local selected_challenge = args.challenge and args.challenge.id or ""
			local selected_sleeve = G.viewed_sleeve
			local selected_run_deck = {
				back = selected_back,
				stake = chosen_stake,
				sleeve = selected_sleeve,
				challenge = selected_challenge,
				cocktail = selected_cocktail,
			}

			if MP.LOBBY.is_host and not MP.LOBBY.config.different_decks then
				MP.ACTIONS.lobby_options(selected_run_deck)
			end

			if lobby_domain.update_run_deck then
				lobby_domain.update_run_deck(selected_run_deck)
			end

			request_lobby_main_menu_refresh()
			ctx.skip_original = true
			ctx.results = { n = 0 }
		else
			local run_deck = lobby_domain.get_run_deck and lobby_domain.get_run_deck() or MP.LOBBY.run_deck
			ctx.args[1] = {
				challenge = args.challenge,
				stake = tonumber(run_deck.stake),
				seed = args.seed,
			}
		end
	end,
})

local function return_to_lobby_from_run()
	if MP.COOP_SAVE and MP.COOP_SAVE.consume_active_resumed_save then
		MP.COOP_SAVE.consume_active_resumed_save()
	end
	if MP.MATCH_LIFECYCLE and MP.MATCH_LIFECYCLE.suspend_team_card_sync then
		MP.MATCH_LIFECYCLE.suspend_team_card_sync()
	end
	if MP.RESUME and MP.RESUME.clear_saved_resume then
		MP.RESUME.clear_saved_resume()
	end
	if MP.ACTIONS.cache_end_game_state then
		MP.ACTIONS.cache_end_game_state()
	end
	MP.ACTIONS.return_to_lobby()
	G.FUNCS.go_to_menu()
	match_domain.reset_state()
end

function G.FUNCS.mp_return_to_lobby()
	if MP.LOBBY.is_host then
		G.FUNCS.confirm_selection(function()
			return_to_lobby_from_run()
		end)
	else
		return_to_lobby_from_run()
	end
end

function G.FUNCS.mp_end_game_return_to_lobby()
	return_to_lobby_from_run()
end

function G.FUNCS.mp_unstuck()
	open_overlay_definition(G.UIDEF.create_UIBox_unstuck())
end

function G.FUNCS.mp_unstuck_blind()
	if match_domain.reset_ready_blind_state then
		match_domain.reset_ready_blind_state()
	end
	if MP.GAME.next_blind_context then
		G.FUNCS.select_blind(MP.GAME.next_blind_context)
	else
		sendErrorMessage("No next blind context", "MULTIPLAYER")
	end
end

function G.FUNCS.mp_coop_save_run(e)
	if MP.ACTIONS and MP.ACTIONS.save_coop_run then
		if MP.ACTIONS.save_coop_run() then
			update_coop_save_button_label(e)
		end
	end
end

function G.FUNCS.copy_to_clipboard(e)
	MP.UTILS.copy_to_clipboard(MP.LOBBY.code)
end

function G.FUNCS.reconnect(e)
	MP.ACTIONS.connect()
	G.FUNCS.exit_overlay_menu()
end
