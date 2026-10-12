extends RefCounted
## Image-backed pixel painter. Everything is baked into textures once, then composed at draw time.

const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var img: Image
var w: int
var h: int


func _init(width: int, height: int, fill := Color(0, 0, 0, 0)) -> void:
	w = width
	h = height
	img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(fill)


static func bayer(x: int, y: int) -> int:
	return BAYER[(y & 3) * 4 + (x & 3)]


static func hash3(x: int, y: int, s: int) -> int:
	var n := x * 374761393 + y * 668265263 + s * 1442695041
	n = (n ^ (n >> 13)) * 1274126177
	return absi(n ^ (n >> 16))


func rect(x: int, y: int, rw: int, rh: int, c: Color) -> void:
	var r := Rect2i(x, y, rw, rh).intersection(Rect2i(0, 0, w, h))
	if r.size.x <= 0 or r.size.y <= 0:
		return
	if c.a >= 1.0:
		img.fill_rect(r, c)
	else:
		for yy in range(r.position.y, r.end.y):
			for xx in range(r.position.x, r.end.x):
				px(xx, yy, c)


func px(x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= w or y >= h:
		return
	if c.a >= 1.0:
		img.set_pixel(x, y, c)
	else:
		img.set_pixel(x, y, img.get_pixel(x, y).blend(c))


func hline(x: int, y: int, len: int, c: Color) -> void:
	rect(x, y, len, 1, c)


func vline(x: int, y: int, len: int, c: Color) -> void:
	rect(x, y, 1, len, c)


## Ordered-dither c over the rect; level 0..16 is coverage.
func dither(x: int, y: int, rw: int, rh: int, c: Color, level: int) -> void:
	for yy in range(y, y + rh):
		for xx in range(x, x + rw):
			if bayer(xx, yy) < level:
				px(xx, yy, c)


## Two-colour dithered vertical gradient.
func vgrad(x: int, y: int, rw: int, rh: int, c0: Color, c1: Color) -> void:
	rect(x, y, rw, rh, c0)
	for yy in range(y, y + rh):
		var lvl := int(float(yy - y) / maxf(1.0, rh - 1) * 16.0)
		for xx in range(x, x + rw):
			if bayer(xx, yy) < lvl:
				px(xx, yy, c1)


## Dithered radial light, densest at the centre.
func glow(cx: int, cy: int, rad: int, c: Color, strength: int, squash := 1.0) -> void:
	for yy in range(cy - rad, cy + rad + 1):
		for xx in range(cx - rad, cx + rad + 1):
			var dy := (yy - cy) / squash
			var d := sqrt(float((xx - cx) * (xx - cx)) + dy * dy) / rad
			if d >= 1.0:
				continue
			if bayer(xx, yy) < int((1.0 - d) * strength):
				px(xx, yy, c)


## Filled box with a hand-jogged dark outline, optional top highlight and left rim light.
func box(x: int, y: int, rw: int, rh: int, fill: Color, line: Color, seed := 0, hi := Color(0, 0, 0, 0), rim := Color(0, 0, 0, 0)) -> void:
	if fill.a > 0.0:
		rect(x, y, rw, rh, fill)
	if hi.a > 0.0:
		hline(x + 1, y + 1, rw - 2, hi)
	if rim.a > 0.0:
		vline(x + 1, y + 1, rh - 2, rim)
	var x1 := x + rw - 1
	var y1 := y + rh - 1
	var seg := 6
	var xx := x
	while xx <= x1:
		var sw := mini(seg, x1 - xx + 1)
		var jt := 1 if (rw > 16 and sw > 3 and hash3(xx, y, seed) % 6 == 0) else 0
		hline(xx, y - jt, sw, line)
		hline(xx, y1, sw, line)
		xx += seg
	var yy := y
	while yy <= y1:
		var sh := mini(seg, y1 - yy + 1)
		var jl := 1 if (rh > 16 and sh > 3 and hash3(x, yy, seed + 3) % 6 == 0) else 0
		vline(x - jl, yy, sh, line)
		vline(x1, yy, sh, line)
		yy += seg


func disc(cx: int, cy: int, r: float, fill: Color, line := Color(0, 0, 0, 0)) -> void:
	var ri := int(ceil(r))
	for yy in range(-ri, ri + 1):
		for xx in range(-ri, ri + 1):
			var d := sqrt(float(xx * xx + yy * yy))
			if d <= r:
				px(cx + xx, cy + yy, line if (line.a > 0.0 and d > r - 1.0) else fill)


## Sprinkle single pixels by hash; density is out of 100.
func speckle(x: int, y: int, rw: int, rh: int, c: Color, density: int, seed: int) -> void:
	for yy in range(y, y + rh):
		for xx in range(x, x + rw):
			if hash3(xx, yy, seed) % 100 < density:
				px(xx, yy, c)


func blit(src: Image, x: int, y: int) -> void:
	img.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(x, y))


func tint(c: Color) -> void:
	var over := Image.create(w, h, false, Image.FORMAT_RGBA8)
	over.fill(c)
	img.blend_rect(over, Rect2i(0, 0, w, h), Vector2i.ZERO)


func texture() -> ImageTexture:
	return ImageTexture.create_from_image(img)
