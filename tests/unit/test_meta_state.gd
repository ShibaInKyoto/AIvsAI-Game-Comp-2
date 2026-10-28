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


func test_milestones_award_once_and_persist() -> void:
	var m := MetaState.new()
	m.deepest_zone = 4
	var first := Milestones.check(m, null)
	var ids := first.map(func(x: Milestones.Milestone) -> String: return x.id)
	check(ids.has("first_descent") and ids.has("twilight") and ids.has("midnight"), "depth milestones awarded")
	check(not ids.has("vents"), "deeper milestone not awarded yet")
	check(Milestones.check(m, null).is_empty(), "nothing awarded twice")
	m.paint = "midnight"
	var copy := MetaState.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check_eq(copy.paint, "midnight")
	check(copy.milestones.has("twilight"))


func test_paint_requires_milestone() -> void:
	var copy := MetaState.from_dict({"paint": "answer", "milestones": []})
	check_eq(copy.paint, "", "unearned paint is dropped")


func test_daily_record_resets_each_day() -> void:
	var m := MetaState.new()
	check_eq(m.daily_summary("2026-10-28"), "")
	m.begin_daily("2026-10-28")
	m.daily_best_depth = 1500
	m.begin_daily("2026-10-28")
	check_eq(m.daily_attempts, 2)
	check(m.daily_summary("2026-10-28").contains("1,500"), "summary shows the best depth")
	var restored := MetaState.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check_eq(restored.daily_best_depth, 1500)
	restored.begin_daily("2026-10-29")
	check_eq(restored.daily_attempts, 1)
	check_eq(restored.daily_best_depth, 0)
	check_eq(m.daily_summary("2026-10-29"), "")
