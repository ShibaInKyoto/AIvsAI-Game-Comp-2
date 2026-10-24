// Cave terrain: a flat grid extruded into a relief by the level's signed
// distance field. Rock (negative distance) rises towards the camera, open
// water recedes into a deep back wall, and the boundary where the relief
// crosses z = 0 is exactly the gameplay collision surface.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://src/fx/shaders/sonar.gdshaderinc"

uniform sampler2D sdf_tex : filter_linear, repeat_disable;
uniform vec2 field_size = vec2(100.0, 200.0);
uniform vec2 texel_count = vec2(201.0, 401.0);
uniform float rock_height = 4.5;
uniform float back_depth = 10.0;
// Grid spacing of the chunk mesh; used to snap vertices onto the cave outline.
uniform float grid_step = 0.4;

uniform sampler2D detail_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_rough : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec3 rock_tint : source_color = vec3(0.5);
uniform vec3 rock_tint_deep : source_color = vec3(0.3);
uniform vec3 sediment_tint : source_color = vec3(0.7, 0.65, 0.5);
uniform vec3 vein_color : source_color = vec3(0.0);
uniform float vein_strength = 0.0;
uniform float caustics = 0.0;
uniform float tex_scale = 0.11;

varying vec3 world_pos;
varying vec3 world_normal;
varying float sdf_value;

float field(vec2 wp) {
	vec2 uv = vec2(wp.x, -wp.y) / field_size;
	uv = uv * (texel_count - 1.0) / texel_count + 0.5 / texel_count;
	return textureLod(sdf_tex, uv, 0.0).r;
}

float relief(vec2 wp) {
	float s = field(wp);
	float n = textureLod(detail_noise, wp * 0.021, 0.0).r - 0.5;
	float n2 = textureLod(detail_noise, wp * 0.083 + vec2(0.37, 0.71), 0.0).r - 0.5;
	if (s < 0.0) {
		float t = tanh(-s / 2.0);
		return t * (rock_height + (n * 4.0 + n2 * 0.8) * t * t);
	}
	float t = tanh(s / 2.4);
	float deep = back_depth + clamp(s - 4.0, 0.0, 12.0) * 0.35;
	return -t * (deep + (n * 4.0 + n2 * 0.8) * t * t);
}

vec2 field_gradient(vec2 wp) {
	float e = 0.25;
	return vec2(field(wp + vec2(e, 0.0)) - field(wp - vec2(e, 0.0)),
		field(wp + vec2(0.0, e)) - field(wp - vec2(0.0, e))) / (2.0 * e);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Pull vertices near the outline onto it so cliffs do not staircase.
	float s0 = field(wp.xy);
	float band = grid_step * 1.6;
	if (abs(s0) < band) {
		vec2 g = field_gradient(wp.xy);
		float gl = length(g);
		if (gl > 0.2) {
			float w = 0.85 * (1.0 - smoothstep(0.0, band, abs(s0)));
			vec2 shift = -(g / gl) * (s0 / gl) * w;
			VERTEX.xy += shift;
			wp.xy += shift;
		}
	}
	float e = 0.3;
	float h = relief(wp.xy);
	float hx = relief(wp.xy + vec2(e, 0.0)) - relief(wp.xy - vec2(e, 0.0));
	float hy = relief(wp.xy + vec2(0.0, e)) - relief(wp.xy - vec2(0.0, e));
	VERTEX.z = h;
	vec3 n = normalize(vec3(-hx / (2.0 * e), -hy / (2.0 * e), 1.0));
	NORMAL = n;
	world_normal = n;
	sdf_value = field(wp.xy);
	world_pos = vec3(wp.xy, h);
}

