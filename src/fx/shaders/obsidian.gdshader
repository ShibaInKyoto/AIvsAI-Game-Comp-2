// Volcanic glass (the Abyssal Vents' singing glass): near-black, glossy faces
// whose edges glow with [code]glow_color[/code] where they turn away from the
// camera, the whole crystal lighting from within as [code]ring[/code] rises.
shader_type spatial;
render_mode cull_back;

uniform vec4 glow_color : source_color = vec4(0.72, 0.55, 1.0, 1.0);
uniform float ring = 0.0;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float edge = pow(1.0 - facing, 4.0);
	ALBEDO = vec3(0.025, 0.02, 0.035);
	ROUGHNESS = 0.07;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	EMISSION = glow_color.rgb * (edge * (0.08 + 1.4 * ring) + ring * (0.1 + 0.3 * facing));
}
