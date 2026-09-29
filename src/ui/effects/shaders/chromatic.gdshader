shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float aberration_amount : hint_range(0.0, 12.0) = 0.0;
void fragment() {
	vec2 delta = vec2(aberration_amount) * SCREEN_PIXEL_SIZE;
	float red = texture(screen_texture, SCREEN_UV + delta).r;
	float green = texture(screen_texture, SCREEN_UV).g;
	float blue = texture(screen_texture, SCREEN_UV - delta).b;
	COLOR = vec4(red, green, blue, 1.0);
}
