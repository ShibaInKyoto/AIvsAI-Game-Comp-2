# FATHOM — Design Document

> *Light reveals. Sound betrays.*

## Pitch

A 2.5D submarine descent roguelite. You pilot the *Lantern*, a small salvage
submersible, down a trench that rearranges itself every dive, to find out why a
research station that went silent at the bottom of the sea has started
pinging again — and what is pinging back.

The game is rendered in full 3D (Godot 4, Forward+) but played on a 2D plane:
the camera looks at a cross-section of the trench, so caves read like a
diorama with real depth, lighting and volumetric water.

## Pillars

1. **Light & sound are your tools and your liabilities.** The lamp shows you the
   way but some creatures hunt light. The sonar ping maps the dark for a few
   seconds, but everything with ears hears it.
2. **Push your luck.** Every stop between zones offers the choice to surface
   and bank your salvage, or go deeper for richer rewards.
3. **A living ecosystem.** Fish school and scatter, predators eat fish, flares
   distract hunters, jellies drift on currents.
4. **Atmosphere first.** Volumetric light, marine snow, bioluminescence,
   underwater audio.

## Core loop

```
Hangar (spend salvage & research) -> Dive -> Zone 1 -> Decompression stop
  -> Zone 2 -> ... -> Hadal Trench (final encounter) -> Ending
        \-> Surface at any stop (bank 100%)   \-> Implode (bank 50%)
```

### A dive

* 5 biomes x 2 zones + the final zone. ~2-4 minutes per zone.
* Each zone is a procedurally generated cave cross-section. The exit (a downward
  fissure with a strong current) is hidden; sonar reveals it on the HUD.
* Side chambers hold wrecks with caches (salvage, modules), signal logs (lore),
  and bioluminescent bulbs that recharge the battery.
* Decompression stop between zones: choose 1 of 3 modules (run upgrades), repair
  hull with salvage, then descend or surface.

### Biomes

| # | Biome            | Depth       | Mood / hazards                                        |
|---|------------------|-------------|-------------------------------------------------------|
| 1 | Sunlit Shelf     | 0–200 m     | God rays, kelp, schools, drifter jellies, lancers     |
| 2 | Twilight Reef    | 200–1000 m  | Bioluminescent coral, anglers, siphonophores          |
| 3 | Midnight Caverns | 1–4 km      | Pitch dark, gulper eels in walls, the Stalker         |
| 4 | Abyssal Vents    | 4–6 km      | Hydrothermal vents, heat currents, latching isopods   |
| 5 | Hadal Trench     | 6–11 km     | Alien geometry, the Meridian station, the Choir       |

## Player kit

| Input            | Action                                                              |
|------------------|---------------------------------------------------------------------|
| WASD / L-stick   | Thrust (inertial, water drag)                                        |
| Mouse / R-stick  | Aim lamp & tools                                                     |
| Shift / LT       | Boost (fast, loud, drains battery)                                   |
| LMB / RT         | Harpoon: spear creatures, hook caches and drag them, grapple walls    |
| RMB / RB         | Tool: torpedo / flare / shock pulse (cycle with Q / LB)              |
| Space / A        | Sonar ping                                                           |
| F / Y            | Toggle lamp                                                          |
| Tab / Back       | Sonar map                                                            |
| 1 / 2 / 3        | Pick a module at a decompression stop                                |

Resources: **Hull** (health), **Battery** (lamp, sonar, boost and tools draw
from it), **Salvage** (meta currency), **Research** (from scanning creatures by
holding the lamp on them; unlocks modules and subs).

**Noise**: every action emits noise (thrust ~ speed, boost, ping, explosions,
impacts). Creatures with hearing investigate noise sources.

## Creatures

| Creature        | Biomes | Senses       | Behaviour                                              |
|-----------------|--------|--------------|--------------------------------------------------------|
| Glimmer shoal   | 1-3    | sight        | Boids. Scatter from the sub. Prey for predators.       |
| Drifter jelly   | 1-5    | none         | Drifts with currents. Shocks on contact.               |
| Lancer          | 1-3    | hearing      | Charges noise sources in straight dashes.              |
| Lurelight       | 2-5    | light        | Ambush angler hidden in the dark behind a glowing lure.|
| Gulper eel      | 3-5    | vibration    | Lunges from wall burrows when you pass fast.           |
| Stalker         | 3-5    | hearing+light| Large hunter. Investigates noise, attacks light.       |
| Vent isopod     | 4-5    | touch        | Crawls on walls, latches onto the hull, drains power.  |
| Siphonophore    | 2,3,5  | touch        | A drifting chain of bells that stings along its length.|
| Mimic           | 3-5    | touch        | Disguised as a salvage cache; wakes, lunges and chases.|
| The Choir       | 5      | everything   | Final encounter.                                       |

