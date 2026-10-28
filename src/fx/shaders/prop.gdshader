// Instanced cave decoration (kelp, coral, crystals...). Vertex color RGB is
// the base albedo and A the glow mask. INSTANCE_CUSTOM: x = sway phase,
// y = tint blend, z = brightness, w = glow multiplier.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

#include "res://src/fx/shaders/sonar.gdshaderinc"

uniform vec3 tint_a : source_color = vec3(1.0);
uniform vec3 tint_b : source_color = vec3(1.0);
uniform vec4 glow_color : source_color = vec4(0.3, 1.0, 0.9, 1.0);
uniform float glow_strength = 0.0;
uniform float glow_pulse = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float sway = 0.0;
uniform float sway_speed = 1.0;
uniform float height = 4.0;
// 1 = crystal: flat-shaded facets whose glow varies per face, so a strongly
// emissive gem still reads as a faceted solid rather than a flat silhouette.
uniform float facet = 0.0;

varying vec3 world_pos;
varying float phase;
varying vec4 custom;

void vertex() {
	custom = INSTANCE_CUSTOM;
	phase = INSTANCE_CUSTOM.x * 6.2831;
	float h = clamp(VERTEX.y / height, 0.0, 1.0);
	float s = sway * h * h;
	VERTEX.x += sin(TIME * sway_speed + phase + VERTEX.y * 0.45) * s;
	VERTEX.z += cos(TIME * sway_speed * 0.77 + phase * 1.3 + VERTEX.y * 0.3) * s * 0.6;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = NORMAL;
	float face_light = 1.0;
	if (facet > 0.0) {
		n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
		n = dot(n, VIEW) < 0.0 ? -n : n;
		NORMAL = n;
		face_light = mix(1.0, 0.2 + 0.9 * abs(dot(n, normalize(vec3(0.45, 0.8, 0.4)))), facet);
	}
	vec3 tint = mix(tint_a, tint_b, custom.y);
	ALBEDO = COLOR.rgb * tint * custom.z;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	float pulse = 1.0 + glow_pulse * sin(TIME * 1.7 + phase);
	float fres = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 2.0);
	vec3 emission = glow_color.rgb * COLOR.a * glow_strength * custom.w * pulse;
	emission *= mix(1.0, face_light + fres * 0.8, facet);
	vec2 sonar = sonar_sample(world_pos.xy);
	emission += sonar_color.rgb * (sonar.x * 2.0 + sonar.y * 0.4) * (0.3 + fres);
	EMISSION = emission;
}
