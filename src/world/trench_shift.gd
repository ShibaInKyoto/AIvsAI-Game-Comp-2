class_name TrenchShift
extends Entity
## The Hadal Trench above the hadal floor is still being composed. Twice a
## zone, as the sub presses on down the main tunnel, the Choir sings and the
## rock moves: a stretch of tunnel well behind the sub flows shut, and a
## smooth new chamber opens off the tunnel ahead with a cache waiting in it
## ("There's a new chamber where solid rock was" - log_04).
## A seal never closes on the sub and never buries anything placed in the
## zone, and the sub always keeps a way to the exit: if it doubles back into
## a closing seal the rock waits for it, and if it would end up cut off, the
## rock opens again.

## Progress along the main path (0 = entrance, 1 = exit) at which the Choir sings.
const TRIGGERS: Array[float] = [0.3, 0.62]
## The song comes first; the rock starts moving this long after.
const LEAD_IN := 1.2
const MORPH_TIME := 6.0
## Seconds between uploads of the moving rock to the renderer.
const STEP := 0.1
## How far behind the sub, along the main path, a seal may close.
const SEAL_BEHIND: Array[float] = [18.0, 24.0, 30.0, 38.0, 46.0, 54.0, 62.0]
const SEAL_LENGTH := 6.0
## How far ahead, along the main path, a chamber may open.
const OPEN_AHEAD: Array[float] = [16.0, 20.0, 24.0, 28.0, 32.0, 36.0, 40.0, 46.0, 52.0, 58.0]
## Chamber sizes to try, roomiest first, where the rock is thick enough.
const POCKET_SIZES: Array[float] = [4.5, 3.6]
const POCKET_RADIUS := 4.5
const NECK_RADIUS := 2.4
## Water kept between the sub's hull and a closing seal.
const SUB_MARGIN := 2.0
## Beyond this far from the new rock surface an edit fades back into the field
## as it was, so the region it touches stays small and seamless.
const TAPER := Vector2(6.0, 9.0)

## Shown once per session, the first time the trench moves.
static var _explained := false

## One piece of moving rock: capsules (a, b, radius) that fill with rock or
## open into water, blended in from the field as it was.
class Morph:
	var fill := true
	var shapes: Array[Array] = []
	var cells: Rect2i
	var bounds: Rect2
	var original: PackedFloat32Array
	var target: PackedFloat32Array
	var progress := 0.0
	## +1 while moving towards [member target], -1 while giving way again.
	var direction := 1.0

	func centre() -> Vector2:
		var c := Vector2.ZERO
		for s in shapes:
			c += (s[0] + s[1]) * 0.5
		return c / shapes.size()

	## Distance from [param p] to the nearest shape's surface once complete.
	func clearance(p: Vector2) -> float:
		var best := INF
		for s in shapes:
			best = minf(best, TrenchShift.segment_distance(p, s[0], s[1]) - s[2])
		return best

	func moving() -> bool:
		return progress < 1.0 if direction > 0.0 else progress > 0.0

var shifts := 0
var _morphs: Array[Morph] = []
var _t := -1.0
var _since_upload := 0.0
var _started := false
## The sub came alongside a closing seal: check its way out once it is shut.
var _sub_was_close := false
var _pocket: Morph
## How strongly the moving rock glows, and where (kept to fade out after).
var _glow := 0.0
var _glow_zones: Array[Vector4] = []


static func segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	return Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p)


func setup() -> void:
	radius = 0.0
	active_radius = 1.0e6


## How far along the main path [param p] is, from 0 (entrance) to 1 (exit).
func progress_of(p: Vector2) -> float:
	var path := level.layout.main_path
	if path.size() < 2:
		return 0.0
	return float(_nearest_index(path, p)) / (path.size() - 1)


## Whether the rock is moving right now.
func active() -> bool:
	return _t >= 0.0


