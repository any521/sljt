shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float corruption_amount : hint_range(0.0, 1.0) = 0.0;
uniform float overlay_alpha : hint_range(0.0, 1.0) = 0.0;
uniform float distortion : hint_range(0.0, 0.02) = 0.0;
uniform sampler2D vein_texture;

float veins(vec2 p) {
	float a = abs(sin(p.x * 31.0 + sin(p.y * 17.0 + TIME * 0.45) * 3.0));
	float b = abs(sin(p.y * 43.0 - sin(p.x * 13.0 - TIME * 0.31) * 4.0));
	return smoothstep(0.92, 0.985, max(a, b));
}

void fragment() {
	vec2 centered = UV - 0.5;
	float edge = smoothstep(0.18, 0.72, length(centered * vec2(1.0, 0.78)));
	float v = veins(UV + vec2(sin(TIME * 0.23), cos(TIME * 0.19)) * 0.02);
	vec2 warp = vec2(sin(UV.y * 38.0 + TIME * 1.5), cos(UV.x * 31.0 - TIME)) * distortion * edge;
	vec4 scene = textureLod(screen_texture, SCREEN_UV + warp, 0.0);
	vec3 organic = mix(vec3(0.14, 0.025, 0.11), vec3(0.78, 0.28, 0.62), v);
	float mask = edge * (0.15 + v * 0.85) * overlay_alpha * corruption_amount;
	COLOR = vec4(mix(scene.rgb, organic, mask), 1.0);
}
