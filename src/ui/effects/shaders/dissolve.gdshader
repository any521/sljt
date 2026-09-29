shader_type canvas_item;
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.62, 0.86, 1.0);
uniform sampler2D noise_texture;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	float cells = hash(floor(UV * vec2(84.0, 128.0)));
	float grain = mix(cells, hash(floor(UV * vec2(23.0, 37.0))), 0.35);
	float threshold = dissolve_amount * 1.15 - 0.08;
	float alive = step(threshold, grain);
	float edge = step(threshold, grain) - step(threshold + 0.075, grain);
	vec3 color = mix(source.rgb, edge_color.rgb, edge * edge_color.a);
	COLOR = vec4(color, source.a * alive);
}
