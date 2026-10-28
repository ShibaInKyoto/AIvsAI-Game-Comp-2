# FATHOM

**A submarine descent roguelite. Light reveals. Sound betrays.**

A research station at the bottom of the deepest trench on Earth went silent.
Three weeks later its sonar beacon started pinging again, and something started
pinging back. You pilot the *Lantern*, a small salvage submersible, down through
five biomes of a trench that rearranges itself every dive, to find out what is
singing at the bottom of the world.

![The Midnight Caverns under sonar](docs/screenshots/sonar.jpg)

| | |
|---|---|
| ![Sunlit Shelf](docs/screenshots/shelf.jpg) | ![Twilight Reef](docs/screenshots/reef.jpg) |
| ![Abyssal Vents](docs/screenshots/vents.jpg) | ![The Choir](docs/screenshots/choir.jpg) |
| ![Decompression stop](docs/screenshots/stop.jpg) | ![Hangar](docs/screenshots/hangar.jpg) |

## Quick start (Windows 10/11)

1. Download `FATHOM-windows-x64.zip` from the [Releases](../../releases) page.
2. Extract it anywhere and run `FATHOM.exe`.

It is a single executable with everything embedded. It needs a GPU with Vulkan
or Direct3D 12, which covers any dedicated GPU from the last decade. The exe is
not code-signed, so SmartScreen may warn on first launch: choose
**More info > Run anyway**. Progress and settings are saved in
`%APPDATA%\FATHOM`.

## How to play

You descend through **11 zones**: two each in the Sunlit Shelf, Twilight
Reef, Midnight Caverns, Abyssal Vents and Hadal Trench, then the hadal floor
itself. Every zone is a procedurally generated cave cross-section. Find the
**descent** (the glowing fissure at the bottom) to go deeper.

* **Your lamp** lights the way and scans creatures for research. It drains
  battery, and some things hunt light.
* **Your sonar ping** charts the cave on your map, finds the descent and marks
  creatures through the dark. Everything with ears hears it.
* **Every movement makes noise.** The faint ring around the sub shows how far
  you can be heard. Lancers dash at sound, gulper eels feel vibration through
  the rock, and the Stalker hears everything.
* **Salvage** comes from caches (ram them or drag them in with the harpoon),
  debris and creatures. **Glow bulbs** on the walls recharge your battery.
* Between zones you dock at a **decompression stop**: install one of three
  modules, repair the hull, then *descend*, or *surface* and bank your salvage
  with a depth bonus. If you implode, insurance keeps only part of it.
* Spend salvage in the **hangar** on permanent upgrades. Spend research (from
  scanning creatures and recovering logs) on three more submarines.
* At the bottom waits **the Choir**. It sings in waves. Answer each wave with
  a sonar ping as it reaches you.

### Controls

| Action | Keyboard & mouse | Gamepad |
|---|---|---|
| Thrust | `W A S D` / arrows | Left stick |
| Aim lamp and tools | Mouse | Right stick |
| Harpoon (hold on rock to winch) | Left mouse | RT |
| Use tool (flare / torpedo / shock) | Right mouse | RB |
| Cycle tool | `Q` | LB |
| Sonar ping | `Space` | A |
| Boost (loud) | `Shift` | LT |
| Toggle lamp | `F` | Y |
| Sonar chart | `Tab` | Back |
| Pick a module at a stop | `1` `2` `3` | D-pad + A |
| Pause | `Esc` | Start |
| Fullscreen | `F11` | |

**How to dive** on the title screen sums up the rules and controls. Settings
include an **Assist mode** (40% less hull damage), screen-shake strength,
gamepad rumble and four graphics presets.

## Replayability

* A new trench every dive, plus a **daily dive** with a shared, date-based seed.
* 30 modules to draft into a build. Their stats stack.
* 4 submarine frames: **Lantern** (balanced, flares), **Mako** (fast, torpedoes,
  fragile), **Bathysphere** (armored, long sonar, shock pulse), **Whisper**
  (near silent, quick scanner).
* 11 hangar upgrades, a creature codex and 11 story logs to recover.
* Nine creature species with their own senses and tells: drifting jellies,
  dashing lancers, angler-like lurelights, burrowing gulper eels, wall-crawling
  isopods, stinging siphonophore chains, caches that turn out to be mimics,
  shoals, and the Stalker, which hunts by sound across the whole zone.
