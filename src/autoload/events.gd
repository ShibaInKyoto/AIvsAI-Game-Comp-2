extends Node
## Global signal bus. Systems that should not know about each other (HUD,
## audio, creatures, the dive controller) communicate through these signals.

## Something made a sound. Creatures with hearing within [param radius] react.
signal noise_emitted(pos: Vector2, radius: float, source: Node)
## The player's sonar fired from [param pos].
signal sonar_pinged(pos: Vector2, range: float)
## A pulse of camera shake; [param strength] ~ 0..1.
signal shake_requested(strength: float)
## Short message shown in the HUD feed.
signal toast(text: String, color: Color)
## The rock inside [param rect] (world space) has moved.
signal terrain_changed(rect: Rect2)
## Large centered banner (zone names, warnings).
signal banner(title: String, subtitle: String)
signal creature_scanned(id: StringName, first_time: bool)
signal creature_killed(id: StringName, pos: Vector2)
signal pickup_collected(kind: StringName, amount: int)
signal log_found(id: StringName)
signal player_damaged(amount: float)
signal player_died
signal zone_exit_reached
signal cache_opened(pos: Vector2)
signal bulb_harvested(pos: Vector2)
## Requests a brief freeze of the simulation for impact (seconds).
signal hitstop(duration: float)
