class_name ZoneObjective
extends RefCounted
## An optional goal for one zone ("open 3 caches", "kill the Stalker",
## "reach the descent without boosting"...). Rolled from what the zone
## actually contains; completing it pays salvage or research on the spot.

signal completed

var kind: StringName
var target := 1
var progress := 0
var reward_salvage := 0
var reward_research := 0
var done := false
var failed := false

var _level: Level
var _sub: Submarine


## Picks an objective suited to the level, or null for zones without one.
static func roll(level: Level, sub: Submarine, run_seed: int) -> ZoneObjective:
	if level.zone == 0 or not level.layout.has_exit:
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, level.zone, "objective"])
	var options: Array[StringName] = [&"caches", &"hunt", &"scan", &"silent", &"bulbs"]
	var counts := _count(level)
	if counts.get(&"stalker", 0) > 0:
		options.append(&"stalker")
		options.append(&"stalker")
	if counts.get(&"log", 0) > 0:
		options.append(&"log")
	var o := ZoneObjective.new()
	o.kind = options[rng.randi() % options.size()]
	match o.kind:
		&"caches":
			o.target = clampi(counts.get(&"cache", 0) - 1, 1, 3)
		&"hunt":
			o.target = 3 + int(level.zone / 3.0)
		&"scan":
			o.target = 2
		&"bulbs":
			o.target = mini(3, counts.get(&"bulb", 0))
	if rng.randf() < 0.65:
		o.reward_salvage = 20 + level.zone * 8 + (25 if o.kind == &"stalker" else 0)
	else:
		o.reward_research = 8 + level.zone
	o._bind(level, sub)
	return o


static func _count(level: Level) -> Dictionary:
	var c := {}
	for e in level.entities:
		var key: StringName = &""
		if e is SalvageCache:
			key = &"cache"
		elif e is GlowBulb:
			key = &"bulb"
		elif e is LogBeacon:
			key = &"log"
		elif e is Stalker:
			key = &"stalker"
		if key != &"":
			c[key] = c.get(key, 0) + 1
	return c


func _bind(level: Level, sub: Submarine) -> void:
	_level = level
	_sub = sub
	Events.cache_opened.connect(_on_cache)
	Events.bulb_harvested.connect(_on_bulb)
	Events.creature_killed.connect(_on_kill)
	Events.creature_scanned.connect(_on_scan)
	Events.log_found.connect(_on_log)
	level.exit_reached.connect(_on_exit)


## Disconnects from the global signal bus (call when the zone ends).
func release() -> void:
	for pair: Array in [[Events.cache_opened, _on_cache], [Events.bulb_harvested, _on_bulb],
			[Events.creature_killed, _on_kill], [Events.creature_scanned, _on_scan], [Events.log_found, _on_log]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])


func describe() -> String:
	var text := ""
	match kind:
		&"caches":
			text = "Open %d salvage caches" % target
		&"hunt":
			text = "Defeat %d creatures" % target
		&"scan":
			text = "Scan %d species" % target
		&"silent":
			text = "Reach the descent without boosting"
		&"bulbs":
			text = "Harvest %d glow bulbs" % target
		&"stalker":
			text = "Kill the Stalker"
		&"log":
			text = "Recover the signal log"
	if target > 1:
		text += "  (%d/%d)" % [mini(progress, target), target]
	return text


func reward_text() -> String:
	return "+%d salvage" % reward_salvage if reward_salvage > 0 else "+%d research" % reward_research


## Called every frame by the dive; handles objectives that can fail.
func tick() -> void:
	if done or failed:
		return
	if kind == &"silent" and _sub and _sub.boosting:
		failed = true
		Events.toast.emit("Objective failed: you boosted", UiTheme.TEXT_DIM)


func _advance(amount := 1) -> void:
	if done or failed:
		return
	progress += amount
	if progress >= target:
		done = true
		_sub.run.salvage += reward_salvage
		_sub.run.research += reward_research
		Audio.play(&"module_install", -2.0)
		Events.toast.emit("Objective complete  %s" % reward_text(), UiTheme.GOOD)
		completed.emit()


func _on_cache(_p: Vector2) -> void:
	if kind == &"caches":
		_advance()


func _on_bulb(_p: Vector2) -> void:
	if kind == &"bulbs":
		_advance()


func _on_kill(id: StringName, _p: Vector2) -> void:
	if kind == &"hunt" or (kind == &"stalker" and id == &"stalker"):
		_advance()


func _on_scan(_id: StringName, _first: bool) -> void:
	if kind == &"scan":
		_advance()


func _on_log(_id: StringName) -> void:
	if kind == &"log":
		_advance()


func _on_exit() -> void:
	if kind == &"silent":
		_advance()
