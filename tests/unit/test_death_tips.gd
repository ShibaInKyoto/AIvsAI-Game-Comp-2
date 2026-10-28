extends TestCase
## Every creature that can sink the sub has a cause description and a tip.


func test_every_species_has_a_tip() -> void:
	for e in CreatureCodex.entries():
		if e.id == &"shoal":
			continue
		check(DeathTips.TIPS.has(e.id), "tip for %s" % e.id)
		check(DeathTips.describe(e.id) != "", "description for %s" % e.id)


func test_unknown_cause_falls_back() -> void:
	check_eq(DeathTips.tip(&"nonsense"), DeathTips.FALLBACK)
	check_eq(DeathTips.cause_of(null), &"rock")
