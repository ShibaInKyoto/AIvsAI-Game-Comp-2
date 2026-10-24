// An expanding wave of the Choir's song: a thin bright ring on a quad whose
// UV radius 1.0 maps to the wave front.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 ring_color : source_color = vec4(1.0, 0.3, 0.9, 1.0);
uniform float intensity = 2.0;
uniform float thickness = 0.03;

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float band = exp(-pow((r - 0.97) / thickness, 2.0));
	float inner = smoothstep(0.6, 0.97, r) * 0.12;
	float ripple = 0.75 + 0.25 * sin(atan(UV.y - 0.5, UV.x - 0.5) * 24.0 + TIME * 3.0);
	ALBEDO = ring_color.rgb;
	ALPHA = clamp((band * ripple + inner) * intensity * ring_color.a, 0.0, 1.0);
}
