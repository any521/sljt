shader_type canvas_item;
uniform vec4 vignette_color : source_color = vec4(0.92, 0.38, 0.38, 1.0);
uniform float intensity : hint_range(0.0, 1.5) = 0.0;
void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.0, 0.78);
	float edge = smoothstep(0.24, 0.68, length(p));
	float scan = 0.92 + 0.08 * sin(UV.y * 900.0);
	COLOR = vec4(vignette_color.rgb, edge * intensity * scan * 0.78);
}
