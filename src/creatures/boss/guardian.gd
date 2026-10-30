class_name Guardian
extends Creature
## Base for the bosses that lair in a zone's exit chamber and seal the way
## down until they fall: the lair geometry, the name on the health bar, the
## waking fanfare and the shared rewards for beating one.
## A guardian takes no harm at all except while it is caught out in its own
## particular way (the Lamplighter dazzled, the Mother wedged in the rock, the
## Ironclad's shell cracked by heat), and once it recovers it cannot be
## caught out again for [constant STUN_GUARD] seconds. Shock pulses and
## concussive pings only make it flinch.

signal defeated

## After an opening closes, the seconds before the guardian can be caught
## out again: no stun-locking a guardian.
const STUN_GUARD := 8.0

## Shown on the HUD health bar while the guardian is awake.
var title := ""
var lair_center := Vector2.ZERO
var lair_radius := Vector2(24.0, 14.0)
## True from the moment it wakes until it dies.
var active := false
## Seconds left before it can be caught out again (see [constant STUN_GUARD]).
var stun_guard := 0.0
var _deflect_cooldown := 0.0
var _taught_deflect := false


func tick(delta: float) -> void:
	stun_guard = maxf(stun_guard - delta, 0.0)
	_deflect_cooldown = maxf(_deflect_cooldown - delta, 0.0)
	super.tick(delta)


## Shock pulses and concussive pings make a guardian flinch, nothing more.
func stun(_duration: float) -> void:
	if _deflect_cooldown <= 0.0:
		_deflect_cooldown = 0.6
		Fx.float_text(level, pos + Vector2(0.0, radius + 1.5), "SHRUGS IT OFF", UiTheme.TEXT_DIM)


## A blow that does nothing: a clank, a spark, and (once) how to hurt it.
func deflect(from: Vector2, hint: String, pitch := 0.6) -> void:
	if not active:
		return
	if _deflect_cooldown <= 0.0:
		_deflect_cooldown = 0.5
		Audio.play_at(&"harpoon_wall", pos, -2.0, 0.05, pitch)
		Fx.sparks(level, pos + (from - pos).normalized() * radius)
		Fx.float_text(level, pos + Vector2(0.0, radius + 1.5), "NO EFFECT", UiTheme.TEXT_DIM)
	if not _taught_deflect and hint != "":
		_taught_deflect = true
		Events.toast.emit(hint, UiTheme.WARN)


## Its opening has closed: the guard is up for a while.
func raise_guard() -> void:
	stun_guard = STUN_GUARD


func in_lair(p: Vector2, scale := 1.0) -> bool:
	return ((p - lair_center) / (lair_radius * scale)).length_squared() < 1.0


## Starts the fight: lair music, a roar and a banner naming the guardian.
func wake(hint: String, roar_pitch := 0.55, music := &"lair") -> void:
	active = true
	alert()
	Audio.play_at(&"stalker_roar", pos, 4.0, 0.03, roar_pitch)
	Audio.play_music(music, 1.0)
	Events.shake_requested.emit(0.7)
	Events.banner.emit(title, hint)


## The shared end of a guardian fight: effects, rewards and the way down.
func reward_defeat(epitaph: String) -> void:
	active = false
	targetable = false
	hostile = false
	Events.hitstop.emit(0.25)
	Events.shake_requested.emit(1.0)
	Fx.flash(level, pos, glow_color, 30.0, 0.8)
	Fx.ichor(level, pos, glow_color, 60)
	Fx.bubble_burst(level, pos, 60, 3.0)
	Audio.play_at(&"choir_death", pos, 0.0, 0.0, 0.7)
	Events.creature_killed.emit(species, pos)
	var sub := level.player
	if sub:
		sub.run.kills += 1
		sub.run.research += 15
		sub.show_gain(15, " research", UiTheme.ACCENT)
	Pickup.scatter(level, pos, &"salvage", salvage_drop, 3.0)
	# Enough hull back to make the next zone after a hard fight.
	Pickup.scatter(level, pos, &"repair", 35, 2.0)
	level.unseal_exit()
	Audio.play_music(level.biome.music, 3.0)
	Events.banner.emit("THE WAY DOWN IS OPEN", epitaph)
	defeated.emit()
