class_name SubStats
extends RefCounted
## Every tunable number of the player's submarine. Built from the chosen
## frame, the permanent hangar upgrades and the modules found during a run
## (see [Catalog]), so gameplay code never needs to know where a bonus came from.

var max_hull := 100.0
var max_battery := 100.0
## Acceleration in m/s^2 and top cruising speed in m/s.
var thrust := 26.0
var max_speed := 8.5
var boost_mult := 1.65
var boost_drain := 8.0
## The battery is life support: it drains slowly always, and with thrust.
var life_support_drain := 0.04
var thrust_drain := 0.12
var drag := 1.4
## Multiplier on all noise the submarine makes.
var noise_mult := 1.0

var lamp_range := 28.0
var lamp_angle := 26.0
var lamp_energy := 14.0
var lamp_drain := 0.35

var sonar_range := 70.0
var sonar_cooldown := 2.6
var sonar_cost := 5.0
## How long sonar marks on creatures last, in seconds.
var sonar_mark_time := 3.5
var sonar_stun := false

var harpoon_damage := 22.0
var harpoon_range := 17.0
var harpoon_reel := 14.0
var harpoon_leech := 0.0

var torpedo_capacity := 0
var torpedo_damage := 70.0
var flare_capacity := 0
var decoy_capacity := 0
var shock_cost := 22.0
var shock_radius := 9.0
var shock_damage := 18.0

var pickup_radius := 5.0
var salvage_mult := 1.0
var bulb_mult := 1.0
var regen := 0.0
var contact_zap := 0.0
var ink_cloud := false
var cache_bonus := 0
var always_compass := false
var scan_speed := 1.0
## Fraction of run salvage banked when the sub is lost (none without the
## Salvage Insurance upgrade).
var insurance := 0.0
## Tools available on the secondary slot, in cycle order.
var tools: Array[StringName] = []


func has_tool(tool: StringName) -> bool:
	return tools.has(tool)


func add_tool(tool: StringName) -> void:
	if not tools.has(tool):
		tools.append(tool)


## Builds the stats for a frame with hangar upgrade levels, run modules and
## the dive's contract (see [Contracts]), if any.
static func build(frame_id: StringName, upgrades: Dictionary, modules: Array[StringName],
		contract: StringName = &"") -> SubStats:
	var stats := SubStats.new()
	var frame := Catalog.frame(frame_id)
	if frame:
		frame.apply.call(stats)
	for up in Catalog.upgrades():
		var level: int = upgrades.get(String(up.id), 0)
		if level > 0:
			up.apply.call(stats, level)
	for id in modules:
		var mod := Catalog.module(id)
		if mod:
			mod.apply.call(stats)
	var terms := Contracts.find(contract)
	if terms:
		terms.apply.call(stats)
	stats.max_hull = maxf(stats.max_hull, 20.0)
	return stats
