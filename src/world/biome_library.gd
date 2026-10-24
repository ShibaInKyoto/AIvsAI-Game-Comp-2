class_name BiomeLibrary
extends RefCounted
## The five biomes of the trench, from the sunlit shelf to the hadal floor.
## Each biome spans [constant ZONES_PER_BIOME] zones of a dive.

const ZONES_PER_BIOME := 2
const BIOME_COUNT := 5
## Zones in a full dive, including the final encounter.
const TOTAL_ZONES := BIOME_COUNT * ZONES_PER_BIOME + 1

static var _cache: Array[BiomeDef] = []


static func get_biome(index: int) -> BiomeDef:
	if _cache.is_empty():
		_cache = [_shelf(), _reef(), _midnight(), _vents(), _hadal()]
	return _cache[clampi(index, 0, _cache.size() - 1)]


## Biome used by the given zone of a dive (0-based).
static func biome_for_zone(zone: int) -> BiomeDef:
	@warning_ignore("integer_division")
	return get_biome(mini(zone / ZONES_PER_BIOME, BIOME_COUNT - 1))


## Depth range in meters covered by a single zone.
static func zone_depth_range(zone: int) -> Vector2:
	if zone >= BIOME_COUNT * ZONES_PER_BIOME:
		var b := get_biome(BIOME_COUNT - 1)
		return Vector2(b.depth_range.y - 400.0, b.depth_range.y)
	var biome := biome_for_zone(zone)
	var part := zone % ZONES_PER_BIOME
	var span := (biome.depth_range.y - biome.depth_range.x) / ZONES_PER_BIOME
	return Vector2(biome.depth_range.x + span * part, biome.depth_range.x + span * (part + 1))


static func is_final_zone(zone: int) -> bool:
	return zone >= BIOME_COUNT * ZONES_PER_BIOME


static func _shelf() -> BiomeDef:
	var b := BiomeDef.new()
	b.id = &"shelf"
	b.display_name = "Sunlit Shelf"
	b.tagline = "Where the light still reaches."
	b.depth_range = Vector2(20, 200)
	b.zone_width = Vector2i(110, 130)
	b.zone_height = 200
	b.tunnel_radius = Vector2(4.5, 7.5)
	b.chamber_radius = Vector2(11.0, 18.0)
	b.chamber_chance = 0.55
	b.branch_count = Vector2i(3, 4)
	b.rock_tint = Color(0.62, 0.58, 0.5)
	b.rock_tint_deep = Color(0.36, 0.4, 0.42)
	b.sediment_tint = Color(0.85, 0.78, 0.6)
	b.water_color = Color(0.1, 0.42, 0.5)
	b.water_color_deep = Color(0.03, 0.18, 0.3)
	b.fog_density = 0.03
	b.ambient_color = Color(0.35, 0.65, 0.75)
	b.ambient_energy = 0.5
	b.caustics = 1.0
	b.sun_energy = 1.0
	b.snow_amount = 0.6
	b.glow_color = Color(0.4, 1.0, 0.8)
	b.creatures = {&"shoal": 3.0, &"jelly": 1.6, &"lancer": 1.0}
	b.creature_budget = 9
	b.props = {&"kelp": 1.0, &"rock": 1.0, &"coral": 0.6, &"anemone": 0.5}
	b.bulb_count = 4
	b.music = &"shelf"
	return b


static func _reef() -> BiomeDef:
	var b := BiomeDef.new()
	b.id = &"reef"
	b.display_name = "Twilight Reef"
	b.tagline = "The last blue, and the first lights."
	b.depth_range = Vector2(200, 1000)
	b.zone_width = Vector2i(120, 140)
	b.zone_height = 230
	b.tunnel_radius = Vector2(4.0, 7.0)
	b.chamber_radius = Vector2(10.0, 17.0)
	b.chamber_chance = 0.5
	b.branch_count = Vector2i(3, 5)
	b.rock_tint = Color(0.45, 0.42, 0.5)
	b.rock_tint_deep = Color(0.22, 0.24, 0.35)
	b.sediment_tint = Color(0.55, 0.5, 0.6)
	b.water_color = Color(0.04, 0.14, 0.32)
	b.water_color_deep = Color(0.01, 0.05, 0.14)
	b.fog_density = 0.04
	b.ambient_color = Color(0.2, 0.3, 0.6)
	b.ambient_energy = 0.9
	b.caustics = 0.15
	b.sun_energy = 0.25
	b.snow_amount = 1.0
	b.glow_color = Color(1.0, 0.35, 0.85)
	b.creatures = {&"shoal": 2.0, &"jelly": 2.0, &"lancer": 1.6, &"lurelight": 1.0}
	b.creature_budget = 12
	b.props = {&"coral": 1.2, &"fan": 1.0, &"rock": 0.8, &"anemone": 0.8, &"kelp": 0.3}
	b.bulb_count = 5
	b.music = &"reef"
	return b


