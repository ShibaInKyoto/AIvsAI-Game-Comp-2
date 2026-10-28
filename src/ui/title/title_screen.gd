extends Node3D
## Title screen: live backdrop, logo and main menu.

var _menu: VBoxContainer
var _ui: Control


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var backdrop := MenuBackdrop.new()
	backdrop.view_shift = -6.0
	add_child(backdrop)
	Audio.play_music(&"title")
	add_child(PostFx.new())
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.theme = UiTheme.get_theme()
	layer.add_child(_ui)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.material = _side_shade()
	_ui.add_child(shade)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	column.offset_left = 120
	column.offset_right = 760
	column.offset_top = 0
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 10)
	_ui.add_child(column)

	var title := UiUtil.label("FATHOM", &"TitleLabel", 150)
	title.add_theme_color_override(&"font_color", Color(0.85, 0.97, 1.0))
	title.add_theme_constant_override(&"shadow_offset_y", 6)
	title.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.3, 0.4, 0.6))
	title.material = _logo_material()
	column.add_child(title)
	column.add_child(UiUtil.label("Light reveals.  Sound betrays.", &"HeaderLabel", 30))
	column.add_child(UiUtil.spacer(40))

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override(&"separation", 12)
	column.add_child(_menu)
	var saved := Game.saved_run()
	var resume: Button
	if saved:
		var biome := BiomeLibrary.biome_for_zone(saved.zone)
		resume = UiUtil.button("Resume dive   (zone %d, %s)" % [saved.zone + 1, biome.display_name], _on_resume, 360)
		_menu.add_child(resume)
	var dive := UiUtil.button("New dive" if saved else "Dive", _on_dive, 360)
	_menu.add_child(dive)
	var daily := "Daily dive: %s" % ZoneEvents.display_name(ZoneEvents.daily(Game.today()))
	var record := Game.meta.daily_summary(Game.today())
	if record != "":
		daily += "   (%s)" % record
	_menu.add_child(UiUtil.button(daily, _on_daily, 360))
	_menu.add_child(UiUtil.button("Hangar", func() -> void: Router.go_to(Router.HANGAR), 360))
	_menu.add_child(UiUtil.button("How to dive", func() -> void: add_child(HowToPlayPanel.new()), 360))
	_menu.add_child(UiUtil.button("Settings", func() -> void: add_child(SettingsPanel.new()), 360))
	_menu.add_child(UiUtil.button("Quit", func() -> void: Router.quit(), 360))
	for b in _menu.get_children():
		(b as Button).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		(b as Button).alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(UiUtil.spacer(30))
	var meta := Game.meta
	var stats := "Dives %d   -   Deepest %s m   -   Salvage %d   -   Research %d" % [
		meta.dives, UiUtil.thousands(meta.deepest_depth), meta.salvage, meta.research]
	column.add_child(UiUtil.label(stats, &"DimLabel"))
	if saved:
		column.add_child(UiUtil.label("Starting a new dive abandons the interrupted one (insurance still pays).",
				&"DimLabel", 18))
	if meta.dives == 0:
		column.add_child(UiUtil.label("New pilot: start with Dive. The first zone teaches the basics.", &"DimLabel",
				18, UiTheme.ACCENT))

	var version := UiUtil.label("v%s" % ProjectSettings.get_setting("application/config/version", "1.0"), &"DimLabel", 16)
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -160
	version.offset_top = -40
	version.offset_right = -24
	version.offset_bottom = -12
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ui.add_child(version)
	(resume if resume else dive).grab_focus()
	if QualityProbe.wanted():
		var probe := QualityProbe.new()
		probe.adjusted.connect(func(quality_name: String) -> void:
			var note := UiUtil.label("Graphics set to %s for a smoother frame rate on this PC (change it in Settings)."
					% quality_name, &"DimLabel", 18, UiTheme.WARN)
			column.add_child(note))
		add_child(probe)


func _on_resume() -> void:
	if Game.resume_run():
		Router.go_to(Router.DIVE)


func _on_dive() -> void:
	Game.start_run()
	Router.go_to(Router.DIVE)


func _on_daily() -> void:
	Game.start_run(true)
	Router.go_to(Router.DIVE)


## A slow sonar sweep that brightens the logo as it passes.
static func _logo_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float sweep = fract(TIME * 0.12) * 3.0 - 1.0;
	float x = SCREEN_UV.x * 2.2;
	float band = exp(-pow((x - sweep) * 6.0, 2.0));
	c.rgb += vec3(0.25, 0.95, 1.0) * band * 0.9 * c.a;
	COLOR = c;
}
"""
	var m := ShaderMaterial.new()
	m.shader = shader
	return m


static func _side_shade() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	float a = smoothstep(0.75, 0.0, UV.x) * 0.75;
	COLOR = vec4(0.0, 0.02, 0.04, a);
}
"""
	var m := ShaderMaterial.new()
	m.shader = shader
	return m
