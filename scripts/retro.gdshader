shader_type canvas_item;
// Retro colour pass over the low-res world: a touch of ordered dithering and colour
// quantization (like old consoles), plus a soft vignette. Subtle on purpose.

uniform float levels = 28.0;     // colour steps per channel
uniform float dither_amount = 1.0;
uniform float vignette = 0.35;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	ivec2 px = ivec2(UV / TEXTURE_PIXEL_SIZE);
	float threshold = BAYER[(px.y % 4) * 4 + (px.x % 4)] / 16.0 - 0.5;
	vec3 col = c.rgb + threshold * dither_amount / levels;
	col = floor(col * levels + 0.5) / levels;
	vec2 d = UV - 0.5;
	col *= 1.0 - vignette * dot(d, d) * 1.6;
	COLOR = vec4(col, 1.0);
}
