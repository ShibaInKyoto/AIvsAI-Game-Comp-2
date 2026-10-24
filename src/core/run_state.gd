class_name RunState
extends RefCounted
## State of the dive in progress. Lives in [member Game.run] while diving.

enum Outcome { NONE, SURFACED, IMPLODED, VICTORY }

var run_seed := 0
var frame_id: StringName = &"lantern"
var zone := 0
var modules: Array[StringName] = []
var stats: SubStats
var hull := 100.0
var battery := 100.0
var torpedoes := 0
var flares := 0
var salvage := 0
var research := 0
var kills := 0
var scans := 0
var logs := 0
var time := 0.0
var pressure := 0
var daily := false
var deepest_depth := 0
var outcome := Outcome.NONE


## Deterministic seed for a zone of this run.
func zone_seed(z: int) -> int:
	return hash([run_seed, z, "zone"]) & 0x7fffffff


## Recomputes stats after modules change, keeping current hull/battery
## proportional gains (new max hull from a module is granted immediately).
func rebuild_stats(upgrades: Dictionary) -> void:
	var old_max_hull := stats.max_hull if stats else 0.0
	var old_max_battery := stats.max_battery if stats else 0.0
	var old_torpedo_cap := stats.torpedo_capacity if stats else 0
	var old_flare_cap := stats.flare_capacity if stats else 0
	stats = SubStats.build(frame_id, upgrades, modules)
	if old_max_hull > 0.0:
		hull += maxf(stats.max_hull - old_max_hull, 0.0)
		battery += maxf(stats.max_battery - old_max_battery, 0.0)
		torpedoes += maxi(stats.torpedo_capacity - old_torpedo_cap, 0)
		flares += maxi(stats.flare_capacity - old_flare_cap, 0)
	hull = minf(hull, stats.max_hull)
	battery = minf(battery, stats.max_battery)


func refill() -> void:
	hull = stats.max_hull
	battery = stats.max_battery
	torpedoes = stats.torpedo_capacity
	flares = stats.flare_capacity


func add_module(id: StringName, upgrades: Dictionary) -> void:
	modules.append(id)
	rebuild_stats(upgrades)
