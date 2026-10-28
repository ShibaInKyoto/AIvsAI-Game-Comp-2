class_name UiTheme
extends RefCounted
## Builds the game's UI theme in code: deep-sea glass panels with a sonar-cyan
## accent. Applied to the root window at startup.

const ACCENT := Color(0.3, 0.95, 1.0)
const ACCENT_DIM := Color(0.3, 0.95, 1.0, 0.35)
const TEXT := Color(0.86, 0.95, 1.0)
const TEXT_DIM := Color(0.55, 0.7, 0.78)
const WARN := Color(1.0, 0.72, 0.25)
const DANGER := Color(1.0, 0.32, 0.28)
const GOOD := Color(0.45, 1.0, 0.6)
const PANEL_BG := Color(0.01, 0.05, 0.08, 0.88)

const BODY_FONT := preload("res://assets/fonts/ChakraPetch-Medium.ttf")
const BOLD_FONT := preload("res://assets/fonts/ChakraPetch-SemiBold.ttf")
const MONO_FONT := preload("res://assets/fonts/ShareTechMono-Regular.ttf")
const TITLE_FONT_FILE := preload("res://assets/fonts/Oxanium-Variable.ttf")

static var _theme: Theme
static var _title_font: FontVariation


static func title_font() -> FontVariation:
	if _title_font == null:
		_title_font = FontVariation.new()
		_title_font.base_font = TITLE_FONT_FILE
		var ts := TextServerManager.get_primary_interface()
		_title_font.variation_opentype = {ts.name_to_tag("wght"): 700}
	return _title_font


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func panel_style(bg := PANEL_BG, border := ACCENT_DIM, width := 1, radius := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(14)
	s.anti_aliasing = true
	return s


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = BODY_FONT
	t.default_font_size = 22

	t.set_color(&"font_color", &"Label", TEXT)
	t.set_color(&"font_shadow_color", &"Label", Color(0, 0, 0, 0.6))
	t.set_constant(&"shadow_offset_x", &"Label", 1)
	t.set_constant(&"shadow_offset_y", &"Label", 2)

	t.set_type_variation(&"TitleLabel", &"Label")
	t.set_font(&"font", &"TitleLabel", title_font())
	t.set_font_size(&"font_size", &"TitleLabel", 64)
	t.set_color(&"font_color", &"TitleLabel", TEXT)

	t.set_type_variation(&"HeaderLabel", &"Label")
	t.set_font(&"font", &"HeaderLabel", title_font())
	t.set_font_size(&"font_size", &"HeaderLabel", 30)
	t.set_color(&"font_color", &"HeaderLabel", ACCENT)

	t.set_type_variation(&"MonoLabel", &"Label")
	t.set_font(&"font", &"MonoLabel", MONO_FONT)
	t.set_font_size(&"font_size", &"MonoLabel", 22)

	t.set_type_variation(&"DimLabel", &"Label")
	t.set_color(&"font_color", &"DimLabel", TEXT_DIM)
	t.set_font_size(&"font_size", &"DimLabel", 18)

	var normal := panel_style(Color(0.02, 0.09, 0.13, 0.9), ACCENT_DIM, 2, 4)
	normal.set_content_margin_all(10)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.05, 0.2, 0.26, 0.95)
	hover.border_color = ACCENT
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.1, 0.35, 0.42, 1.0)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.02, 0.05, 0.07, 0.7)
	disabled.border_color = Color(0.3, 0.4, 0.45, 0.3)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(1, 1, 1, 0.85)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(4)
	focus.set_expand_margin_all(3)
	t.set_stylebox(&"normal", &"Button", normal)
	t.set_stylebox(&"hover", &"Button", hover)
	t.set_stylebox(&"pressed", &"Button", pressed)
	t.set_stylebox(&"hover_pressed", &"Button", pressed)
	t.set_stylebox(&"disabled", &"Button", disabled)
	t.set_stylebox(&"focus", &"Button", focus)
	t.set_color(&"font_color", &"Button", TEXT)
	t.set_color(&"font_hover_color", &"Button", Color.WHITE)
	t.set_color(&"font_pressed_color", &"Button", Color.WHITE)
	t.set_color(&"font_focus_color", &"Button", Color.WHITE)
	t.set_color(&"font_disabled_color", &"Button", Color(0.5, 0.6, 0.65, 0.6))
	t.set_font(&"font", &"Button", BOLD_FONT)
	t.set_font_size(&"font_size", &"Button", 24)

	t.set_stylebox(&"panel", &"Panel", panel_style())
	t.set_stylebox(&"panel", &"PanelContainer", panel_style())

	var bar_bg := panel_style(Color(0.0, 0.03, 0.05, 0.8), Color(0.3, 0.9, 1.0, 0.25), 1, 3)
	bar_bg.set_content_margin_all(0)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = ACCENT
	bar_fill.set_corner_radius_all(2)
	t.set_stylebox(&"background", &"ProgressBar", bar_bg)
	t.set_stylebox(&"fill", &"ProgressBar", bar_fill)
	t.set_color(&"font_color", &"ProgressBar", TEXT)
	t.set_font_size(&"font_size", &"ProgressBar", 14)

	var slider := StyleBoxFlat.new()
	slider.bg_color = Color(0.1, 0.25, 0.3, 0.9)
	slider.set_corner_radius_all(3)
	slider.content_margin_top = 4
	slider.content_margin_bottom = 4
	var slider_fill := slider.duplicate() as StyleBoxFlat
	slider_fill.bg_color = ACCENT
	t.set_stylebox(&"slider", &"HSlider", slider)
	t.set_stylebox(&"grabber_area", &"HSlider", slider_fill)
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", slider_fill)

	t.set_stylebox(&"normal", &"OptionButton", normal)
	t.set_stylebox(&"hover", &"OptionButton", hover)
	t.set_stylebox(&"pressed", &"OptionButton", pressed)
	t.set_stylebox(&"focus", &"OptionButton", focus)
	t.set_stylebox(&"panel", &"PopupMenu", panel_style(Color(0.02, 0.07, 0.1, 0.98)))
	t.set_color(&"font_color", &"PopupMenu", TEXT)
	t.set_color(&"font_hover_color", &"PopupMenu", Color.WHITE)
	t.set_stylebox(&"hover", &"PopupMenu", hover)

	t.set_stylebox(&"normal", &"CheckBox", StyleBoxEmpty.new())
	t.set_stylebox(&"hover", &"CheckBox", StyleBoxEmpty.new())
	t.set_stylebox(&"pressed", &"CheckBox", StyleBoxEmpty.new())
	t.set_stylebox(&"focus", &"CheckBox", focus)
	t.set_color(&"font_color", &"CheckBox", TEXT)
	# The engine's default boxes are tiny and an empty one vanishes on the dark panels.
	t.set_icon(&"checked", &"CheckBox", _box_icon(true))
	t.set_icon(&"unchecked", &"CheckBox", _box_icon(false))

	var scroll := StyleBoxFlat.new()
	scroll.bg_color = Color(0.3, 0.9, 1.0, 0.4)
	scroll.set_corner_radius_all(3)
	t.set_stylebox(&"grabber", &"VScrollBar", scroll)
	t.set_stylebox(&"grabber_highlight", &"VScrollBar", scroll)
	t.set_stylebox(&"grabber_pressed", &"VScrollBar", scroll)
	t.set_stylebox(&"scroll", &"VScrollBar", StyleBoxEmpty.new())

	t.set_color(&"default_color", &"RichTextLabel", TEXT)
	t.set_font(&"bold_font", &"RichTextLabel", BOLD_FONT)
	t.set_font(&"mono_font", &"RichTextLabel", MONO_FONT)
	t.set_font_size(&"normal_font_size", &"RichTextLabel", 20)
	t.set_font_size(&"bold_font_size", &"RichTextLabel", 20)
	return t


## A square outline in the accent color, filled when [param checked].
static func _box_icon(checked: bool) -> ImageTexture:
	var size := 26
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var edge := x < 2 or y < 2 or x >= size - 2 or y >= size - 2
			var inner := x >= 6 and y >= 6 and x < size - 6 and y < size - 6
			img.set_pixel(x, y, ACCENT if edge or (checked and inner) else Color(0.0, 0.0, 0.0, 0.0))
	return ImageTexture.create_from_image(img)
