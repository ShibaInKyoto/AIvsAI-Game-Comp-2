// Shared sonar ping evaluation. Pings are pushed by SonarSystem into global
// uniforms: xy = origin (world), z = start time (sonar_time clock), w = range.
global uniform vec4 sonar_ping0;
global uniform vec4 sonar_ping1;
global uniform vec4 sonar_ping2;
global uniform vec4 sonar_ping3;
global uniform float sonar_time;
global uniform vec4 sonar_color : source_color;

const float SONAR_SPEED = 42.0;
const float SONAR_LIFE = 6.0;

// Returns (wavefront, lingering reveal) for one ping at world point p.
vec2 sonar_eval(vec4 ping, vec2 p) {
	float age = sonar_time - ping.z;
	if (age < 0.0 || age > SONAR_LIFE) {
		return vec2(0.0);
	}
	float d = distance(p, ping.xy);
	float radius = age * SONAR_SPEED;
	float range_fade = 1.0 - smoothstep(ping.w * 0.7, ping.w, d);
	float front = exp(-pow((d - radius) / 1.1, 2.0)) * range_fade;
	float since = age - d / SONAR_SPEED;
	float reveal = step(0.0, since) * range_fade * exp(-since * 0.7);
	return vec2(front, reveal) * (1.0 - age / SONAR_LIFE);
}

vec2 sonar_sample(vec2 p) {
	return sonar_eval(sonar_ping0, p) + sonar_eval(sonar_ping1, p)
		+ sonar_eval(sonar_ping2, p) + sonar_eval(sonar_ping3, p);
}
