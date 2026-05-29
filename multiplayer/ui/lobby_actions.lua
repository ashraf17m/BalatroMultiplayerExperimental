local function get_lobby_session_runtime()
	return MP.UI and MP.UI.get_lobby_session_runtime and MP.UI.get_lobby_session_runtime() or nil
end

local function open_overlay_definition(definition)
	G.FUNCS.overlay_menu({
		definition = definition,
	})
end

local function toggle_lobby_ready()
	if not MP.lobby_uses_ready() then
		return false
	end
	if MP.LOBBY.client and MP.LOBBY.client.pending_lobby_ready ~= nil then
		return false
	end

	local is_ready = not MP.is_self_lobby_ready()
	if MP.set_pending_lobby_ready then
		MP.set_pending_lobby_ready(is_ready)
	end
	MP.refresh_lobby_main_menu()

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
	if MP.MATCH_LIFECYCLE and MP.MATCH_LIFECYCLE.suspend_team_card_sync then
		MP.MATCH_LIFECYCLE.suspend_team_card_sync()
	end
	if MP.CONNECTION_SESSION and MP.CONNECTION_SESSION.clear_local_lobby_session then
		MP.CONNECTION_SESSION.clear_local_lobby_session({
			clear_reconnect = false,
		})
	end
	MP.ACTIONS.leave_lobby()

	if G.STAGE ~= G.STAGES.MAIN_MENU then
		G.FUNCS.go_to_menu()
		MP.reset_game_states()
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
	local runtime = get_lobby_session_runtime()
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

function G.FUNCS.view_host_hash(e)
	open_overlay_definition(G.UIDEF.create_UIBox_view_hash("host"))
end

G.FUNCS.view_guest_hash = function(e)
	open_overlay_definition(G.UIDEF.create_UIBox_view_hash("guest"))
end

---@type fun(e: table | nil, args: { deck: string, stake: number | nil, seed: string | nil })
function G.FUNCS.lobby_start_run(e, args)
	if MP.LOBBY.config.different_decks == false and MP.sync_lobby_run_deck_from_config then
		MP.sync_lobby_run_deck_from_config()
	end

	local run_deck = MP.get_lobby_run_deck and MP.get_lobby_run_deck() or MP.LOBBY.run_deck

	local challenge = nil
	if run_deck.back == "Challenge Deck" then
		challenge = G.CHALLENGES[get_challenge_int_from_id(run_deck.challenge)]
	else
		G.GAME.viewed_back = G.P_CENTERS[MP.UTILS.get_deck_key_from_name(run_deck.back)]
	end

	G.FUNCS.start_run(e, {
		mp_start = true,
		challenge = challenge,
		stake = tonumber(run_deck.stake),
		seed = args.seed,
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

		local run_deck = MP.get_lobby_run_deck and MP.get_lobby_run_deck() or MP.LOBBY.run_deck
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
	MP.ACTIONS.start_game()
end

function G.FUNCS.lobby_ready_up(e)
	toggle_lobby_ready()
end

function G.FUNCS.lobby_options(e)
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

function MP.process_pending_lobby_option_failure()
	return process_pending_lobby_option_failure()
end

function G.FUNCS.lobby_choose_deck(e)
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

			local selected_cocktail = MP.cocktail_cfg_get and MP.cocktail_cfg_get() or MP.LOBBY.config.cocktail
			local run_deck = MP.get_lobby_run_deck and MP.get_lobby_run_deck() or MP.LOBBY.run_deck or {}
			local selected_back = args.challenge and "Challenge Deck"
				or (args.deck and args.deck.name)
				or (G.GAME and G.GAME.viewed_back and G.GAME.viewed_back.name)
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

			if MP.LOBBY.is_host then
				MP.ACTIONS.lobby_options(selected_run_deck)
			end

			if MP.update_lobby_run_deck then
				MP.update_lobby_run_deck(selected_run_deck)
			end

			MP.refresh_lobby_main_menu()
			ctx.skip_original = true
			ctx.results = { n = 0 }
		else
			local run_deck = MP.get_lobby_run_deck and MP.get_lobby_run_deck() or MP.LOBBY.run_deck
			ctx.args[1] = {
				challenge = args.challenge,
				stake = tonumber(run_deck.stake),
				seed = args.seed,
			}
		end
	end,
})

local function return_to_lobby_from_run()
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
	MP.reset_game_states()
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

function G.FUNCS.mp_unstuck_arcana()
	G.FUNCS.skip_booster()
end

function G.FUNCS.mp_unstuck_blind()
	if MP.reset_match_ready_blind_state then
		MP.reset_match_ready_blind_state()
	end
	if MP.GAME.next_blind_context then
		G.FUNCS.select_blind(MP.GAME.next_blind_context)
	else
		sendErrorMessage("No next blind context", "MULTIPLAYER")
	end
end

function G.FUNCS.copy_to_clipboard(e)
	MP.UTILS.copy_to_clipboard(MP.LOBBY.code)
end

function G.FUNCS.reconnect(e)
	MP.ACTIONS.connect()
	G.FUNCS.exit_overlay_menu()
end
