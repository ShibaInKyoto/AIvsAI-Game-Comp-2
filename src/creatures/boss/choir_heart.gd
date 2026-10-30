class_name ChoirHeart
extends Creature
## The Choir's heart, as something a harpoon can reach: once its four voice
## organs are gone it surges forward out of the dark, and its throat opens
## for a moment each time the pilot answers the song. Wounded enough, it does
## not die; it falls silent and listens (see [method ChoirBoss.begin_duet]).
## Its body is drawn by the [ChoirBoss]; this is only where blows land.

var boss: ChoirBoss
var _shield_hint := 0.0


func setup() -> void:
	species = &"choir"
	max_hp = 260.0
	radius = 4.2
	mass = 999.0
	# Its body looms behind the water the sub swims in: touching does nothing.
	contact_damage = 0.0
	hostile = false
	salvage_drop = 0
	glow_color = Color(1.0, 0.35, 0.9)
	ambushable = false
	super.setup()
	active_radius = 400.0
	lock_facing = true


func behave(delta: float) -> void:
	_shield_hint = maxf(_shield_hint - delta, 0.0)
	vel = Vector2.ZERO
	if boss:
		pos = boss.pos


func move_and_collide_field(_delta: float, _bounce := 0.1) -> Vector2:
	return Vector2.ZERO


## Shock pulses and concussive pings mean nothing to it.
func stun(_duration: float) -> void:
	pass


func take_damage(amount: float, from: Vector2, kind: StringName = &"") -> void:
	if boss == null or boss.part != ChoirBoss.Part.REACH:
		return
	if boss.vulnerable <= 0.0:
		if _shield_hint <= 0.0:
			_shield_hint = 4.0
			Fx.float_text(level, pos + Vector2(0.0, radius + 1.0), "NO EFFECT", UiTheme.TEXT_DIM)
			Events.toast.emit("Its throat is closed. Answer the song to open it.", UiTheme.WARN)
		return
	super.take_damage(amount, from, kind)
	boss.on_heart_hurt(hp / max_hp)


func on_harpoon_hit(_harpoon: Node, damage: float) -> HarpoonReaction:
	take_damage(damage, level.player.pos if level.player else pos, &"harpoon")
	return HarpoonReaction.STICK if targetable else HarpoonReaction.IGNORE


## Silenced, not killed: it stops singing and starts listening.
func die() -> void:
	if not targetable:
		return
	targetable = false
	hp = 0.0
	if boss:
		boss.begin_duet()
