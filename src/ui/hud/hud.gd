class_name Hud
extends CanvasLayer
## In-dive heads-up display: gauges, tool slot, currencies, message feed and
## the world-space overlay (crosshair, scan reticle, exit compass).

## Whether this session has already suggested sound cues to a muted player.
static var _cues_hinted := false

var sub: Submarine
var level: Level
var camera: Camera3D
var objective: ZoneObjective
## The dive's heartbeat, which the sound cues show (set by the dive).
var heartbeat: Heartbeat

var _depth_label: Label
var _zone_label: Label
var _objective_label: Label
var _hull_bar: ProgressBar
var _hull_label: Label
var _battery_bar: ProgressBar
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _battery_label: Label
var _power_alarm: Label
var _salvage_label: Label
var _research_label: Label
var _tool_label: Label
var _tool_hint: Label
var _feed: VBoxContainer
var _banner: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _overlay: HudOverlay
var _vignette: ColorRect
var _fps_label: Label
var _banner_tween: Tween
var _map: SonarMap
var _shown_salvage := 0.0
var _flash := 0.0


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)

	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.material = _vignette_material()
	root.add_child(_vignette)

	_overlay = HudOverlay.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.hud = self
	root.add_child(_overlay)

	var cues := SoundCues.new()
	cues.set_anchors_preset(Control.PRESET_FULL_RECT)
	cues.hud = self
	root.add_child(cues)

	# Depth gauge (top left).
	var depth_box := VBoxContainer.new()
	_place(depth_box, Control.PRESET_TOP_LEFT, Vector2(40, 28), Vector2(700, 110))
	depth_box.add_theme_constant_override(&"separation", -6)
	root.add_child(depth_box)
	_depth_label = Label.new()
	_depth_label.theme_type_variation = &"TitleLabel"
	_depth_label.add_theme_font_size_override(&"font_size", 54)
	depth_box.add_child(_depth_label)
	_zone_label = Label.new()
	_zone_label.theme_type_variation = &"DimLabel"
	_zone_label.add_theme_font_size_override(&"font_size", 20)
	depth_box.add_child(_zone_label)
	_objective_label = Label.new()
	_objective_label.theme_type_variation = &"DimLabel"
	_objective_label.add_theme_font_size_override(&"font_size", 18)
	depth_box.add_child(_objective_label)

	# Hull and battery (bottom left).
	var gauges := VBoxContainer.new()
	_place(gauges, Control.PRESET_BOTTOM_LEFT, Vector2(40, -120), Vector2(560, 80))
	gauges.add_theme_constant_override(&"separation", 8)
	root.add_child(gauges)
	var hull := _gauge(gauges, "HULL", Color(1.0, 0.55, 0.25))
	_hull_bar = hull[0]
	_hull_label = hull[1]
	var bat := _gauge(gauges, "BATTERY", Color(0.35, 0.95, 1.0))
	_battery_bar = bat[0]
	_battery_label = bat[1]
	# Above the gauges: the countdown once the battery is empty.
	_power_alarm = Label.new()
	_power_alarm.theme_type_variation = &"HeaderLabel"
	_power_alarm.add_theme_color_override(&"font_color", UiTheme.DANGER)
	_place(_power_alarm, Control.PRESET_BOTTOM_LEFT, Vector2(40, -170), Vector2(560, 40))
	_power_alarm.visible = false
	root.add_child(_power_alarm)

	# Tool slot (bottom right).
	var tool_box := VBoxContainer.new()
	_place(tool_box, Control.PRESET_BOTTOM_RIGHT, Vector2(-440, -120), Vector2(400, 80))
	tool_box.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(tool_box)
	_tool_label = Label.new()
	_tool_label.theme_type_variation = &"HeaderLabel"
	_tool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tool_box.add_child(_tool_label)
	_tool_hint = Label.new()
	_tool_hint.theme_type_variation = &"DimLabel"
	_tool_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tool_box.add_child(_tool_hint)

	# Currencies (top right).
	var cur := VBoxContainer.new()
	_place(cur, Control.PRESET_TOP_RIGHT, Vector2(-340, 28), Vector2(300, 80))
	root.add_child(cur)
	_salvage_label = Label.new()
	_salvage_label.theme_type_variation = &"HeaderLabel"
	_salvage_label.add_theme_color_override(&"font_color", UiTheme.WARN)
	_salvage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cur.add_child(_salvage_label)
	_research_label = Label.new()
	_research_label.theme_type_variation = &"DimLabel"
	_research_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cur.add_child(_research_label)

	# Sonar chart (right side) and the message feed beside it.
	_map = SonarMap.new()
	root.add_child(_map)
	_feed = VBoxContainer.new()
	# Kept narrow (long messages wrap) so it never runs into the zone banner.
	_place(_feed, Control.PRESET_TOP_RIGHT, Vector2(-660, 130), Vector2(440, 340))
	_feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(_feed)

	# Center banner.
	_banner = VBoxContainer.new()
	_place(_banner, Control.PRESET_CENTER_TOP, Vector2(-600, 220), Vector2(1200, 140))
	_banner.modulate.a = 0.0
	root.add_child(_banner)
	_banner_title = Label.new()
	_banner_title.theme_type_variation = &"TitleLabel"
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_title)
	_banner_sub = Label.new()
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.add_theme_color_override(&"font_color", UiTheme.ACCENT)
	_banner.add_child(_banner_sub)

	# Guardian health (top centre), shown while the Blind Mother is awake.
	_boss_box = VBoxContainer.new()
	_place(_boss_box, Control.PRESET_CENTER_TOP, Vector2(-320, 36), Vector2(640, 60))
	_boss_box.visible = false
	root.add_child(_boss_box)
	_boss_name = UiUtil.label("", &"HeaderLabel", 24, UiTheme.DANGER)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size = Vector2(640, 12)
	_boss_bar.show_percentage = false
	var boss_fill := StyleBoxFlat.new()
	boss_fill.bg_color = UiTheme.DANGER
	_boss_bar.add_theme_stylebox_override(&"fill", boss_fill)
	_boss_box.add_child(_boss_bar)

	_fps_label = Label.new()
	_fps_label.theme_type_variation = &"DimLabel"
	_place(_fps_label, Control.PRESET_BOTTOM_LEFT, Vector2(40, -34), Vector2(200, 30))
	root.add_child(_fps_label)

	Events.toast.connect(toast)
	Events.banner.connect(show_banner)
	Events.player_damaged.connect(_on_damaged)
	Events.creature_scanned.connect(_on_scanned)