static func _midnight() -> BiomeDef:
	var b := BiomeDef.new()
	b.id = &"midnight"
	b.display_name = "Midnight Caverns"
	b.tagline = "Nothing down here has ever seen the sun."
	b.depth_range = Vector2(1000, 4000)
	b.zone_width = Vector2i(125, 145)
	b.zone_height = 250
	b.tunnel_radius = Vector2(3.6, 6.2)
	b.chamber_radius = Vector2(10.0, 19.0)
	b.chamber_chance = 0.45
	b.branch_count = Vector2i(4, 5)
	b.wall_noise_amp = 2.4
	b.spire_count = 10
	b.rock_tint = Color(0.3, 0.33, 0.4)
	b.rock_tint_deep = Color(0.12, 0.14, 0.2)
	b.sediment_tint = Color(0.35, 0.36, 0.42)
	b.vein_color = Color(0.1, 0.8, 1.0)
	b.vein_strength = 0.0
	b.water_color = Color(0.01, 0.03, 0.08)
	b.water_color_deep = Color(0.0, 0.01, 0.03)
	b.fog_density = 0.045
	b.ambient_color = Color(0.25, 0.32, 0.55)
	b.ambient_energy = 1.6
	b.snow_amount = 1.2
	b.glow_color = Color(0.2, 0.9, 1.0)
	b.creatures = {&"gulper": 2.0, &"lurelight": 1.5, &"jelly": 1.0, &"shoal": 1.0, &"lancer": 1.0, &"stalker": 0.6}
	b.creature_budget = 13
	b.props = {&"crystal": 1.0, &"mushroom": 1.0, &"rock": 1.0, &"spine": 0.5}
	b.bulb_count = 6
	b.music = &"midnight"
	return b


static func _vents() -> BiomeDef:
	var b := BiomeDef.new()
	b.id = &"vents"
	b.display_name = "Abyssal Vents"
	b.tagline = "The sea floor is breathing fire."
	b.depth_range = Vector2(4000, 6000)
	b.zone_width = Vector2i(125, 145)
	b.zone_height = 250
	b.tunnel_radius = Vector2(3.8, 6.5)
	b.chamber_radius = Vector2(11.0, 19.0)
	b.chamber_chance = 0.5
	b.branch_count = Vector2i(3, 5)
	b.wall_noise_amp = 2.6
	b.rock_tint = Color(0.22, 0.2, 0.2)
	b.rock_tint_deep = Color(0.1, 0.08, 0.08)
	b.sediment_tint = Color(0.45, 0.4, 0.3)
	b.vein_color = Color(1.0, 0.35, 0.05)
	b.vein_strength = 1.0
	b.water_color = Color(0.05, 0.025, 0.02)
	b.water_color_deep = Color(0.015, 0.005, 0.005)
	b.fog_density = 0.05
	b.ambient_color = Color(0.4, 0.15, 0.08)
	b.ambient_energy = 1.3
	b.snow_amount = 0.8
	b.glow_color = Color(1.0, 0.5, 0.15)
	b.creatures = {&"isopod": 3.0, &"gulper": 1.0, &"jelly": 1.0, &"lancer": 1.0, &"stalker": 0.6}
	b.creature_budget = 14
	b.props = {&"tubeworm": 1.2, &"chimney": 0.6, &"rock": 1.0, &"crystal": 0.3}
	b.bulb_count = 6
	b.music = &"vents"
	return b


static func _hadal() -> BiomeDef:
	var b := BiomeDef.new()
	b.id = &"hadal"
	b.display_name = "Hadal Trench"
	b.tagline = "Something down here is singing."
	b.depth_range = Vector2(6000, 10900)
	b.zone_width = Vector2i(130, 150)
	b.zone_height = 260
	b.tunnel_radius = Vector2(3.8, 6.8)
	b.chamber_radius = Vector2(12.0, 20.0)
	b.chamber_chance = 0.5
	b.branch_count = Vector2i(3, 5)
	b.wall_noise_amp = 2.0
	b.spire_count = 12
	b.rock_tint = Color(0.42, 0.38, 0.48)
	b.rock_tint_deep = Color(0.14, 0.1, 0.2)
	b.sediment_tint = Color(0.5, 0.45, 0.55)
	b.vein_color = Color(0.6, 0.3, 1.0)
	b.vein_strength = 0.3
	b.water_color = Color(0.03, 0.01, 0.06)
	b.water_color_deep = Color(0.01, 0.0, 0.02)
	b.fog_density = 0.05
	b.ambient_color = Color(0.25, 0.15, 0.4)
	b.ambient_energy = 1.4
	b.snow_amount = 1.4
	b.glow_color = Color(0.7, 0.4, 1.0)
	b.creatures = {&"stalker": 1.0, &"gulper": 1.5, &"lurelight": 1.2, &"jelly": 1.2, &"isopod": 1.0, &"lancer": 1.2}
	b.creature_budget = 15
	b.props = {&"crystal": 1.2, &"spine": 1.0, &"rock": 0.8, &"mushroom": 0.4}
	b.bulb_count = 6
	b.music = &"hadal"
	return b
