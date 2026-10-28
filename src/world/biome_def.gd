class_name BiomeDef
extends Resource
## Static description of a biome: how its zones are generated, how they look
## and what lives in them. Instances are built by [BiomeLibrary].

@export var id: StringName
@export var display_name: String
@export var tagline: String
## Depth in meters covered by this biome (both zones together).
@export var depth_range := Vector2(0, 200)

@export_group("Generation")
@export var zone_width := Vector2i(110, 140)
@export var zone_height := 240
@export var tunnel_radius := Vector2(3.6, 6.5)
@export var chamber_radius := Vector2(9.0, 16.0)
@export var chamber_chance := 0.45
@export var branch_count := Vector2i(3, 5)
@export var wall_noise_amp := 2.0
@export var wall_noise_freq := 0.05
## Frequency and threshold of the large organic caverns (higher = fewer).
@export var cavern_noise_freq := 0.022
@export var cavern_threshold := 0.64
@export var spire_count := 6
@export var pillar_chance := 0.3

@export_group("Look")
@export var rock_tint := Color(0.5, 0.5, 0.5)
@export var rock_tint_deep := Color(0.3, 0.3, 0.35)
@export var sediment_tint := Color(0.7, 0.65, 0.5)
@export var vein_color := Color(0, 0, 0)
@export var vein_strength := 0.0
@export var water_color := Color(0.05, 0.25, 0.35)
@export var water_color_deep := Color(0.0, 0.05, 0.1)
@export var fog_density := 0.03
@export var ambient_color := Color(0.2, 0.4, 0.5)
@export var ambient_energy := 0.4
@export var caustics := 0.0
@export var sun_energy := 0.0
@export var snow_amount := 1.0
@export var glow_color := Color(0.2, 1.0, 0.9)

@export_group("Content")
## Creature id -> spawn weight.
@export var creatures: Dictionary[StringName, float] = {}
@export var creature_budget := 10
## Prop id -> density multiplier.
@export var props: Dictionary[StringName, float] = {}
@export var bulb_count := 5
## Erupting thermal vents per zone (see [ThermalVent]).
@export var vent_count := 0
## Loose stalactites per zone (see [Stalactite]).
@export var stalactite_count := 0
@export var cache_count := 3
@export var music: StringName = &"shelf"
