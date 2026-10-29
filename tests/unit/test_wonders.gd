extends TestCase
## The wonders of the trench: each witnessed once, kept with the rest of the
## progress, and each tied to a real log where it names one.


func test_listed_once_and_told_of_in_real_logs() -> void:
	var ids: Array[String] = []
	for w in Wonders.ALL:
		check(not ids.has(w.id), "%s is listed once" % w.id)
		ids.append(w.id)
		check(w.name != "" and w.text != "" and w.where != "", "%s is described" % w.id)
		if w.has("log"):
			check(not SignalLogs.get_log(StringName(w.log)).is_empty(), "%s's log %s exists" % [w.id, w.log])


func test_witnessed_once_and_kept() -> void:
	var before := Game.meta.wonders.duplicate()
	var run_before := Game.run
	Game.run = RunState.new()
	Game.run.rebuild_stats({})
	Game.meta.wonders.clear()
	Wonders.witness("glass")
	Wonders.witness("glass")
	Wonders.witness("no_such_wonder")
	check_eq(Game.meta.wonders.size(), 1, "witnessed once, and only what is listed")
	check_eq(Wonders.found_count(Game.meta.wonders), 1, "counted")
	var copy := MetaState.from_dict(JSON.parse_string(JSON.stringify(Game.meta.to_dict())))
	check(copy.wonders.has("glass"), "kept in the save")
	check_eq(Game.run.wonders, ["glass"] as Array[String], "and listed for this dive's report")
	check_eq(Game.run.research, Wonders.RESEARCH, "for a little research")
	var run_copy := RunState.from_dict(JSON.parse_string(JSON.stringify(Game.run.to_dict())), {})
	check(run_copy.wonders.has("glass"), "even across a resumed dive")
	Game.run = run_before
	Game.meta.wonders = before


func test_snapshots_load_back() -> void:
	var img := Image.create(32, 18, false, Image.FORMAT_RGB8)
	DirAccess.make_dir_recursive_absolute(Wonders.SNAPSHOT_DIR)
	img.save_png(Wonders.snapshot_path("zz_test"))
	check(Wonders.snapshot("zz_test") != null, "a kept snapshot loads back")
	DirAccess.remove_absolute(Wonders.snapshot_path("zz_test"))
	check(Wonders.snapshot("zz_test") == null, "and a missing one is null")
