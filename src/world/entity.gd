class_name Entity
extends Node3D
## Base class for everything that lives on the gameplay plane: creatures,
## pickups, caches, projectiles. Entities are ticked by their [Level] (not by
## _physics_process) so distant ones can sleep and update order is explicit.

## How a harpoon reacts when it strikes this entity.
enum HarpoonReaction { IGNORE, STICK, DRAG }

var level: Level
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var radius := 1.0
var alive := true
## Entities further than this from the player are not ticked.
var active_radius := 70.0
## Whether sonar/harpoon/torpedoes consider this entity a target.
var targetable := false


func _enter_tree() -> void:
	sync_transform()


## Called once after the entity is added to a level.
func setup() -> void:
	pass


func tick(_delta: float) -> void:
	pass


func sync_transform() -> void:
	position = Vector3(pos.x, pos.y, 0.0)


## Removes the entity from its level at the end of the frame.
func despawn() -> void:
	if not alive:
		return
	alive = false
	if level:
		level.remove_entity(self)
	queue_free()


func on_harpoon_hit(_harpoon: Node, _damage: float) -> HarpoonReaction:
	return HarpoonReaction.IGNORE


func on_sonar(_origin: Vector2, _mark_time: float) -> void:
	pass


## Moves the entity with terrain collision. Returns the contact normal or
## Vector2.ZERO if nothing was hit.
func move_and_collide_field(delta: float, bounce := 0.1) -> Vector2:
	var field := level.field
	var motion := vel * delta
	var steps := maxi(1, ceili(motion.length() / (radius * 0.5 + 0.2)))
	var hit := Vector2.ZERO
	for _i in steps:
		pos += motion / steps
		var d := field.sample(pos)
		if d < radius:
			var n := field.normal(pos)
			pos += n * (radius - d)
			var vn := vel.dot(n)
			if vn < 0.0:
				vel -= n * vn * (1.0 + bounce)
			hit = n
	return hit