func tick(delta: float) -> void:
	_update_glow(delta)
	var sub := level.player
	if _t < 0.0:
		if shifts < TRIGGERS.size() and sub and sub.alive and progress_of(sub.pos) >= TRIGGERS[shifts]:
			shifts += 1
			_begin(sub)
		return
	_t += delta
	if _t < LEAD_IN:
		return
	if not _started:
		_started = true
		for m in _morphs:
			Audio.play_at(&"rock_flow", m.centre(), 0.0, 0.05)
			Fx.silt(level, m.centre(), 3.0, level.biome.sediment_tint)
	for m in _morphs:
		var rate := delta / MORPH_TIME
		# The rock waits while the sub is in the way of a closing seal.
		if m.fill and m.direction > 0.0 and sub and m.clearance(sub.pos) < Submarine.RADIUS + SUB_MARGIN:
			_sub_was_close = true
			rate = 0.0
		var was := m.progress
		m.progress = clampf(m.progress + rate * m.direction, 0.0, 1.0)
		if m.fill and m.direction > 0.0 and m.progress >= 1.0 and was < 1.0 and _sub_was_close and sub:
			_keep_way_out(m, sub)
	_since_upload += delta
	var still_moving := _morphs.any(func(m: Morph) -> bool: return m.moving())
	if _since_upload >= STEP or not still_moving:
		_since_upload = 0.0
		_upload()
	if not still_moving:
		_finish()


## Plans the seal and the chamber for this song and starts it.
func _begin(sub: Submarine) -> void:
	_morphs.clear()
	var seal := _plan_seal(sub)
	if seal:
		_morphs.append(seal)
	_pocket = _plan_pocket(sub)
	# Each edit blends from the rock as it was, so the two must not overlap.
	if _pocket and seal and _pocket.cells.intersects(seal.cells):
		_pocket = null
	if _pocket:
		_morphs.append(_pocket)
	if _morphs.is_empty():
		return
	_t = 0.0
	_started = false
	_sub_was_close = false
	_since_upload = 0.0
	_glow_zones.clear()
	for m in _morphs:
		var reach := 0.0
		for s in m.shapes:
			reach = maxf(reach, (s[0] as Vector2).distance_to(m.centre()) + s[2])
		var c := m.centre()
		_glow_zones.append(Vector4(c.x, c.y, reach + 3.0, 0.0))
	Audio.play(&"trench_song", -2.0)
	# For the sound cues: the song comes up from far below.
	Audio.sound_at.emit(&"trench_song", sub.pos + Vector2(0.0, -40.0))
	Events.shake_requested.emit(0.3)
	if not _explained:
		_explained = true
		Events.toast.emit("The Choir is singing, and the rock is moving. The tunnel behind you is closing.",
			UiTheme.WARN)
	else:
		Events.toast.emit("The trench is moving.", UiTheme.WARN)


## The rock glows while it moves: in with the song, out once it settles.
func _update_glow(delta: float) -> void:
	var target := 1.0 if _t >= 0.0 else 0.0
	if _glow == target and target == 0.0:
		return
	_glow = move_toward(_glow, target, delta / (LEAD_IN if target > 0.0 else 2.0))
	if level.terrain == null:
		return
	var zones: Array[Vector4] = []
	for z in _glow_zones:
		zones.append(Vector4(z.x, z.y, z.z, _glow))
	level.terrain.set_shift_glow(zones)


## Writes the moving rock into the field, keeps everything that swims out of
## it and shows it.
func _upload() -> void:
	var field := level.field
	for m in _morphs:
		var k := smoothstep(0.0, 1.0, m.progress)
		var values := PackedFloat32Array()
		values.resize(m.original.size())
		for i in values.size():
			values[i] = lerpf(m.original[i], m.target[i], k)
		field.write_cells(m.cells, values)
	for e in level.entities:
		if e is Creature or e is Pickup:
			e.pos = _free_from_rock(e.pos, e.radius)
	if level.player:
		level.player.pos = _free_from_rock(level.player.pos, Submarine.RADIUS)
	if level.terrain:
		level.terrain.refresh(field)


## [param p], pushed out of any seal it is caught in by a circle of [param r].
func _free_from_rock(p: Vector2, r: float) -> Vector2:
	r = maxf(r, 0.3)
	for m in _morphs:
		if m.fill and m.bounds.has_point(p) and level.field.sample(p) < r:
			p = level.field.resolve_circle(p, r)
	return p


