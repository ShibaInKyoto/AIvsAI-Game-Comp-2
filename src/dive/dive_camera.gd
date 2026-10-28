class_name DiveCamera
extends Camera3D
## Side-on follow camera with aim look-ahead, speed zoom, level clamping and
## trauma-based screen shake.

const BASE_DISTANCE := 29.0

var target: Submarine
var level_size := Vector2(100, 200)
var zoom := 1.0

var _offset := Vector2.ZERO
var _trauma := 0.0
var _distance := BASE_DISTANCE
var _time := 0.0
var _shake_noise := FastNoiseLite.new()


func _ready() -> void:
	fov = 42.0
	near = 0.5
	far = 140.0
	current = true
	_shake_noise.frequency = 2.0
	Events.shake_requested.connect(add_trauma)


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount * Settings.screen_shake, 0.0, 1.0)
	if amount >= 0.5:
		Settings.rumble_pulse(amount * 0.8, 0.3)


func snap() -> void:
	if target == null:
		return
	_offset = Vector2.ZERO
	_distance = BASE_DISTANCE * zoom
	position = _desired(target.pos)


func tick(delta: float) -> void:
	_time += delta
	if target == null:
		return
	var look := target.aim * 3.5 + target.vel * 0.3
	_offset = _offset.lerp(look, 1.0 - exp(-1.8 * delta))
	var want_distance := (BASE_DISTANCE + target.vel.length() * 0.35) * zoom
	_distance = lerpf(_distance, want_distance, 1.0 - exp(-1.5 * delta))
	var desired := _desired(target.pos + _offset)
	position = position.lerp(desired, 1.0 - exp(-6.0 * delta))

	_trauma = maxf(_trauma - delta * 1.6, 0.0)
	var shake := _trauma * _trauma
	h_offset = _shake_noise.get_noise_2d(_time * 60.0, 0.0) * shake * 0.9
	v_offset = _shake_noise.get_noise_2d(0.0, _time * 60.0) * shake * 0.9
	rotation.z = _shake_noise.get_noise_2d(_time * 40.0, 100.0) * shake * 0.03


func _desired(focus: Vector2) -> Vector3:
	var half_h := _distance * tan(deg_to_rad(fov * 0.5))
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var half_w := half_h * aspect
	# Keep the view mostly inside the zone (a little slack so walls show).
	var margin := 6.0
	var x := clampf(focus.x, half_w - margin, maxf(level_size.x - half_w + margin, half_w - margin))
	var y := clampf(focus.y, -level_size.y + half_h - margin, -half_h + margin + 8.0)
	if level_size.x < half_w * 2.0 - margin * 2.0:
		x = level_size.x * 0.5
	return Vector3(x, y, _distance)
