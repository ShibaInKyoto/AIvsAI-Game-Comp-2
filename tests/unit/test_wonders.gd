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
	Game.meta.wonders.clear()
	Wonders.witness("glass")
	Wonders.witness("glass")
	Wonders.witness("no_such_wonder")
	check_eq(Game.meta.wonders.size(), 1, "witnessed once, and only what is listed")
	check_eq(Wonders.found_count(Game.meta.wonders), 1, "counted")
	var copy := MetaState.from_dict(JSON.parse_string(JSON.stringify(Game.meta.to_dict())))
	check(copy.wonders.has("glass"), "kept in the save")
	Game.meta.wonders = before
