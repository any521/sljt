shader_type canvas_item;
uniform vec4 outline_color : source_color = vec4(0.42, 0.78, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 8.0) = 0.0;
uniform float pulse_speed = 7.85398;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform bool reduce_flashes = false;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec2 step_uv = TEXTURE_PIXEL_SIZE * outline_width;
	float edge = 0.0;
	edge = max(edge, texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a);
	edge = max(edge, texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a);
	edge = max(edge, texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a);
	edge = max(edge, texture(TEXTURE, UV + step_uv * 0.707).a);
	edge = max(edge, texture(TEXTURE, UV - step_uv * 0.707).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(step_uv.x, -step_uv.y) * 0.707).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(-step_uv.x, step_uv.y) * 0.707).a);
	float pulse = 0.70 + 0.30 * sin(TIME * pulse_speed);
	float border = max(0.0, edge - base.a) * step(0.01, outline_width) * outline_color.a;
	vec3 hit_color = reduce_flashes ? outline_color.rgb : vec3(1.0);
	base.rgb = mix(base.rgb, hit_color, flash_amount * (reduce_flashes ? 0.38 : 1.0));
	COLOR = vec4(mix(outline_color.rgb * pulse, base.rgb, base.a), max(base.a, border * pulse));
}
