class_name MenuBackdrop
extends Node3D
## Live 3D scene behind the menus: a real generated zone with the submarine
## idling in its entry chamber, a slowly drifting camera and periodic pings.

var level: Level
var sub: Submarine
var camera: Camera3D
var _t := 0.0
var _ping_timer := 2.0
var _anchor := Vector2.ZERO
var _run: RunState
## Horizontal camera offset; negative values push the submarine to the right
## of the screen to leave room for menus on the left.
var view_shift := -5.0
## Zone to show; -1 picks the deepest biome the player has reached.
var force_zone := -1


func _ready() -> void:
	var zone := clampi(Game.meta.deepest_zone, 0, BiomeLibrary.BIOME_COUNT * BiomeLibrary.ZONES_PER_BIOME - 1)
	# Show the deepest biome reached so far; the backdrop evolves with progress.
	zone = zone - zone % BiomeLibrary.ZONES_PER_BIOME
	if force_zone >= 0:
		zone = force_zone
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), 777 + zone, zone)
	level = Level.new()
	add_child(level)
	level.build(layout, Settings.quality)
	PropScatter.scatter(level)
	_run = RunState.new()
	_run.frame_id = StringName(Game.meta.selected_frame)
	_run.rebuild_stats(Game.meta.upgrades)
	_run.refill()
	sub = Submarine.new()
	level.add_child(sub)
	_anchor = _pick_spot(layout)
	sub.setup(level, _run, _anchor)
	sub.input_enabled = false
	sub.external_move = Vector2.ZERO
	level.player = sub
	# A shoal for life.
	var shoal := Shoal.new()
	shoal.pos = _anchor + Vector2(8, 3)
	level.add_entity(shoal)
	camera = Camera3D.new()
	camera.fov = 40.0
	camera.far = 140.0
	add_child(camera)
	camera.current = true
	camera.position = Vector3(_anchor.x + view_shift, _anchor.y + 1.5, 17.0)
	var water := WaterFx.new()
	level.add_child(water)
	water.setup(layout.biome, layout.size(), camera, Settings.quality)


func _pick_spot(layout: LevelLayout) -> Vector2:
	for c in layout.chambers:
		if c.kind == &"main" and c.radius.x > 12.0:
			return c.center
	return layout.start + Vector2(0, -4)


## Swaps the sub's paint when the selected frame changes in the hangar.
func refresh_sub() -> void:
	if sub == null:
		return
	var frame := Catalog.frame(StringName(Game.meta.selected_frame))
	if frame and sub.model:
		sub.model.hull_material.albedo_color = frame.hull_color


func _process(frame_delta: float) -> void:
	var delta := minf(frame_delta, 1.0 / 20.0)
	_t += delta
	var drift := Vector2(sin(_t * 0.23) * 3.0, sin(_t * 0.31) * 1.5)
	sub.external_move = ((_anchor + drift) - sub.pos).limit_length(1.0) * 0.25
	sub.aim = Vector2(cos(_t * 0.4) * 0.8 + 0.4, sin(_t * 0.27) * 0.5 - 0.2).normalized()
	sub.facing = 1.0 if sub.aim.x > 0.0 else -1.0
	_run.battery = _run.stats.max_battery
	_ping_timer -= delta
	if _ping_timer <= 0.0:
		_ping_timer = 7.0
		level.ping(sub.pos, 60.0, 3.0)
		Audio.play(&"sonar_ping", -12.0)
	sub.tick(delta)
	level.tick(delta)
	var target := Vector3(sub.pos.x + view_shift + sin(_t * 0.1) * 1.5, sub.pos.y + 1.5, 17.0 + sin(_t * 0.13) * 1.5)
	camera.position = camera.position.lerp(target, 1.0 - exp(-0.8 * delta))
	camera.look_at(Vector3(sub.pos.x + view_shift * 0.55, sub.pos.y, 0.0))
