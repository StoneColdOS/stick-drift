shader_type spatial;
// City buildings: gritty concrete (world-space triplanar grit, like the rest of the game),
// optional glow for windows and neon, and an "x-ray" cutaway: anything between the camera and
// the car, inside a circle around the car on screen, is cut out with a dithered edge, so tall
// buildings never hide the car.

uniform vec4 albedo : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform sampler2D grit : source_color, filter_linear_mipmap, repeat_enable;
uniform float grit_scale = 0.3;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;

global uniform vec2 car_screen;   // car position in screen UV (0..1)
global uniform float car_depth;   // distance from the camera to the car along the view
global uniform float cut_radius;  // circle radius, as a fraction of screen height

varying vec3 world_pos;
varying vec3 world_normal;

float bayer4(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int x = q.x;
	int y = q.y;
	int a = (x ^ y) & 1;
	int b = x & 1;
	int c = ((x ^ y) >> 1) & 1;
	int d = (x >> 1) & 1;
	return (float(a * 8 + b * 4 + c * 2 + d) + 0.5) / 16.0;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	float depth = -VERTEX.z;
	if (depth < car_depth - 2.0) {
		vec2 d = (SCREEN_UV - car_screen) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
		float r = length(d);
		if (r < cut_radius) {
			// Solid hole in the middle, dithered rim.
			float keep = smoothstep(cut_radius * 0.75, cut_radius, r);
			if (keep < bayer4(FRAGCOORD.xy)) {
				discard;
			}
		}
	}
	vec3 w = abs(world_normal);
	w /= (w.x + w.y + w.z);
	vec3 g = texture(grit, world_pos.zy * grit_scale).rgb * w.x
		+ texture(grit, world_pos.xz * grit_scale).rgb * w.y
		+ texture(grit, world_pos.xy * grit_scale).rgb * w.z;
	ALBEDO = albedo.rgb * g;
	ROUGHNESS = 0.9;
	EMISSION = emission_color * emission_energy;
}
