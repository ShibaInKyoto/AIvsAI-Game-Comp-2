// Glow-worms in a Midnight Caverns grotto (and the threads they hang): flat,
// unshaded light whose brightness each instance carries in INSTANCE_CUSTOM.r,
// so the grotto can dim worm by worm as sound ripples through it.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 glow_color : source_color = vec4(0.45, 1.0, 0.85, 1.0);
uniform float energy = 3.0;

varying float bright;

void vertex() {
	bright = INSTANCE_CUSTOM.r;
}

void fragment() {
	ALBEDO = glow_color.rgb * bright * energy;
}