* 14 milestones (silence the Choir, scan every species, kill a Stalker...), each
  unlocking a hull paint.
* **Zone objectives** for bonus salvage or research: open caches, hunt, scan
  species, stay silent, harvest bulbs, recover a log.
* **Zone events**: strong currents, blackouts, feeding frenzies, wreck
  fields, dead calm and bioluminescent blooms.
* **Pressure levels** unlock after you beat the Choir. Each level stacks a new
  modifier on top of the ones below it.

## Under the hood

FATHOM is built with **Godot 4.5** (Forward+ renderer) in statically typed
GDScript. All 3D art is generated at runtime from code.

* **Caves** (`src/world/level_generator.gd`). The generator carves tunnels,
  chambers and shafts into a signed distance field with smooth-min SDF
  operations. Domain-warped noise then erodes the walls and opens organic
  caverns. A flood fill marks the water the sub can reach and seals pockets it
  can't. Generation runs on a worker thread and takes about 0.3 s.
* **One field for everything** (`src/world/terrain_field.gd`). The same SDF
  drives collision (circle vs field), creature steering, projectile ray
  marching and rendering. It is uploaded as a half-float texture, and a vertex
  shader extrudes flat chunk grids into a relief (`terrain.gdshader`), with
  triplanar texturing, sediment, caustics and veins. Walls are pulled onto the
  exact collision outline, so what you see is what you hit.
* **Sonar** (`sonar.gdshaderinc`). Pings are global shader uniforms. Terrain,
  props and creatures all draw the wavefront and a fading contour map.
* **Creatures** (`src/creatures/`). Each species is a small state machine on a
  shared base: senses (hearing, light, line of sight), steering and wall
  avoidance. Their bodies are lathe meshes animated by a shared swim shader;
  shoals are boids on a MultiMesh.
* **Audio** (`tools/audio/`). Every sound effect and every note of music is
  synthesized by a numpy script: FM bells, detuned pads, formant "choir"
  voices, convolution reverb and seamless loops.

### Repository layout

```
src/
  autoload/   settings, signal bus, audio mixer, save/progression, scene router
  core/       run state, meta progression, submarine stats
  data/       biomes, modules/upgrades/frames, codex, logs, zone events, pressure
  world/      generator, terrain field + renderer, level, props, pickups, interactables
  creatures/  creature base, nine species, the Choir boss
  player/     submarine, model, harpoon, tool belt, projectiles
  dive/       dive controller, camera, tutorial, test autopilot
  ui/         theme, HUD, sonar chart, menus, hangar, decompression stop, ending
  fx/         shaders, particle factory, procedural mesh kit
tests/        headless unit and simulation tests (run in CI)
tools/        audio synthesis, script checker, debug renderers
```

### Building from source

Requires Godot 4.5.1 with export templates installed.

```sh
godot --headless --import                                       # first-time import
godot --headless --path . -s res://tests/run_tests.gd           # 33 tests: generation, traversal, biome and boss simulations
godot --headless --path . res://tests/flow_test.tscn            # end-to-end menu and dive flow
godot --headless --export-release "Windows Desktop" build/windows/FATHOM.exe
python3 tools/audio/generate.py                                 # regenerate all audio (numpy + ffmpeg)
```

Debugging helpers: `-- --autopilot --zone=4 --shots=<dir>` flies a bot through
a zone and saves screenshots. `-- --capture=<dir> --capture-at=5` screenshots
any screen.

CI (`.github/workflows/ci.yml`) checks every script, runs the tests and
exports the Windows build on every push. `release.yml` publishes a GitHub
release.

## Credits

Built in one week by Claude (Anthropic) for the AI vs AI Game Competition.

* Engine: [Godot Engine](https://godotengine.org) 4.5 (MIT)
* Rock and sand textures: [Poly Haven](https://polyhaven.com) (CC0)
* Fonts: Oxanium, Chakra Petch, Share Tech Mono (SIL Open Font License;
  licenses in `assets/fonts/`)
* Everything else (models, creatures, caves, effects, sound and music) is
  generated by the code in this repository.
