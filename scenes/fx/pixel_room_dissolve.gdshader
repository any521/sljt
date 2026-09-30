shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float pixel_size : hint_range(8.0, 64.0) = 24.0;
uniform vec2 design_size = vec2(1920.0, 1080.0);
uniform vec4 shadow_color : source_color = vec4(0.018, 0.035, 0.055, 1.0);
uniform vec4 edge_color : source_color = vec4(0.17, 0.48, 0.62, 1.0);

void fragment() {
	vec2 cell = floor(UV * design_size / pixel_size);
	float noise = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	float order = noise * 0.58 + (1.0 - UV.y) * 0.42;
	float phase = mix(-0.12, 1.12, progress);
	float alpha = smoothstep(order - 0.075, order + 0.075, phase);
	float rim = smoothstep(order - 0.11, order, phase) - smoothstep(order, order + 0.11, phase);
	vec3 color = mix(shadow_color.rgb, edge_color.rgb, rim * 0.25);
	COLOR = vec4(color, alpha * shadow_color.a);
}
