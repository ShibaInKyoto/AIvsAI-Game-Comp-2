extends TestCase
## Dive scores and the personal records table.


func _run(depth: int, kills: int, outcome: RunState.Outcome, pressure := 0) -> RunState:
	var run := RunState.new()
	run.rebuild_stats({})
	run.deepest_depth = depth
	run.kills = kills
	run.outcome = outcome
	run.pressure = pressure
	return run


func test_score_adds_up_and_pressure_multiplies() -> void:
	var run := _run(1200, 4, RunState.Outcome.SURFACED)
	run.scans = 2
	run.logs = 1
	run.salvage = 90
	run.ambushes = 3
	var expected := 1200 + 4 * DiveScore.PER_KILL + 3 * DiveScore.PER_AMBUSH + 2 * DiveScore.PER_SCAN \
		+ DiveScore.PER_LOG + 90 + DiveScore.SURFACED_BONUS
	check_eq(DiveScore.total(run), expected, "every part counts")
	run.pressure = 2
	check_eq(DiveScore.total(run), roundi(expected * 1.5), "pressure 2 multiplies by 1.5")
	check(DiveScore.describe(run).contains("pressure"), "the description names the multiplier")
	var win := _run(11000, 0, RunState.Outcome.VICTORY)
	check_eq(DiveScore.total(win), 11000 + DiveScore.VICTORY_BONUS, "silencing the Choir pays a bonus")
	check_eq(DiveScore.outcome_label(_run(10, 0, RunState.Outcome.IMPLODED)), "Abandoned", "hull left: abandoned")


func test_records_keep_the_best_five_in_order() -> void:
	var m := MetaState.new()
	check_eq(m.record_dive({"score": 0}), -1, "an empty dive is not filed")
	for s in [500, 900, 100, 700, 300]:
		m.record_dive(DiveScore.record(_run(s, 0, RunState.Outcome.IMPLODED), "2026-10-28"))
	check_eq(m.best_score(), 900, "the best leads")
	check_eq(m.record_dive(DiveScore.record(_run(50, 0, RunState.Outcome.IMPLODED), "")), -1,
		"a sixth worse dive does not place")
	check_eq(m.record_dive(DiveScore.record(_run(800, 0, RunState.Outcome.IMPLODED), "")), 1, "800 places second")
	check_eq(m.records.size(), MetaState.MAX_RECORDS, "the table stays at five")
	check_eq(int(m.records[-1].score), 300, "the worst dive fell off")


func test_records_survive_a_save_and_bad_data() -> void:
	var m := MetaState.new()
	m.record_dive(DiveScore.record(_run(640, 2, RunState.Outcome.SURFACED), "2026-10-28"))
	var d: Dictionary = JSON.parse_string(JSON.stringify(m.to_dict()))
	d.records.append("garbage")
	d.records.append({"score": "77"})
	var copy := MetaState.from_dict(d)
	check_eq(copy.records.size(), 2, "garbage entries are dropped")
	check_eq(copy.best_score(), m.best_score(), "the best survives")
	check_eq(copy.records[0].outcome, "Surfaced", "fields survive")
	check_eq(copy.records[1].frame, "lantern", "missing fields get defaults")
