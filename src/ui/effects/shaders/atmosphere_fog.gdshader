shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 fog_color : source_color = vec4(0.06, 0.22, 0.29, 1.0);
uniform float density : hint_range(0.0, 0.5) = 0.055;
uniform float drift_speed : hint_range(0.0, 1.0) = 0.025;

float fog_noise(vec2 p) {
	return sin(p.x * 17.0 + sin(p.y * 9.0)) * 0.5 + 0.5;
}

void fragment() {
	vec2 uv = UV;
	float drift = TIME * drift_speed;
	float layer_a = fog_noise(vec2(uv.x + drift, uv.y) * 3.2);
	float layer_b = fog_noise(vec2(uv.x * 1.7 - drift * 0.6, uv.y * 2.1) * 2.3);
	float floor_mask = smoothstep(0.30, 1.0, uv.y);
	float alpha = (layer_a * 0.6 + layer_b * 0.4) * floor_mask * density;
	COLOR = vec4(fog_color.rgb, alpha * fog_color.a);
}
