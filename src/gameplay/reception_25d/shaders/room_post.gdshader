shader_type canvas_item;
// Post effect for the 3D room image (RoomView). Only the 3D world uses it: speech, HUD and
// consultations are drawn above it in the 2D canvas and stay sharp.

uniform float vignette : hint_range(0.0, 1.5) = 0.35;
uniform float grain : hint_range(0.0, 0.3) = 0.03;
uniform float aberration : hint_range(0.0, 6.0) = 0.0; // in screen pixels
uniform float distortion : hint_range(0.0, 1.0) = 0.0; // wavy "something's off" warp
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float red_pulse : hint_range(0.0, 1.0) = 0.0;
uniform float time_offset = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME + time_offset;
	if (distortion > 0.0) {
		uv.x += sin(uv.y * 38.0 + t * 7.0) * 0.004 * distortion;
		uv.y += sin(uv.x * 23.0 - t * 5.0) * 0.003 * distortion;
	}
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 dir = (uv - 0.5);
	vec4 col;
	if (aberration > 0.0) {
		vec2 off = dir * px * aberration * 2.0;
		col.r = texture(TEXTURE, uv + off).r;
		col.g = texture(TEXTURE, uv).g;
		col.b = texture(TEXTURE, uv - off).b;
		col.a = 1.0;
	} else {
		col = texture(TEXTURE, uv);
	}
	col.rgb *= tint.rgb;
	// Vignette: darker corners, a little red when pulsing.
	float d = length(dir * vec2(1.0, 0.78));
	float v = smoothstep(0.35, 0.95, d) * vignette;
	col.rgb = mix(col.rgb, vec3(0.06 * red_pulse, 0.0, 0.0), clamp(v, 0.0, 1.0));
	col.rgb += vec3(0.18, 0.0, 0.0) * red_pulse * smoothstep(0.2, 0.9, d);
	// Film grain.
	float n = hash(floor(UV / px) + floor(t * 24.0)) - 0.5;
	col.rgb += n * grain;
	COLOR = vec4(col.rgb, 1.0);
}
