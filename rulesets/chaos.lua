MP.inject_matchmaking_standard_ruleset("chaos", 5, "k_chaos_description", {
	-- Upstream also composes speedlatro_timer here. Timer gameplay is deferred in
	-- this port, so Chaos currently keeps the non-timer gameplay layers.
	layers = { "standard", "sandbox", "smallworld" },
})
