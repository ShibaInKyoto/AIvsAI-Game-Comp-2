// Shared creature material. Bodies are modelled along +X (head) with vertex
// color R as a bioluminescence mask and G as a belly/back blend. The vertex
// stage adds a travelling swim wave; instance uniforms carry per-creature
// state (sonar mark, hit flash, swim phase) so one material serves a species.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://src/fx/shaders/sonar.gdshaderinc"

uniform vec4 back_color : source_color = vec4(0.3, 0.35, 0.4, 1.0);
uniform vec4 belly_color : source_color = vec4(0.7, 0.75, 0.8, 1.0);
uniform vec4 glow_color : source_color = vec4(0.3, 1.0, 0.9, 1.0);
uniform float glow_strength = 2.0;
uniform float glow_pulse = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.45;
uniform float metallic : hint_range(0.0, 1.0) = 0.1;
uniform float rim_strength = 0.3;
uniform float body_length = 2.0;
uniform float swim_amp = 0.12;
uniform float swim_freq = 7.0;
uniform float swim_wave = 2.5;
// 0 = wag laterally (fish), 1 = undulate vertically (rays, eels seen side-on).
uniform float swim_vertical = 0.25;

instance uniform float marked = 0.0;
instance uniform float hit_flash = 0.0;
instance uniform float phase = 0.0;
// Swim cycles so far, advanced each frame by how fast the creature swims
// (accumulated on the CPU so a change of pace never makes the stroke jump).
instance uniform float swim_clock = 0.0;
instance uniform float glow_boost = 1.0;

varying vec3 world_pos;

void vertex() {
	float x = VERTEX.x / max(body_length, 0.01);
	float tail = smoothstep(0.35, -0.55, x);
	// INSTANCE_CUSTOM.x carries a per-fish phase when drawn through a MultiMesh.
	float w = sin(swim_clock * swim_freq + phase + INSTANCE_CUSTOM.x * 6.28 - VERTEX.x * swim_wave);
	VERTEX.z += w * swim_amp * tail * (1.0 - swim_vertical);
	VERTEX.y += w * swim_amp * tail * swim_vertical;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = mix(back_color.rgb, belly_color.rgb, COLOR.g);
	ALBEDO = base;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	RIM = rim_strength;
	RIM_TINT = 0.5;
	float pulse = 1.0 + glow_pulse * sin(TIME * 2.3 + phase * 3.0);
	vec3 emission = glow_color.rgb * COLOR.r * glow_strength * pulse * glow_boost;

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	vec2 sonar = sonar_sample(world_pos.xy);
	emission += sonar_color.rgb * (sonar.x * 4.0 * (0.4 + fres) + marked * fres * 1.6);
	emission += vec3(1.0, 0.85, 0.8) * hit_flash * 2.5;
	EMISSION = emission;
}
