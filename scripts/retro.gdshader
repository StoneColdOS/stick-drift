shader_type canvas_item;
// Retro colour pass over the low-res world: light ordered dithering and colour quantization
// (like old consoles), plus a soft vignette. Kept subtle so motion stays smooth.

uniform float levels = 40.0;      // colour steps per channel
uniform float dither_amount = 0.6;
uniform float vignette = 0.3;

float bayer4(ivec2 p) {
	// 4x4 Bayer matrix without array lookups (fast on phones).
	int x = p.x & 3;
	int y = p.y & 3;
	int a = (x ^ y) & 1;
	int b = (x & 1);
	int c = ((x ^ y) >> 1) & 1;
	int d = (x >> 1) & 1;
	return float(a * 8 + b * 4 + c * 2 + d) / 16.0;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	ivec2 px = ivec2(UV / TEXTURE_PIXEL_SIZE);
	float threshold = bayer4(px) - 0.5;
	vec3 col = c.rgb + threshold * dither_amount / levels;
	col = floor(col * levels + 0.5) / levels;
	vec2 d = UV - 0.5;
	col *= 1.0 - vignette * dot(d, d) * 1.6;
	COLOR = vec4(col, 1.0);
}
