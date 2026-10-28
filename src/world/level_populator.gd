class_name LevelPopulator
extends RefCounted
## Fills a generated zone with creatures, glow bulbs, caches, salvage debris,
## signal logs and decorative props, following the biome's tables.

## Species id -> script. Wall dwellers are placed on anchors, others in water.
const SPECIES: Dictionary[StringName, Script] = {
	&"shoal": preload("res://src/creatures/shoal.gd"),
	&"jelly": preload("res://src/creatures/jelly.gd"),
	&"lancer": preload("res://src/creatures/lancer.gd"),
	&"lurelight": preload("res://src/creatures/lurelight.gd"),
	&"gulper": preload("res://src/creatures/gulper.gd"),
	&"stalker": preload("res://src/creatures/stalker.gd"),
	&"isopod": preload("res://src/creatures/isopod.gd"),
	&"siphon": preload("res://src/creatures/siphonophore.gd"),
}
const WALL_DWELLERS: Array[StringName] = [&"gulper", &"lurelight", &"isopod"]
## Spawn cost of each species against the biome's creature budget.
const COST: Dictionary[StringName, float] = {
	&"shoal": 0.6, &"jelly": 0.8, &"lancer": 1.0, &"lurelight": 1.5,
	&"gulper": 1.4, &"stalker": 4.0, &"isopod": 0.7, &"siphon": 1.6,
}
const SAFE_RADIUS := 26.0


static func populate(level: Level, run: RunState) -> void:
	var layout := level.layout
	var rng := level.rng
	var used := PackedVector2Array([layout.start])
	if not layout.has_exit:
		_spawn_boss(level, used)
	_spawn_creatures(level, run, used)
	_spawn_bulbs(level, used)
	_spawn_vents(level, used)
	_spawn_caches(level, used)
	_spawn_debris(level)
	PropScatter.scatter(level)
	if rng.randf() < 0.8:
		_spawn_log(level, used)


static func _spawn_creatures(level: Level, run: RunState, used: PackedVector2Array) -> void:
	var biome := level.biome
	var rng := level.rng
	var budget := biome.creature_budget * Pressure.creature_budget(run.pressure)
	# The very first zone eases players in; the arena keeps the focus on the Choir.
	if level.zone == 0:
		budget *= 0.7
	if not level.layout.has_exit:
		budget *= 0.35
	if level.event == &"frenzy":
		budget *= 1.6
	var ids: Array[StringName] = []
	var weights := PackedFloat32Array()
	for id in biome.creatures:
		if SPECIES.has(id):
			ids.append(id)
			weights.append(biome.creatures[id])
	if ids.is_empty():
		return
	var stalkers := 0
	var guard := 0
	while budget > 0.0 and guard < 80:
		guard += 1
		var id := ids[rng.rand_weighted(weights)]
		if id == &"stalker":
			if stalkers >= 1 or not level.layout.has_exit:
				continue
			stalkers += 1
		var p := _creature_spot(level, id, used)
		if p.is_empty():
			continue
		var c: Creature = SPECIES[id].new()
		c.pos = p.pos
		if p.has("normal"):
			c.set(&"wall_normal", p.normal)
		level.add_entity(c)
		used.append(c.pos)
		budget -= COST.get(id, 1.0)


## Picks a spawn spot: wall anchors for wall dwellers, open water otherwise.
static func _creature_spot(level: Level, id: StringName, used: PackedVector2Array) -> Dictionary:
	var layout := level.layout
	var rng := level.rng
	if WALL_DWELLERS.has(id):
		for _i in 30:
			var a: LevelLayout.Anchor = layout.anchors[rng.randi() % layout.anchors.size()]
			if a.pos.distance_to(layout.start) < SAFE_RADIUS or a.pos.distance_to(layout.exit) < 10.0:
				continue
			if not _far_from(a.pos, used, 7.0):
				continue
			return {"pos": a.pos + a.normal * 0.6, "normal": a.normal}
		return {}
	var clearance := 5.0 if id == &"stalker" or id == &"siphon" else 2.5
	var spot := layout.random_open_point(rng, clearance, PackedVector2Array([layout.start]), SAFE_RADIUS)
	if spot == Vector2.INF or not _far_from(spot, used, 5.0):
		return {}
	return {"pos": spot}


static func _spawn_boss(level: Level, used: PackedVector2Array) -> void:
	var arena: LevelLayout.Chamber = level.layout.chambers_of_kind(&"arena")[0]
	var boss := ChoirBoss.new()
	boss.center = arena.center
	boss.arena_radius = arena.radius.x
	level.boss = boss
	level.add_entity(boss)
	# Keep ordinary spawns out of the arena.
	for i in 16:
		var a := TAU * i / 16.0
		used.append(arena.center + Vector2(cos(a) * arena.radius.x, sin(a) * arena.radius.y) * 0.6)
	used.append(arena.center)


