class_name PostFx
extends CanvasLayer
## Screen-space underwater treatment between the 3D view and the HUD.
## Disabled on the Low quality preset.

var _rect: ColorRect
var _mat: ShaderMaterial
var _damage := 0.0


func _ready() -> void:
	layer = 1
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://src/fx/shaders/underwater_post.gdshader")
	_mat.set_shader_parameter(&"noise_tex", TerrainRenderer.detail_noise())
	_rect.material = _mat
	add_child(_rect)
	Settings.changed.connect(_apply_quality)
	Events.player_damaged.connect(func(amount: float) -> void: _damage = clampf(_damage + amount / 30.0, 0.0, 1.0))
	_apply_quality()


func _process(delta: float) -> void:
	_damage = maxf(_damage - delta * 1.5, 0.0)
	_mat.set_shader_parameter(&"damage", _damage)


func _apply_quality() -> void:
	visible = Settings.quality != Settings.Quality.LOW