## Replayability

* Seeded procedural zones, random module drafts, random cache contents.
* 4 submarine frames with different stats and starting tools.
* Meta upgrades (hull, battery, thrusters, lamp, sonar, cargo, tool unlocks).
* Codex: scan every creature, collect every signal log.
* **Pressure** levels after the first win (stacking difficulty modifiers).
* Daily dive (date-seeded), with today's best depth on the title screen.
* Zone events (currents, blackout, frenzy, wrecks, dead calm, bloom) forecast
  at the decompression stop.
* Optional zone objectives for bonus salvage or research.
* 14 milestones, each unlocking a hull paint.

## Technical approach

* **Terrain**: a 2D density grid is carved by a path/chamber generator, eroded
  by domain-warped noise, flood-filled for connectivity, then converted to a
  signed distance field (exact Euclidean distance transform). The SDF drives
  *both* gameplay collision (sphere vs SDF, raymarched projectiles, steering)
  and rendering: it is uploaded as a float texture and a vertex shader extrudes
  a subdivided plane into a relief heightfield. No physics engine is used for
  gameplay, which keeps it deterministic and cheap.
* **Sonar**: global shader uniforms carry the last pings; terrain and creature
  shaders draw the expanding wavefront and a fading contour reveal.
* **Audio**: all sound effects and music are synthesized by a Python script in
  `tools/audio/` and committed as OGG files.
* **Art**: all meshes are procedurally built at runtime; rock textures are
  CC0 from Poly Haven.

## Architecture

**Scene flow.** `main.tscn` installs the theme and hands over to the
`Router` autoload, which owns every scene change (with a fade): title,
hangar, dive and ending. The dive scene (`src/dive/dive.gd`) runs one zone
at a time: it generates the layout on a worker thread, builds a `Level`,
populates it, spawns the `Submarine`, and between zones shows the
`DecompressionStop` before loading the next.

**Autoloads** hold the cross-cutting services, each with one job:

| Autoload   | Responsibility                                                       |
|------------|----------------------------------------------------------------------|
| `Settings` | Preferences, the input map (registered in code), video quality       |
| `Events`   | Signal bus for decoupled notifications (toasts, noise, kills, scans) |
| `Audio`    | Bus layout, pooled 2D/3D players, music crossfades, lazy stream cache|
| `Game`     | The persistent `MetaState`, the current `RunState`, save and banking |
| `Router`   | Scene transitions, clean quit, debug screenshot capture              |

**Per-frame order.** Everything on the gameplay plane updates from
`Dive._process` in a fixed order with a clamped delta, rather than from
scattered `_physics_process` callbacks: autopilot (tests only) -> submarine
-> level (every awake entity, then deferred removals and noise expiry) ->
heartbeat -> zone objective -> camera. Hitstop freezes the simulation but
not the camera.

**Entities.** `Entity` (`src/world/entity.gd`) is the base for creatures,
pickups, caches and projectiles: a 2D position and velocity on the play
plane, a radius, `setup()`/`tick()` hooks and `sync_transform()` into 3D.
Creatures add senses (hearing via `Level.loudest_noise_at`, light via the
sub's lamp cone, line of sight via the SDF), steering and a per-species
`think()`/`behave()` state machine.

**Data.** Static game data lives in `src/data/` as typed definitions
(frames, upgrades, modules, biomes, codex, logs, events, milestones, tips),
separate from the mutable state in `src/core/` (`RunState` for one dive,
`MetaState` for the save, `SubStats` derived from frame + upgrades +
modules). Saves are JSON, written to a temp file and renamed into place.

**Testing.** `tests/run_tests.gd` loads every `tests/unit/test_*.gd` suite
headlessly: data integrity, generator invariants (reachability, sealed
pockets, corridor width), a physical traversal of every zone, creature and
boss simulations, save round trips and asset references.
`tests/flow_test.tscn` clicks through the menus and a dive end to end.
CI fails on any test failure and on any runtime script or shader error.