func _finish() -> void:
	for m in _morphs:
		Events.terrain_changed.emit(m.bounds)
		if m.fill and m.direction > 0.0:
			Fx.silt(level, m.centre(), 4.0, level.biome.sediment_tint)
	if _pocket and _pocket.progress >= 1.0:
		_furnish(_pocket)
	_morphs.clear()
	_pocket = null
	_t = -1.0


## The sub squeezed past the seal while it closed: if it is now cut off from
## the exit, the rock gives way again.
func _keep_way_out(m: Morph, sub: Submarine) -> void:
	_upload()
	if level.layout.find_path(sub.pos, level.layout.exit, 1.3).is_empty():
		m.direction = -1.0


## A new chamber has a cache waiting in it, and a glow on its floor.
func _furnish(m: Morph) -> void:
	var c: Vector2 = m.shapes[0][0]
	var cache := SalvageCache.new()
	cache.pos = c
	cache.salvage = int(level.rng.randi_range(14, 20) * (1.0 + level.zone * 0.35))
	cache.rich = true
	level.add_entity(cache)
	var floor_y := MeridianStation.floor_below(level.field, c, POCKET_RADIUS + 1.5)
	if floor_y != -INF and level.field.sample(Vector2(c.x, floor_y + 0.5)) > 0.3:
		var bulb := GlowBulb.new()
		bulb.pos = Vector2(c.x, floor_y + 0.5)
		# World +y is up.
		bulb.normal = Vector2(0.0, 1.0)
		bulb.color = level.biome.glow_color
		level.add_entity(bulb)
	Fx.silt(level, c, 3.0, level.biome.sediment_tint)
	var sub := level.player
	if sub and sub.pos.distance_to(c) < 60.0:
		Events.toast.emit("A new chamber has opened ahead, where there was solid rock.", UiTheme.ACCENT)


## A stretch of the main tunnel well behind the sub that can close without
## burying anything or cutting the sub off from the exit, or null.
func _plan_seal(sub: Submarine) -> Morph:
	var layout := level.layout
	var path := layout.main_path
	var field := level.field
	var at := _nearest_index(path, sub.pos)
	for behind in SEAL_BEHIND:
		var i0 := _walk(path, at, behind, -1)
		var i1 := _walk(path, i0, SEAL_LENGTH, -1) if i0 >= 0 else -1
		if i1 < 0:
			break
		var a := path[i1]
		var b := path[i0]
		# Wall to wall: the tunnel's half-width along the stretch, and a bit.
		var half := maxf(maxf(field.sample(a), field.sample(b)), field.sample((a + b) * 0.5))
		if half < 1.0:
			continue
		var r := half + 1.5
		if segment_distance(sub.pos, a, b) < r + 8.0 or not _nothing_buried(a, b, r):
			continue
		var m := _make_morph([[a, b, r]], true)
		if _leaves_way_out(m, sub, at):
			return m
	return null


## Nothing placed in the zone (caches, logs, bulbs, the drone...) lies inside
## a seal from [param a] to [param b] of radius [param r].
func _nothing_buried(a: Vector2, b: Vector2, r: float) -> bool:
	for e in level.entities:
		if e == self or e is Creature or e is Pickup:
			continue
		var margin := 6.0 if e is VasquezDrone else 2.0
		if segment_distance(e.pos, a, b) < r + e.radius + margin:
			return false
	return true


## Whether the sub can still reach the exit with [param m] shut. The usual
## case is cheap: the sub can see the main path and the path on from there
## keeps clear of the seal. Otherwise the route is searched with it in place.
func _leaves_way_out(m: Morph, sub: Submarine, at: int) -> bool:
	var path := level.layout.main_path
	var field := level.field
	var simple := sub.pos.distance_to(path[at]) < 15.0 and field.line_of_sight(sub.pos, path[at], Submarine.RADIUS) \
		and m.clearance(sub.pos) > 6.0
	if simple:
		for i in range(at, path.size()):
			if m.clearance(path[i]) < Submarine.RADIUS + 1.0:
				simple = false
				break
	if simple:
		return true
	field.write_cells(m.cells, m.target)
	var ok := not level.layout.find_path(sub.pos, level.layout.exit, 1.3).is_empty()
	field.write_cells(m.cells, m.original)
	return ok