func bind(p_sub: Submarine, p_level: Level, p_camera: Camera3D) -> void:
	sub = p_sub
	level = p_level
	camera = p_camera
	var biome := level.biome
	_zone_label.text = "%s  -  ZONE %d" % [biome.display_name.to_upper(), level.zone + 1]
	if BiomeLibrary.is_final_zone(level.zone):
		_zone_label.text = "THE HADAL FLOOR"
	if level.event != ZoneEvents.NONE:
		_zone_label.text += "  -  " + ZoneEvents.display_name(level.event).to_upper()
	var terms := Contracts.find(sub.run.contract)
	if terms:
		_zone_label.text += "  -  CONTRACT: " + terms.name.to_upper()
	_shown_salvage = sub.run.salvage
	_map.bind(level, sub)
	_layout_map()
	# Hunters announce themselves by sound: a pilot diving muted is pointed
	# at the setting that shows it instead (once per session).
	var muted := Settings.master_volume < 0.05 or Settings.sfx_volume < 0.05
	if muted and not Settings.sound_cues and not _cues_hinted and not Autopilot.requested():
		_cues_hinted = true
		get_tree().create_timer(2.0).timeout.connect(_hint_sound_cues)


func _hint_sound_cues() -> void:
	toast("Playing without sound? Settings > Sound cues shows where threats are heard.", UiTheme.ACCENT, 6.0)


## Small chart in the corner; Tab shows it large in the middle of the screen.
func _layout_map() -> void:
	var aspect := level.size().y / maxf(level.size().x, 1.0)
	if _map.expanded:
		var h := 820.0
		_place(_map, Control.PRESET_CENTER, Vector2(-h / aspect * 0.5, -h * 0.5), Vector2(h / aspect, h))
	else:
		var w := 140.0
		_place(_map, Control.PRESET_TOP_RIGHT, Vector2(-40 - w, 110), Vector2(w, w * aspect))


func _unhandled_input(event: InputEvent) -> void:
	if sub and event.is_action_pressed(&"map"):
		_map.expanded = not _map.expanded
		_layout_map()
		Audio.play_ui(&"ui_click", -6.0)


