class_name Challenges
extends RefCounted
## Goals to chase, won once each. Every challenge pays a livery (see
## [SubSkins]): the first ones a paint for any submarine, the harder ones a
## skin made for one frame, earned by doing something difficult in it.
## Career challenges count across every dive; dive challenges must be done
## within a single dive. Up to [constant MAX_TRACKED] can be tracked from the
## hangar, and the HUD keeps their progress in view while diving.

const MAX_TRACKED := 3

class Challenge:
	var id: String
	var name: String
	var description: String
	var target := 1
	## Progress counts within one dive, and starts over on the next.
	var per_dive := false
	## The frame a dive challenge must be done in (&"" for any).
	var frame: StringName = &""
	## (meta: MetaState, run: RunState) -> int; the run may be null.
	var measure: Callable

	## The livery it wins (which shares its id).
	func reward() -> SubSkins.Livery:
		return SubSkins.find(id)

static var _all: Array[Challenge] = []


static func all() -> Array[Challenge]:
	if _all.is_empty():
		_all = [
			_career("first_descent", "First Descent", "Clear the first zone of a dive.", 1,
				func(m: MetaState, r: RunState) -> int: return int(_depth_zone(m, r) >= 1)),
			_career("twilight", "Into the Twilight", "Reach the Twilight Reef.", 1,
				func(m: MetaState, r: RunState) -> int: return int(_depth_zone(m, r) >= 2)),
			_career("midnight", "Midnight", "Reach the Midnight Caverns.", 1,
				func(m: MetaState, r: RunState) -> int: return int(_depth_zone(m, r) >= 4)),
			_career("vents", "Into the Fire", "Reach the Abyssal Vents.", 1,
				func(m: MetaState, r: RunState) -> int: return int(_depth_zone(m, r) >= 6)),
			_career("hadal", "Hadal", "Reach the Hadal Trench.", 1,
				func(m: MetaState, r: RunState) -> int: return int(_depth_zone(m, r) >= 8)),
			_career("answer", "The Answer", "Silence the Choir.", 1,
				func(m: MetaState, _r: RunState) -> int: return m.wins),
			_career("naturalist", "Naturalist", "Scan 5 different species.", 5,
				func(m: MetaState, _r: RunState) -> int: return m.codex.size()),
			_career("codex", "Codex Complete", "Scan every species in the trench.", CreatureCodex.entries().size(),
				func(m: MetaState, _r: RunState) -> int: return m.codex.size()),
			_career("archivist", "Archivist", "Recover every signal log.", SignalLogs.count(),
				func(m: MetaState, _r: RunState) -> int: return SignalLogs.found_count(m.logs_found)),
			_career("lights_out", "Lights Out", "Put out the Lamplighter.", 1,
				func(m: MetaState, _r: RunState) -> int: return m.anglers_killed),
			_career("lullaby", "Lullaby", "Silence the Blind Mother.", 1,
				func(m: MetaState, _r: RunState) -> int: return m.mothers_killed),
			_career("hunter", "Apex", "Kill a Stalker.", 1,
				func(m: MetaState, _r: RunState) -> int: return m.stalkers_killed),
			_career("hoarder", "Hoarder", "Bank 1,000 salvage in total.", 1000,
				func(m: MetaState, _r: RunState) -> int: return m.total_salvage),
			_career("fleet", "Fleet", "Unlock every submarine.", Catalog.frames().size(),
				func(m: MetaState, _r: RunState) -> int: return m.unlocked_frames.size()),
			_career("pressure", "Crush Depth", "Silence the Choir at Pressure 3 or higher.", 1,
				func(m: MetaState, _r: RunState) -> int: return int(m.best_pressure_win >= 3)),
			_career("veteran", "Veteran", "Complete 15 dives.", 15,
				func(m: MetaState, _r: RunState) -> int: return m.dives),
			_dive("ambusher", "Silent Hunter", "Land 8 ambushes in a single dive.", &"", 8,
				func(_m: MetaState, r: RunState) -> int: return r.ambushes),
			# The harder ones, each done in one particular submarine.
			_dive("lantern_survey", "Field Survey", "In the Lantern, scan 6 different species in one dive.",
				&"lantern", 6, func(_m: MetaState, r: RunState) -> int: return r.species_scanned.size()),
			_dive("lantern_biolume", "Glow Harvest", "In the Lantern, harvest 12 glow bulbs in one dive.",
				&"lantern", 12, func(_m: MetaState, r: RunState) -> int: return r.bulbs),
			_career("lantern_brass", "Old Faithful", "Silence the Choir in the Lantern.", 1,
				func(m: MetaState, _r: RunState) -> int: return int(m.frame_wins.get("lantern", 0))),
			_dive("mako_tiger", "Blood in the Water", "In the Mako, kill 25 creatures in one dive.",
				&"mako", 25, func(_m: MetaState, r: RunState) -> int: return r.kills),
			_dive("mako_racer", "Lap Record",
				"In the Mako, reach the Midnight Caverns within 6 minutes of leaving the surface.", &"mako", 1,
				func(_m: MetaState, r: RunState) -> int: return int(r.zone >= 4 and r.time <= 360.0)),
			_career("mako_carbon", "Torpedo Run", "Silence the Choir in the Mako.", 1,
				func(m: MetaState, _r: RunState) -> int: return int(m.frame_wins.get("mako", 0))),
			_dive("bathysphere_rust", "Punching Bag", "In the Bathysphere, take 250 hull damage in one dive.",
				&"bathysphere", 250, func(_m: MetaState, r: RunState) -> int: return int(r.damage_taken)),
			_dive("bathysphere_hazard", "Pressure Test", "In the Bathysphere, reach the Hadal Trench at Pressure 1 " +
				"or higher.", &"bathysphere", 1,
				func(_m: MetaState, r: RunState) -> int: return int(r.zone >= 8 and r.pressure >= 1)),
			_career("bathysphere_chrome", "Deep Chrome", "Silence the Choir in the Bathysphere.", 1,
				func(m: MetaState, _r: RunState) -> int: return int(m.frame_wins.get("bathysphere", 0))),
			_dive("whisper_camo", "Unseen", "In the Whisper, land 12 ambushes in one dive.", &"whisper", 12,
				func(_m: MetaState, r: RunState) -> int: return r.ambushes),
			_dive("whisper_ghost", "Ghost Run", "In the Whisper, clear 3 zones in one dive without a scratch on " +
				"the hull.", &"whisper", 3, func(_m: MetaState, r: RunState) -> int: return r.clean_zones),
			_career("whisper_stars", "Silent Answer", "Silence the Choir in the Whisper.", 1,
				func(m: MetaState, _r: RunState) -> int: return int(m.frame_wins.get("whisper", 0))),
		]
	return _all


static func find(id: String) -> Challenge:
	for c in all():
		if c.id == id:
			return c
	return null


## How far along [param c] is, from 0 to its target. A dive challenge counts
## only the dive in progress, and only in its frame.
static func progress(c: Challenge, meta: MetaState, run: RunState) -> int:
	if c.per_dive:
		if run == null or c.frame != &"" and run.frame_id != c.frame:
			return 0
	return clampi(c.measure.call(meta, run), 0, c.target)


## Short progress text for the HUD and the hangar ("3 / 8", or "done").
static func progress_text(c: Challenge, meta: MetaState, run: RunState) -> String:
	if meta.challenges_won.has(c.id):
		return "done"
	if c.target == 1:
		return "not yet"
	return "%s / %s" % [UiUtil.thousands(progress(c, meta, run)), UiUtil.thousands(c.target)]


## What winning [param c] unlocks ("Kelp paint", "Carbon skin for the Mako").
static func reward_text(c: Challenge) -> String:
	var reward := c.reward()
	if reward.is_paint():
		return "%s paint" % reward.name
	return "%s skin for the %s" % [reward.name, Catalog.frame(reward.frame).name]


## Marks newly completed challenges won. Returns them.
static func check(meta: MetaState, run: RunState) -> Array[Challenge]:
	var fresh: Array[Challenge] = []
	for c in all():
		if c.per_dive and run != null:
			meta.challenge_best[c.id] = maxi(int(meta.challenge_best.get(c.id, 0)), progress(c, meta, run))
		if not meta.challenges_won.has(c.id) and progress(c, meta, run) >= c.target:
			meta.challenges_won.append(c.id)
			if run:
				run.challenges_won.append(c.id)
			fresh.append(c)
	return fresh


## Whether the livery [param skin_id] has been won.
static func has_livery(meta: MetaState, skin_id: String) -> bool:
	return skin_id == "" or meta.challenges_won.has(skin_id)


static func _career(id: String, name: String, desc: String, target: int, measure: Callable) -> Challenge:
	var c := Challenge.new()
	c.id = id
	c.name = name
	c.description = desc
	c.target = target
	c.measure = measure
	return c


static func _dive(id: String, name: String, desc: String, frame: StringName, target: int,
		measure: Callable) -> Challenge:
	var c := _career(id, name, desc, target, measure)
	c.per_dive = true
	c.frame = frame
	return c


static func _depth_zone(m: MetaState, r: RunState) -> int:
	return maxi(m.deepest_zone, r.zone if r else 0)