vec3 unpack_normal(vec4 c) {
	return c.xyz * 2.0 - 1.0;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 blend = pow(abs(n), vec3(4.0));
	blend /= dot(blend, vec3(1.0));
	vec2 uv_x = world_pos.zy * tex_scale;
	vec2 uv_y = world_pos.xz * tex_scale;
	vec2 uv_z = world_pos.xy * tex_scale;

	vec3 alb = texture(rock_albedo, uv_x).rgb * blend.x
		+ texture(rock_albedo, uv_y).rgb * blend.y
		+ texture(rock_albedo, uv_z).rgb * blend.z;
	float rough = texture(rock_rough, uv_x).r * blend.x
		+ texture(rock_rough, uv_y).r * blend.y
		+ texture(rock_rough, uv_z).r * blend.z;

	// Triplanar normal mapping (UDN blend).
	vec3 tnx = unpack_normal(texture(rock_normal, uv_x));
	vec3 tny = unpack_normal(texture(rock_normal, uv_y));
	vec3 tnz = unpack_normal(texture(rock_normal, uv_z));
	tnx = vec3(tnx.xy + n.zy, n.x);
	tny = vec3(tny.xy + n.xz, n.y);
	tnz = vec3(tnz.xy + n.xy, n.z);
	vec3 rock_n = normalize(tnx.zyx * blend.x + tny.xzy * blend.y + tnz.xyz * blend.z);

	// Desaturate the photo texture and tint it per biome; the back wall uses
	// the deep tint so the playable layer reads clearly in front of it.
	float lum = dot(alb, vec3(0.299, 0.587, 0.114));
	vec3 base = mix(vec3(lum), alb, 0.25) * 1.6;
	float front = smoothstep(-back_depth * 0.8, 1.0, world_pos.z);
	vec3 tint = mix(rock_tint_deep, rock_tint, front);
	vec3 color = base * tint;

	// Sediment settles on upward-facing slopes.
	float noise_a = texture(detail_noise, world_pos.xy * 0.05).r;
	float sediment = smoothstep(0.4, 0.75, n.y + (noise_a - 0.5) * 0.6) * smoothstep(-back_depth, -1.0, world_pos.z);
	vec3 sand_tex = texture(sand_albedo, uv_y * 1.6).rgb;
	vec3 sand = mix(vec3(dot(sand_tex, vec3(0.333))), sand_tex, 0.3) * sediment_tint * 1.2;
	vec3 sand_n = unpack_normal(texture(sand_normal, uv_y * 1.6));
	sand_n = normalize(vec3(sand_n.xy + n.xz, n.y).xzy);
	color = mix(color, sand, sediment);
	vec3 final_n = normalize(mix(rock_n, sand_n, sediment));

	// Cavity darkening on the back wall.
	float cavity = mix(0.45, 1.0, smoothstep(-back_depth - 2.0, 0.5, world_pos.z));
	ALBEDO = color * cavity;
	ROUGHNESS = mix(clamp(rough * 1.1, 0.55, 1.0), 0.95, sediment);
	SPECULAR = 0.35;
	NORMAL = normalize((VIEW_MATRIX * vec4(final_n, 0.0)).xyz);

	vec3 emission = vec3(0.0);

	// Glowing mineral veins (vents, midnight, hadal).
	if (vein_strength > 0.0) {
		float v = texture(detail_noise, world_pos.xy * 0.02 + vec2(0.13, 0.4)).r;
		float ridge = 1.0 - abs(v * 2.0 - 1.0);
		float spots = texture(detail_noise, world_pos.xy * 0.11 + vec2(0.71, 0.2)).r;
		float vein = smoothstep(0.86, 0.97, ridge) * smoothstep(0.45, 0.75, spots);
		vein *= smoothstep(-1.0, 1.5, world_pos.z) * (0.4 + 0.6 * (1.0 - abs(n.z)));
		float pulse = 0.7 + 0.3 * sin(TIME * 0.6 + world_pos.x * 0.15 + world_pos.y * 0.1);
		emission += vein_color * vein * vein_strength * pulse * 1.6;
	}

	// Animated caustics from the surface, mostly on upward faces.
	if (caustics > 0.0) {
		vec2 cp = world_pos.xy * 0.035 + vec2(world_pos.z * 0.02, 0.0);
		float c1 = texture(detail_noise, cp + vec2(TIME * 0.011, TIME * 0.007)).r;
		float c2 = texture(detail_noise, cp * 1.21 - vec2(TIME * 0.009, -TIME * 0.01)).r;
		float web = pow(1.0 - abs(c1 - c2), 9.0);
		float facing = clamp(n.y * 0.9 + n.z * 0.3, 0.0, 1.0) * smoothstep(-4.0, 2.0, world_pos.z);
		emission += vec3(0.6, 0.9, 1.0) * web * caustics * facing * 0.35 * color;
	}

	// Sonar: a bright wavefront, then a fading contour map of the walls.
	vec2 sonar = sonar_sample(world_pos.xy);
	if (sonar.x + sonar.y > 0.001) {
		float wall = 1.0 - abs(n.z);
		float contour = smoothstep(0.82, 1.0, abs(fract(world_pos.z * 0.6) * 2.0 - 1.0));
		float grid = max(smoothstep(0.94, 1.0, abs(fract(world_pos.x * 0.25) * 2.0 - 1.0)),
			smoothstep(0.94, 1.0, abs(fract(world_pos.y * 0.25) * 2.0 - 1.0))) * step(world_pos.z, -2.0);
		float edge = smoothstep(1.5, 0.0, abs(sdf_value)) ;
		float lines = wall * 0.6 + contour * 0.5 + grid * 0.25 + edge * 1.4;
		emission += sonar_color.rgb * (sonar.x * (1.5 + lines * 2.0) + sonar.y * lines * 0.9);
	}
	EMISSION = emission;
}