## A spot in solid rock beside the main tunnel ahead of the sub where a
## chamber can open, with a neck through to the tunnel, or null.
func _plan_pocket(sub: Submarine) -> Morph:
	var at := _nearest_index(level.layout.main_path, sub.pos)
	for size_r in POCKET_SIZES:
		for ahead in OPEN_AHEAD:
			var m := _pocket_at(sub, at, ahead, size_r)
			if m:
				return m
	return null


## A chamber of radius [param pocket_r] beside the main path [param ahead]
## metres on from index [param at], or null if the rock there will not hold one.
func _pocket_at(sub: Submarine, at: int, ahead: float, pocket_r: float) -> Morph:
	var layout := level.layout
	var path := layout.main_path
	var field := level.field
	var size := layout.size()
	var margin := pocket_r + 3.0
	var i := _walk(path, at, ahead, 1)
	if i < 0:
		return null
	var p := path[i]
	var tangent := (path[mini(i + 2, path.size() - 1)] - path[maxi(i - 2, 0)]).normalized()
	var sides: Array[float] = [1.0, -1.0]
	if i % 2 == 1:
		sides.reverse()
	for side in sides:
		var n := tangent.orthogonal() * side
		var reach := 0.0
		while reach < 14.0 and field.sample(p + n * reach) > 0.3:
			reach += 0.5
		if reach >= 14.0:
			continue
		var wall := p + n * reach
		var c := wall + n * (pocket_r + 1.2)
		if c.x < margin or c.x > size.x - margin or c.y > -margin or c.y < -(size.y - margin):
			continue
		# Solid all round, so the chamber opens only into this tunnel.
		if field.sample(c) > -(pocket_r + 0.8):
			continue
		if c.distance_to(layout.exit) < 15.0 or c.distance_to(sub.pos) < 12.0:
			continue
		var shapes: Array[Array] = [[c, c, pocket_r], [wall - n * 1.0, c, NECK_RADIUS]]
		var lobe := c + tangent * 2.2 + n * 1.0
		if field.sample(lobe) < -(pocket_r * 0.7 + 0.8):
			shapes.append([lobe, lobe, pocket_r * 0.7])
		return _make_morph(shapes, false)
	return null


func _make_morph(shapes: Array[Array], fill: bool) -> Morph:
	var m := Morph.new()
	m.fill = fill
	m.shapes = shapes
	var bounds := Rect2()
	for k in shapes.size():
		var s: Array = shapes[k]
		var grow: float = s[2] + TAPER.y + 1.0
		var r := Rect2(s[0], Vector2.ZERO).expand(s[1]).grow(grow)
		bounds = r if k == 0 else bounds.merge(r)
	m.bounds = bounds
	var field := level.field
	m.cells = field.cells_in(bounds)
	m.original = field.read_cells(m.cells)
	m.target = m.original.duplicate()
	var i := 0
	for iy in range(m.cells.position.y, m.cells.end.y):
		for ix in range(m.cells.position.x, m.cells.end.x):
			var surface := m.clearance(field.cell_pos(ix, iy))
			var old := m.original[i]
			var moved := minf(old, surface) if fill else maxf(old, -surface)
			m.target[i] = lerpf(moved, old, smoothstep(TAPER.x, TAPER.y, surface))
			i += 1
	return m


static func _nearest_index(path: PackedVector2Array, p: Vector2) -> int:
	var best := 0
	for i in path.size():
		if path[i].distance_squared_to(p) < path[best].distance_squared_to(p):
			best = i
	return best


## The index [param dist] metres along [param path] from [param from], walking
## in [param step] (+1 or -1), or -1 if the path ends first.
static func _walk(path: PackedVector2Array, from: int, dist: float, step: int) -> int:
	var i := from
	var gone := 0.0
	while gone < dist:
		var j := i + step
		if j < 0 or j >= path.size():
			return -1
		gone += path[i].distance_to(path[j])
		i = j
	return i
