class_name RunState
extends RefCounted
## State of the dive in progress. Lives in [member Game.run] while diving.

enum Outcome { NONE, SURFACED, IMPLODED, VICTORY }

var run_seed := 0
var frame_id: StringName = &"lantern"
var zone := 0
## The zone the dive began in (always the first).
var start_zone := 0
var modules: Array[StringName] = []
var stats: SubStats
var hull := 100.0
var battery := 100.0
var torpedoes := 0
var flares := 0
var decoys := 0
var salvage := 0
var research := 0
var kills := 0
## Harpoon hits on creatures that had not noticed the sub.
var ambushes := 0
var scans := 0
## Each species scanned on this dive (for [Challenges]).
var species_scanned: Array[StringName] = []
var logs := 0
var bulbs := 0
## Hull damage taken on this dive, and in the zone in progress.
var damage_taken := 0.0
var zone_damage := 0.0
## Zones cleared without taking any hull damage.
var clean_zones := 0
## Ids of the [Challenges] won on this dive.
var challenges_won: Array[String] = []
## [Wonders] witnessed for the first time on this dive.
var wonders: Array[String] = []
var time := 0.0
var pressure := 0
var daily := false
## The contract taken for this dive (see [Contracts]), or &"".
var contract: StringName = &""
## The daily dive's condition of the day (see [method ZoneEvents.for_zone]).
var daily_event: StringName = &""
var deepest_depth := 0
## What last damaged the hull (see [method DeathTips.cause_of]).
var last_hit_by: StringName = &""
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
	var old_decoy_cap := stats.decoy_capacity if stats else 0
	stats = SubStats.build(frame_id, upgrades, modules, contract)
	if old_max_hull > 0.0:
		hull += maxf(stats.max_hull - old_max_hull, 0.0)
		battery += maxf(stats.max_battery - old_max_battery, 0.0)
		torpedoes += maxi(stats.torpedo_capacity - old_torpedo_cap, 0)
		flares += maxi(stats.flare_capacity - old_flare_cap, 0)
		decoys += maxi(stats.decoy_capacity - old_decoy_cap, 0)
	hull = minf(hull, stats.max_hull)
	battery = minf(battery, stats.max_battery)


## Metres descended this dive: depth below where it started.
func descent() -> int:
	return maxi(deepest_depth - int(BiomeLibrary.zone_depth_range(start_zone).x), 0) if start_zone > 0 \
		else deepest_depth


func refill() -> void:
	hull = stats.max_hull
	battery = stats.max_battery
	torpedoes = stats.torpedo_capacity
	flares = stats.flare_capacity
	decoys = stats.decoy_capacity


func add_module(id: StringName, upgrades: Dictionary) -> void:
	modules.append(id)
	rebuild_stats(upgrades)


## Snapshot for resuming an interrupted dive (stats are rebuilt on load).
## Whether the sub was lost to an empty battery (it sank whole).
func lost_power() -> bool:
	return last_hit_by == &"power"


func to_dict() -> Dictionary:
	return {
		"run_seed": run_seed, "frame_id": frame_id, "zone": zone, "start_zone": start_zone, "modules": modules,
		"hull": hull, "battery": battery, "torpedoes": torpedoes, "flares": flares, "decoys": decoys,
		"salvage": salvage, "research": research, "kills": kills, "ambushes": ambushes, "scans": scans, "logs": logs,
		"time": time, "pressure": pressure, "daily": daily, "daily_event": daily_event, "contract": contract,
		"deepest_depth": deepest_depth, "last_hit_by": last_hit_by, "wonders": wonders,
		"species_scanned": species_scanned, "bulbs": bulbs, "damage_taken": damage_taken,
		"clean_zones": clean_zones, "challenges_won": challenges_won,
	}


static func from_dict(d: Dictionary, upgrades: Dictionary) -> RunState:
	var r := RunState.new()
	r.run_seed = int(d.get("run_seed", 0))
	r.frame_id = StringName(d.get("frame_id", "lantern"))
	if Catalog.frame(r.frame_id) == null:
		r.frame_id = &"lantern"
	r.zone = clampi(int(d.get("zone", 0)), 0, BiomeLibrary.TOTAL_ZONES - 1)
	r.start_zone = clampi(int(d.get("start_zone", 0)), 0, r.zone)
	r.contract = StringName(d.get("contract", ""))
	if Contracts.find(r.contract) == null:
		r.contract = &""
	for m in d.get("modules", []):
		if Catalog.module(StringName(m)) != null:
			r.modules.append(StringName(m))
	r.rebuild_stats(upgrades)
	r.hull = clampf(float(d.get("hull", r.stats.max_hull)), 1.0, r.stats.max_hull)
	r.battery = clampf(float(d.get("battery", r.stats.max_battery)), 0.0, r.stats.max_battery)
	r.torpedoes = clampi(int(d.get("torpedoes", 0)), 0, r.stats.torpedo_capacity)
	r.flares = clampi(int(d.get("flares", 0)), 0, r.stats.flare_capacity)
	r.decoys = clampi(int(d.get("decoys", 0)), 0, r.stats.decoy_capacity)
	r.salvage = int(d.get("salvage", 0))
	r.research = int(d.get("research", 0))
	r.kills = int(d.get("kills", 0))
	r.ambushes = int(d.get("ambushes", 0))
	r.scans = int(d.get("scans", 0))
	r.logs = int(d.get("logs", 0))
	for w in d.get("wonders", []):
		r.wonders.append(String(w))
	for id in d.get("species_scanned", []):
		r.species_scanned.append(StringName(id))
	r.bulbs = int(d.get("bulbs", 0))
	r.damage_taken = float(d.get("damage_taken", 0.0))
	r.clean_zones = int(d.get("clean_zones", 0))
	for id in d.get("challenges_won", []):
		r.challenges_won.append(String(id))
	r.time = float(d.get("time", 0.0))
	r.pressure = int(d.get("pressure", 0))
	r.daily = bool(d.get("daily", false))
	r.daily_event = StringName(d.get("daily_event", ""))
	r.deepest_depth = int(d.get("deepest_depth", 0))
	r.last_hit_by = StringName(d.get("last_hit_by", ""))
	return r
