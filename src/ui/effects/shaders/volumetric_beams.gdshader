shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 beam_color : source_color = vec4(0.18, 0.62, 0.85, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.10;
uniform float beam_width : hint_range(0.02, 0.5) = 0.16;
uniform float beam_angle : hint_range(-1.0, 1.0) = -0.18;
uniform float falloff : hint_range(0.2, 5.0) = 1.8;
uniform float motion_speed : hint_range(0.0, 2.0) = 0.08;

void fragment() {
	vec2 uv = UV;
	float shifted_x = uv.x + beam_angle * (uv.y - 0.5);
	float bands = 0.55 + 0.45 * sin(shifted_x * 31.0 + TIME * motion_speed);
	float shafts = smoothstep(1.0 - beam_width, 1.0, bands);
	float vertical_fade = pow(max(0.0, 1.0 - uv.y), falloff);
	float edge_fade = smoothstep(0.0, 0.18, uv.x) * smoothstep(0.0, 0.18, 1.0 - uv.x);
	float alpha = shafts * vertical_fade * edge_fade * intensity;
	COLOR = vec4(beam_color.rgb, alpha * beam_color.a);
}
