extends TestCase
## Persistent progression: purchases, unlocks and serialization.


func test_buy_upgrade_deducts_salvage() -> void:
	var m := MetaState.new()
	m.salvage = 100
	check(m.buy_upgrade(&"hull"))
	check_eq(m.salvage, 40)
	check_eq(m.upgrade_level(&"hull"), 1)
	check(not m.buy_upgrade(&"hull"), "cannot afford level 2")


func test_upgrades_cap_at_max_level() -> void:
	var m := MetaState.new()
	m.salvage = 100000
	for i in 10:
		m.buy_upgrade(&"lamp")
	check_eq(m.upgrade_level(&"lamp"), Catalog.upgrade(&"lamp").max_level())


func test_unlock_frame_costs_research() -> void:
	var m := MetaState.new()
	m.research = 39
	check(not m.unlock_frame(&"mako"))
	m.research = 45
	check(m.unlock_frame(&"mako"))
	check_eq(m.research, 5)
	check(m.is_frame_unlocked(&"mako"))


func test_round_trip() -> void:
	var m := MetaState.new()
	m.salvage = 321
	m.research = 12
	m.upgrades["sonar"] = 2
	m.unlocked_frames.append("mako")
	m.selected_frame = "mako"
	m.codex["lancer"] = 3
	m.logs_found.append("log_01")
	m.deepest_depth = 4321
	var copy := MetaState.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check_eq(copy.salvage, 321)
	check_eq(copy.upgrade_level(&"sonar"), 2)
	check_eq(copy.selected_frame, "mako")
	check_eq(copy.codex.get("lancer"), 3)
	check(copy.logs_found.has("log_01"))
	check_eq(copy.deepest_depth, 4321)


func test_corrupt_data_falls_back() -> void:
	var copy := MetaState.from_dict({"selected_frame": "nonexistent", "unlocked_frames": []})
	check_eq(copy.selected_frame, "lantern")
	check(copy.is_frame_unlocked(&"lantern"))