func _gauge(parent: Control, title: String, color: Color) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	parent.add_child(row)
	var name_label := Label.new()
	name_label.text = title
	name_label.theme_type_variation = &"DimLabel"
	name_label.custom_minimum_size = Vector2(96, 0)
	row.add_child(name_label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(320, 16)
	bar.show_percentage = false
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override(&"fill", fill)
	row.add_child(bar)
	var value := Label.new()
	value.theme_type_variation = &"MonoLabel"
	value.custom_minimum_size = Vector2(90, 0)
	row.add_child(value)
	return [bar, value]


func _process(delta: float) -> void:
	if sub == null:
		return
	var run := sub.run
	var depth := level.depth_at(sub.pos.y)
	_depth_label.text = "%s m" % UiUtil.thousands(int(depth))
	_hull_bar.max_value = sub.stats.max_hull
	_hull_bar.value = run.hull
	_hull_label.text = "%d" % ceili(run.hull)
	_battery_bar.max_value = sub.stats.max_battery
	_battery_bar.value = run.battery
	_battery_label.text = "%d" % ceili(run.battery)
	_power_alarm.visible = sub.power_failing > 0.0 and sub.alive
	if _power_alarm.visible:
		var left := maxf(Submarine.POWER_GRACE - sub.power_failing, 0.0)
		_power_alarm.text = "LIFE SUPPORT FAILING   %.0f" % ceilf(left)
		_power_alarm.modulate.a = 0.55 + 0.45 * absf(sin(sub.power_failing * 5.0))
	_shown_salvage = move_toward(_shown_salvage, run.salvage, maxf(40.0, absf(run.salvage - _shown_salvage) * 4.0) * delta)
	_salvage_label.text = "%d SALVAGE" % roundi(_shown_salvage)
	_research_label.text = "%d research" % run.research

	var tool := sub.tools.current()
	if tool == &"":
		_tool_label.text = "HARPOON"
		_tool_hint.text = "%s fire   %s sonar" % [Prompt.key(&"fire"), Prompt.key(&"ping")]
	else:
		var ammo := sub.tools.ammo(tool)
		var ammo_text := " x%d" % ammo if ammo >= 0 else "  %d power" % int(sub.stats.shock_cost)
		_tool_label.text = Catalog.TOOL_NAMES.get(tool, String(tool)).to_upper() + ammo_text
		_tool_hint.text = "%s use" % Prompt.key(&"tool")
		if sub.stats.tools.size() > 1:
			_tool_hint.text += "   %s cycle" % Prompt.key(&"cycle_tool")

	var guardian := level.guardian
	_boss_box.visible = is_instance_valid(guardian) and guardian.active
	if _boss_box.visible:
		_boss_name.text = guardian.title
		_boss_bar.max_value = guardian.max_hp
		_boss_bar.value = guardian.hp

	var low_hull := clampf(1.0 - run.hull / maxf(sub.stats.max_hull, 1.0) * 3.0, 0.0, 1.0)
	var mat := _vignette.material as ShaderMaterial
	_flash = maxf(_flash - delta * 2.5, 0.0)
	mat.set_shader_parameter(&"flash", _flash)
	mat.set_shader_parameter(&"danger", low_hull)
	_objective_label.visible = objective != null
	if objective:
		var status := "  -  DONE" if objective.done else ("  -  FAILED" if objective.failed else "")
		_objective_label.text = "OBJECTIVE: %s   %s%s" % [objective.describe(), objective.reward_text(), status]
		_objective_label.add_theme_color_override(&"font_color",
			UiTheme.GOOD if objective.done else (UiTheme.TEXT_DIM if objective.failed else UiTheme.WARN))
	_fps_label.visible = Settings.show_fps
	if Settings.show_fps:
		_fps_label.text = "%d fps" % Engine.get_frames_per_second()
	_overlay.queue_redraw()


func toast(text: String, color := UiTheme.TEXT, hold := 3.5) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_color_override(&"font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feed.add_child(label)
	while _feed.get_child_count() > 6:
		_feed.get_child(0).free()
	label.modulate.a = 0.0
	var tween := label.create_tween()
	tween.tween_property(label, ^"modulate:a", 1.0, 0.2)
	tween.tween_interval(hold)
	tween.tween_property(label, ^"modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)


func show_banner(title: String, subtitle: String) -> void:
	_banner_title.text = title
	_banner_sub.text = subtitle
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, ^"modulate:a", 1.0, 0.8)
	_banner_tween.tween_interval(3.0)
	_banner_tween.tween_property(_banner, ^"modulate:a", 0.0, 1.2)


func _on_damaged(amount: float) -> void:
	_flash = maxf(_flash, clampf(amount / 25.0, 0.35, 1.0) * (0.4 if Settings.reduce_flashing else 1.0))


func _on_scanned(id: StringName, first_time: bool) -> void:
	var entry := CreatureCodex.entry(id)
	var label_text := entry.name if entry else String(id)
	toast("Scanned: %s%s" % [label_text, "  (new codex entry)" if first_time else ""], UiTheme.ACCENT)
	# A first scan comes with a field note on how to handle the species.
	if first_time and DeathTips.TIPS.has(id):
		toast(DeathTips.tip(id), UiTheme.TEXT_DIM, 7.0)


## Anchors a control to a preset corner and offsets it from that anchor.
static func _place(c: Control, preset: Control.LayoutPreset, offset: Vector2, size: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + size.x
	c.offset_bottom = offset.y + size.y


static func _vignette_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float flash = 0.0;
uniform float danger = 0.0;
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float v = smoothstep(0.55, 1.45, length(uv * vec2(0.9, 1.0)));
	float pulse = 0.6 + 0.4 * sin(TIME * 5.0);
	float a = v * (0.35 + flash * 0.6 + danger * 0.45 * pulse);
	vec3 col = mix(vec3(0.0, 0.02, 0.04), vec3(0.6, 0.02, 0.0), clamp(flash + danger * pulse, 0.0, 1.0));
	COLOR = vec4(col, a);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat
