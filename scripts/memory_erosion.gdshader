shader_type canvas_item;
render_mode unshaded;
// Memory unravelling over the room canvas, on the art-pixel grid.
// Technique refs (godotshaders.com, MIT): "Pixel melting and falling" (reverse search for the
// pixel that lands here), "2D vertical pixel dissolving wave", "Turn to dust dissolve".

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 art_size = vec2(270.0, 330.0);
uniform float px = 2.0;                               // device pixels per art pixel
uniform vec4 region = vec4(0.0, 18.0, 108.0, 195.0);  // art px: x, y, w, h
uniform vec2 origin = vec2(52.0, 168.0);              // where unravelling starts (art px)
uniform float progress = 0.0;                         // 0..1 over DUR seconds
uniform float dim = 0.0;                              // brief whole-room light dip
uniform float motion = 1.0;                           // 0 = reduce motion

const float DUR = 3.6;
const float TILE = 6.0;
const int MAXK = 48;
const vec3 VOID = vec3(0.035, 0.027, 0.047);
const vec3 ASH = vec3(0.86, 0.80, 0.70);
const vec3 GRID = vec3(0.14, 0.12, 0.17);
const vec3 SKETCH = vec3(0.36, 0.31, 0.36);
const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float h(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float bayer(vec2 a) {
	return BAYER[int(mod(a.y, 4.0)) * 4 + int(mod(a.x, 4.0))] / 16.0;
}

float lum(vec3 c) {
	return dot(c, vec3(0.3, 0.59, 0.11));
}

bool in_region(vec2 s) {
	if (s.x < region.x || s.y < region.y || s.x >= region.x + region.z || s.y >= region.y + region.w) {
		return false;
	}
	vec2 t = floor(s / TILE);
	vec2 lo = floor(region.xy / TILE);
	vec2 hi = floor((region.xy + region.zw - 1.0) / TILE);
	bool border = t.x >= hi.x - 1.0 || t.y <= lo.y || t.y >= hi.y;
	return !border || h(t + 5.0) < 0.55;
}

float tile_delay(vec2 t) {
	vec2 c = t * TILE + TILE * 0.5;
	return distance(c, origin) / 180.0 * 1.6 + h(t) * 0.35;
}

bool is_float(vec2 t) {
	return h(t + 11.0) < 0.06;
}

float release_at(vec2 s) {
	vec2 t = floor(s / TILE);
	return tile_delay(t) + (is_float(t) ? 0.0 : h(s) * 0.25);
}

// Upward displacement of source pixel s at time T; < 0 = still attached, > 900 = gone.
float disp(vec2 s, float T, float bob) {
	float u = T - release_at(s);
	if (u < 0.0) {
		return -1.0;
	}
	vec2 t = floor(s / TILE);
	if (is_float(t)) {
		return min(floor(u * 10.0), 3.0 + floor(h(t + 2.0) * 7.0)) + bob;
	}
	float d = floor(u * u * 30.0 + u * 10.0);
	return d > 16.0 + h(s + 1.0) * 30.0 ? 999.0 : d;
}

vec3 orig(vec2 base, vec2 one, vec2 off) {
	return texture(screen_tex, base + off * one).rgb;
}

void fragment() {
	vec2 a = floor(UV * art_size);
	vec2 one = px * SCREEN_PIXEL_SIZE;
	vec2 base = SCREEN_UV - (fract(UV * art_size) - 0.5) * one;
	float T = progress * DUR;
	float bob = step(0.55, sin(TIME * 1.1 + h(floor(a / TILE)) * 20.0)) * motion;

	vec3 col = orig(base, one, vec2(0.0));
	bool mine = in_region(a);
	float r = release_at(a);

	if (mine && T >= r) {
		// revealed: void, then the stage grid and pencil outlines of what used to be here
		float g = clamp((T - r - 0.3) / 0.9, 0.0, 1.0);
		vec3 bg = VOID;
		float b = bayer(a);
		bool grid = (mod(a.x, 18.0) == 0.0 || mod(a.y, 18.0) == 0.0) && mod(a.x + a.y, 2.0) == 0.0;
		float l = lum(col);
		float e = abs(l - lum(orig(base, one, vec2(2.0, 0.0)))) + abs(l - lum(orig(base, one, vec2(0.0, 2.0))));
		bool sketch = e > 0.14 && mod(a.x + a.y, 3.0) != 0.0;
		if (b < g) {
			if (sketch) {
				bg = SKETCH * (0.7 + l);
			} else if (grid) {
				bg = GRID;
			}
		}
		// slow dust still drifting up through the hollow
		float mote = h(vec2(a.x, floor(a.y + TIME * 4.0 * motion + h(vec2(a.x, 7.0)) * 300.0)));
		if (mote > 0.997 && g > 0.5) {
			bg = mix(bg, ASH, 0.35);
		}
		col = bg;
	} else if (mine && T > r - 0.3 && motion > 0.5) {
		// loosening: the tile trembles before it lets go
		float j = sign(sin(TIME * 38.0 + h(floor(a / TILE)) * 9.0));
		col = orig(base, one, vec2(j, 0.0));
	}

	// particles rising through this pixel (reverse search below, swaying on the way up)
	bool near = a.x >= region.x - 4.0 && a.x < region.x + region.z + 4.0 && a.y >= region.y - 50.0 && a.y < region.y + region.w;
	if (near && T > 0.0) {
		float ph = h(vec2(a.x, 3.0)) * 6.2831;
		for (int i = 0; i < MAXK; i++) {
			float k = float(i);
			float dx = round(sin(k * 0.22 + ph) * 1.6) - round(sin(ph) * 1.6);
			vec2 s = vec2(a.x - dx, a.y + k);
			if (!in_region(s)) {
				continue;
			}
			float d = disp(s, T, bob);
			if (d == k && d >= 0.0) {
				vec3 pc = texture(screen_tex, base + vec2(-dx, k) * one).rgb;
				vec2 t = floor(s / TILE);
				if (is_float(t)) {
					col = pc;
				} else {
					float life = 16.0 + h(s + 1.0) * 30.0;
					float f = k / life;
					if (bayer(a) >= (f - 0.55) / 0.45) {
						col = mix(pc, ASH, f * 0.75);
					}
				}
				break;
			}
		}
	}

	if (!mine || T < r) {
		col *= 1.0 - dim * 0.4;
	}
	COLOR = vec4(col, 1.0);
}
