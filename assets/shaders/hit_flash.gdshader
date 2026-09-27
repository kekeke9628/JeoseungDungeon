shader_type canvas_item;
// Blends a sprite toward flash_color by `flash` (0 = as drawn, 1 = solid colour),
// keeping its alpha. Actor tweens `flash` down after a hit for a white-out blink.

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(c.rgb, flash_color.rgb, flash), c.a);
}
