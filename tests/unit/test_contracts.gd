extends TestCase
## Dive contracts: a handicap for one dive in exchange for a bigger score
## and payout, taken in the hangar and used up when the dive starts.


func test_every_contract_changes_the_dive_and_pays_for_it() -> void:
	var plain := SubStats.build(&"lantern", {}, [])
	for c in Contracts.all():
		check(c.score_mult > 1.0 or c.salvage_mult > 1.0 or c.research_mult > 1.0, "%s pays something" % c.name)
		check(c.rewards() != "", "%s lists its rewards" % c.name)
		var stats := SubStats.build(&"lantern", {}, [], c.id)
		var changed := stats.max_hull != plain.max_hull or stats.sonar_cost != plain.sonar_cost \
			or stats.lamp_range != plain.lamp_range or stats.max_battery != plain.max_battery or c.creature_mult != 1.0
		check(changed, "%s is a real handicap" % c.name)
	check_near(SubStats.build(&"lantern", {}, [], &"glass_hull").max_hull, plain.max_hull * 0.6, 0.01,
		"Glass Hull takes 40% of the hull")


func test_contract_scores_and_survives_a_save() -> void:
	var run := RunState.new()
	run.contract = &"glass_hull"
	run.rebuild_stats({})
	run.deepest_depth = 1000
	run.outcome = RunState.Outcome.IMPLODED
	check_eq(DiveScore.total(run), 1500, "Glass Hull scores x1.5")
	check(DiveScore.describe(run).contains("Glass Hull"), "the score explains the multiplier")
	var copy := RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())), {})
	check_eq(copy.contract, &"glass_hull", "a resumed dive keeps its contract")
	check_near(copy.stats.max_hull, run.stats.max_hull, 0.01, "and its handicap")
	var bad := run.to_dict()
	bad.contract = "free_money"
	check_eq(RunState.from_dict(bad, {}).contract, &"", "an unknown contract is dropped")
	check_eq(DiveScore.record(run, "").contract, "glass_hull", "records note the contract")


func test_unknown_selection_is_dropped_on_load() -> void:
	var m := MetaState.new()
	m.contract_selected = "infested"
	check_eq(MetaState.from_dict(JSON.parse_string(JSON.stringify(m.to_dict()))).contract_selected, "infested",
		"a chosen contract survives a save")
	var d := m.to_dict()
	d.contract_selected = "nonsense"
	check_eq(MetaState.from_dict(d).contract_selected, "", "a bogus one does not")
