extends TestCase
## Deep starts: a dive can begin in any biome already reached, with a module
## for every stop skipped, and only the descent itself pays and scores.


func test_unlocks_follow_the_deepest_zone_reached() -> void:
	var m := MetaState.new()
	check_eq(m.deepest_start(), 0, "a new pilot starts at the surface")
	m.deepest_zone = 3
	check_eq(m.deepest_start(), 1, "reaching the reef unlocks a reef start")
	m.deepest_zone = BiomeLibrary.TOTAL_ZONES - 1
	check_eq(m.deepest_start(), BiomeLibrary.BIOME_COUNT - 1, "the hadal floor is never a start")
	m.deepest_zone = 1
	var d := m.to_dict()
	d.start_biome = 4
	check_eq(MetaState.from_dict(d).start_biome, 0, "a start not yet earned is refused")


func test_a_deep_start_skips_zones_but_not_the_payout_rules() -> void:
	var run := RunState.new()
	run.run_seed = 808
	run.rebuild_stats({})
	run.start_deep(2, {})
	run.refill()
	check_eq(run.zone, 4, "the dive begins in the first Midnight Caverns zone")
	check_eq(run.start_zone, 4, "and remembers where it began")
	check_eq(run.modules.size(), 4, "with a module for each skipped stop")
	run.deepest_depth = int(BiomeLibrary.zone_depth_range(4).x) + 300
	check_eq(run.descent(), 300, "only the metres below the start count")
	check_eq(DiveScore.breakdown(run)[0][1], 300, "the score uses the descent")
	run.zone = 6
	check_eq(Game.expedition_pay(run), 16, "expedition pay covers the zones actually descended")
	var copy := RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())), {})
	check_eq(copy.start_zone, 4, "a resumed dive keeps its start")
	check_eq(copy.modules.size(), 4, "and its free modules")