static func _spawn_bulbs(level: Level, used: PackedVector2Array) -> void:
	var layout := level.layout
	var rng := level.rng
	var placed := 0
	var guard := 0
	var target := level.biome.bulb_count + (4 if level.event == &"blackout" or level.event == &"bloom" else 0)
	while placed < target and guard < 300 and not layout.anchors.is_empty():
		guard += 1
		var a: LevelLayout.Anchor = layout.anchors[rng.randi() % layout.anchors.size()]
		if not _far_from(a.pos, used, 14.0):
			continue
		var bulb := GlowBulb.new()
		bulb.pos = a.pos + a.normal * 0.5
		bulb.normal = a.normal
		bulb.color = level.biome.glow_color
		level.add_entity(bulb)
		used.append(bulb.pos)
		placed += 1


## Thermal vents on open floor, spaced apart and clear of the entry and exit.
static func _spawn_vents(level: Level, used: PackedVector2Array) -> void:
	var layout := level.layout
	var rng := level.rng
	var placed: Array[Vector2] = []
	var guard := 0
	while placed.size() < level.biome.vent_count and guard < 400 and not layout.anchors.is_empty():
		guard += 1
		var a: LevelLayout.Anchor = layout.anchors[rng.randi() % layout.anchors.size()]
		if a.normal.y < 0.75 or a.pos.distance_to(layout.start) < 25.0 or a.pos.distance_to(layout.exit) < 18.0:
			continue
		if not layout.is_reachable(a.pos + a.normal * 3.0) or not _far_from(a.pos, used, 8.0):
			continue
		if placed.any(func(q: Vector2) -> bool: return q.distance_to(a.pos) < 25.0):
			continue
		var vent := ThermalVent.new()
		vent.pos = a.pos + a.normal * 0.3
		vent.normal = a.normal
		level.add_entity(vent)
		placed.append(a.pos)
		used.append(vent.pos)


static func _spawn_caches(level: Level, used: PackedVector2Array) -> void:
	var layout := level.layout
	var rng := level.rng
	var depth_scale := 1.0 + level.zone * 0.35
	var rooms := layout.chambers_of_kind(&"loot")
	for room in rooms:
		var cache := SalvageCache.new()
		cache.pos = layout.point_in_chamber(rng, room, 2.0)
		cache.salvage = int(rng.randi_range(10, 16) * depth_scale)
		cache.rich = rng.randf() < 0.35
		level.add_entity(cache)
		used.append(cache.pos)
	# A wreck field spills its salvage around the hulls.
	if level.event == &"wrecks":
		for spot in Wrecks.scatter(level, rng, used):
			for k in 2:
				var p := spot + Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(0.0, 3.0))
				if layout.field.sample(p) >= 1.6 and layout.is_reachable(p):
					var wreck_cache := SalvageCache.new()
					wreck_cache.pos = p
					wreck_cache.salvage = int(rng.randi_range(8, 13) * depth_scale)
					level.add_entity(wreck_cache)
					used.append(p)
	# A couple more in the open so every route pays something. Below the
	# reef, some of them are not caches at all.
	for _i in (4 if level.event == &"wrecks" else 2):
		var p := layout.random_open_point(rng, 2.0, used, 12.0)
		if p == Vector2.INF:
			continue
		if level.zone >= 4 and rng.randf() < 0.35:
			var mimic := Mimic.new()
			mimic.pos = p
			level.add_entity(mimic)
			used.append(p)
			continue
		var cache := SalvageCache.new()
		cache.pos = p
		cache.salvage = int(rng.randi_range(6, 10) * depth_scale)
		level.add_entity(cache)
		used.append(p)


## Loose salvage along the main path and in side rooms.
static func _spawn_debris(level: Level) -> void:
	var layout := level.layout
	var rng := level.rng
	var count := (10 + level.zone) * (2 if level.event == &"wrecks" else 1)
	for _i in count:
		var p: Vector2
		if rng.randf() < 0.6 and layout.main_path.size() > 0:
			p = layout.main_path[rng.randi() % layout.main_path.size()] + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
		else:
			p = layout.random_open_point(rng, 1.5)
		if p == Vector2.INF or level.field.sample(p) < 1.0:
			continue
		var piece := Pickup.new()
		piece.kind = &"salvage"
		piece.amount = rng.randi_range(1, 3) + int(level.zone / 3.0)
		piece.pos = p
		level.add_entity(piece)


static func _spawn_log(level: Level, used: PackedVector2Array) -> void:
	var id := SignalLogs.next_unfound(Game.meta.logs_found, level.zone)
	if id == &"":
		return
	var layout := level.layout
	var rooms := layout.chambers_of_kind(&"loot")
	var p: Vector2
	if rooms.is_empty():
		p = layout.random_open_point(level.rng, 2.0, used, 10.0)
	else:
		p = layout.point_in_chamber(level.rng, rooms[level.rng.randi() % rooms.size()], 2.0)
	if p == Vector2.INF:
		return
	var beacon := LogBeacon.new()
	beacon.pos = p
	beacon.log_id = id
	level.add_entity(beacon)
	used.append(p)


static func _far_from(p: Vector2, others: PackedVector2Array, dist: float) -> bool:
	for o in others:
		if o.distance_squared_to(p) < dist * dist:
			return false
	return true
