extends SceneTree
## Debug helper: generates zones and writes the distance field as PNGs.
## Usage: godot --headless --path . -s res://tools/debug/dump_level.gd -- <out_dir> [zone] [seed]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "user://"
	var zone := int(args[1]) if args.size() > 1 else 0
	var zone_seed := int(args[2]) if args.size() > 2 else 1234
	var t := Time.get_ticks_msec()
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), zone_seed, zone)
	print("generated in %d ms, size %s, anchors %d, chambers %d" % [Time.get_ticks_msec() - t,
		layout.size(), layout.anchors.size(), layout.chambers.size()])
	var f := layout.field
	var img := Image.create(f.width, f.height, false, Image.FORMAT_RGB8)
	for y in f.height:
		for x in f.width:
			var v := f.data[y * f.width + x]
			var c: Color
			if v < 0.0:
				c = Color(0.25, 0.2, 0.15).lerp(Color(0.05, 0.04, 0.03), clampf(-v / 6.0, 0, 1))
			else:
				var reach := layout.reachable[y * f.width + x] == 1
				c = (Color(0.1, 0.4, 0.6) if reach else Color(0.4, 0.1, 0.1)).lerp(Color(0.6, 0.9, 1.0), clampf(v / 12.0, 0, 1))
			img.set_pixel(x, y, c)
	for a in layout.anchors:
		img.set_pixel(clampi(int(a.pos.x / f.cell), 0, f.width - 1), clampi(int(-a.pos.y / f.cell), 0, f.height - 1),
				Color.YELLOW)
	for c in layout.chambers:
		var col := Color.GREEN if c.kind == &"loot" else (Color.MAGENTA if c.kind == &"exit" else Color.WHITE)
		img.fill_rect(Rect2i(int(c.center.x / f.cell) - 2, int(-c.center.y / f.cell) - 2, 5, 5), col)
	img.fill_rect(Rect2i(int(layout.exit.x / f.cell) - 3, int(-layout.exit.y / f.cell) - 3, 7, 7), Color.RED)
	img.save_png(out_dir.path_join("zone_%d_%d.png" % [zone, zone_seed]))
	quit()
