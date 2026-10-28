class_name Guardian
extends Creature
## Base for the bosses that lair in a zone's exit chamber and seal the way
## down until they fall: the lair geometry, the name on the health bar, the
## waking fanfare and the shared rewards for beating one.

signal defeated

## Shown on the HUD health bar while the guardian is awake.
var title := ""
var lair_center := Vector2.ZERO
var lair_radius := Vector2(24.0, 14.0)
## True from the moment it wakes until it dies.
var active := false


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
	Pickup.scatter(level, pos, &"repair", 2, 2.0)
	level.unseal_exit()
	Audio.play_music(level.biome.music, 3.0)
	Events.banner.emit("THE WAY DOWN IS OPEN", epitaph)
	defeated.emit()
