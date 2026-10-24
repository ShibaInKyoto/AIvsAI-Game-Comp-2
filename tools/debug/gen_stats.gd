extends SceneTree
## Debug helper: generates many zones and reports retries / failures / timing.
## Usage: godot --headless --path . -s res://tools/debug/gen_stats.gd -- [count]


func _initialize() -> void:
	var count := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 50
	var fails := 0
	var total_ms := 0
	var worst_ms := 0
	var n := 0
	for zone in BiomeLibrary.TOTAL_ZONES:
		for s in count:
			var t := Time.get_ticks_msec()
			var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), s * 7 + 1, zone)
			var ms := Time.get_ticks_msec() - t
			total_ms += ms
			worst_ms = maxi(worst_ms, ms)
			n += 1
			if not layout.is_reachable(layout.exit) or not layout.is_reachable(layout.start):
				fails += 1
				print("FAIL zone %d seed %d" % [zone, s * 7 + 1])
	print("zones=%d fails=%d avg=%dms worst=%dms" % [n, fails, total_ms / n, worst_ms])
	quit()
