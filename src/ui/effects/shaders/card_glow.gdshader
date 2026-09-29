shader_type canvas_item;
uniform vec4 glow_color : source_color = vec4(0.42, 0.78, 1.0, 1.0);
uniform float glow_strength : hint_range(0.0, 2.0) = 0.0;
void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	vec3 glow = glow_color.rgb * glow_strength * (0.75 + 0.25 * sin(TIME * 7.0));
	COLOR = vec4(source.rgb + glow * source.a, source.a);
}
