extends TestCase
## TerrainField sampling, normals, casting and collision resolution.


## A 40 x 40 m field with a round room of radius 10 at (20, -20).
func _room() -> TerrainField:
	var f := TerrainField.new(81, 81, 0.5)
	for y in 81:
		for x in 81:
			var p := Vector2(x * 0.5, -y * 0.5)
			f.data[y * 81 + x] = 10.0 - p.distance_to(Vector2(20, -20))
	return f


func test_sample_matches_analytic_distance() -> void:
	var f := _room()
	check_near(f.sample(Vector2(20, -20)), 10.0, 0.01)
	check_near(f.sample(Vector2(25.25, -20)), 4.75, 0.05)
	check(f.sample(Vector2(-5, -5)) < 0.0, "outside the grid is rock")


func test_normal_points_into_water() -> void:
	var f := _room()
	var n := f.normal(Vector2(29, -20))
	check(n.dot(Vector2.LEFT) > 0.95, "normal near the east wall points west, got %s" % n)


func test_cast_hits_wall() -> void:
	var f := _room()
	var t := f.cast(Vector2(20, -20), Vector2(40, -20), 0.0)
	check_near(20.0 + t * 20.0, 30.0, 0.2, "ray should stop at the wall")
	check_eq(f.cast(Vector2(18, -20), Vector2(22, -20)), 1.0, "short ray inside the room is clear")


func test_resolve_circle_pushes_out() -> void:
	var f := _room()
	var p := f.resolve_circle(Vector2(29.5, -20), 1.0)
	check(f.sample(p) >= 0.99, "circle should be pushed to clearance, got %f" % f.sample(p))


func test_line_of_sight() -> void:
	var f := _room()
	check(f.line_of_sight(Vector2(15, -20), Vector2(25, -20)))
	check(not f.line_of_sight(Vector2(15, -20), Vector2(39, -39)))
