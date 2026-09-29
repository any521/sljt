shader_type canvas_item;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform bool reduce_flashes = false;
uniform vec4 flash_color : source_color = vec4(1.0);
void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	vec3 target = reduce_flashes ? vec3(0.42, 0.78, 1.0) : flash_color.rgb;
	COLOR = vec4(mix(source.rgb, target, flash_amount * (reduce_flashes ? 0.35 : 1.0)), source.a);
}
