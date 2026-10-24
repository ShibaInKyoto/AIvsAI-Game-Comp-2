class_name LevelLayout
extends RefCounted
## Output of [LevelGenerator]: the terrain field plus every point of interest
## the level needs to populate a zone.

## A carved room. [member kind] is one of &"spawn", &"main", &"loot", &"exit".
class Chamber:
	var center: Vector2
	var radius: Vector2
	var kind: StringName

	func _init(c: Vector2, r: Vector2, k: StringName) -> void:
		center = c
		radius = r
		kind = k


## A point on a reachable rock surface with its outward normal.
class Anchor:
	var pos: Vector2
	var normal: Vector2

	func _init(p: Vector2, n: Vector2) -> void:
		pos = p
		normal = n


var biome: BiomeDef
var zone := 0
var zone_seed := 0
var field: TerrainField
## One byte per field sample; 1 where the submarine can travel from the start.
var reachable: PackedByteArray
var start := Vector2.ZERO
var exit := Vector2.ZERO
var main_path := PackedVector2Array()
var chambers: Array[Chamber] = []
var anchors: Array[Anchor] = []


func size() -> Vector2:
	return field.world_size()


func is_reachable(p: Vector2) -> bool:
	var ix := roundi(p.x / field.cell)
	var iy := roundi(-p.y / field.cell)
	if ix < 0 or iy < 0 or ix >= field.width or iy >= field.height:
		return false
	return reachable[iy * field.width + ix] == 1


## Returns a random reachable point with at least [param clearance] meters of
## open water around it, at least [param min_dist] from every point in
## [param avoid]. Returns [code]Vector2.INF[/code] if none was found.
func random_open_point(rng: RandomNumberGenerator, clearance: float,
		avoid: PackedVector2Array = PackedVector2Array(), min_dist := 0.0) -> Vector2:
	var s := size()
	for _i in 80:
		var p := Vector2(rng.randf_range(4.0, s.x - 4.0), -rng.randf_range(4.0, s.y - 4.0))
		if field.sample(p) < clearance or not is_reachable(p):
			continue
		var ok := true
		for a in avoid:
			if a.distance_squared_to(p) < min_dist * min_dist:
				ok = false
				break
		if ok:
			return p
	return Vector2.INF


## Random point inside a chamber that is in open water.
func point_in_chamber(rng: RandomNumberGenerator, c: Chamber, clearance: float) -> Vector2:
	for _i in 30:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.8
		var p := c.center + Vector2(cos(a) * c.radius.x, sin(a) * c.radius.y) * r
		if field.sample(p) >= clearance and is_reachable(p):
			return p
	return c.center


func chambers_of_kind(kind: StringName) -> Array[Chamber]:
	var out: Array[Chamber] = []
	for c in chambers:
		if c.kind == kind:
			out.append(c)
	return out
