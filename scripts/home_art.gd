extends RefCounted
## Dark 90s-cyberpunk room art, baked to images at 270x330 (1.5 art px per logical unit).

const R = preload("res://scripts/raster.gd")

const VOID := Color("0b0810")
const LINE := Color("07050b")
const WALL := Color("2a1c2d")
const WALL_D := Color("1d1320")
const WALL_P := Color("34233a")
const WALL_MARK := Color("3e2b45")
const WALL_MARK_P := Color("4b3554")
const FLOOR := Color("361d1b")
const FLOOR_D := Color("251210")
const FLOOR_H := Color("4a2a24")
const PAPER := Color("cdb994")
const PAPER_D := Color("8f7e62")
const RUST := Color("8a3324")
const RUST_H := Color("b04a32")
const CRIMSON := Color("5a1b28")
const CRIMSON_D := Color("3a1019")
const CRIMSON_H := Color("7a2a38")
const WALNUT := Color("4a2b1e")
const WALNUT_D := Color("2f180f")
const WALNUT_H := Color("6e4329")
const BRASS := Color("c08f3e")
const AMBER := Color("f0a848")
const CYAN := Color("3fe0cf")
const CYAN_D := Color("1d6a66")
const MAGENTA := Color("e0408c")
const NIGHT := Color("16203a")
const NIGHT_D := Color("080c18")
const TEAL := Color("1f3c4a")
const TEAL_D := Color("132631")
const TEAL_H := Color("33616f")
const LEAF := Color("22402b")
const LEAF_H := Color("3a6845")
const GLASS := Color("3f6b74")
const GLASS_H := Color("9fd6d6")
const METAL := Color("47434f")
const METAL_H := Color("6c6878")
const CREAM_UI := Color("d8c8a8")
const NOTHING := Color(0, 0, 0, 0)

const W := 270
const H := 330
const SLOT_X := [159, 201, 243]
const SHELF_Y := 90
const ERASE_LIVING := Rect2i(0, 18, 108, 195)
const ERASE_DINING := Rect2i(0, 90, 126, 195)
## Where the card text sits inside closeup images (image pixels).
const CARD_TEXT_RECT := Rect2(10, 10, 100, 64)
## Text area inside the reflected card of the closeup mirror (image pixels, clipped by the glass).
const MIRROR_CARD_RECT := Rect2(20, 16, 44, 36)


static func _shade(p: R, x: int, y: int, w: int, h: int, c: Color, l0: int, l1: int) -> void:
	for yy in range(y, y + h):
		var lvl := int(lerpf(l0, l1, float(yy - y) / maxf(1.0, h - 1)))
		for xx in range(x, x + w):
			if R.bayer(xx, yy) < lvl:
				p.px(xx, yy, c)


# ================================================================ room shell

static func _shell(p: R, floor_y := 225) -> void:
	p.rect(0, 0, W, floor_y, WALL)
	for x in range(0, W, 10):
		p.vline(x, 12, floor_y - 12, WALL_P)
	for y in range(20, floor_y - 6, 14):
		for x in range(5, W, 10):
			var yy := y + (7 if (x / 10) % 2 == 1 else 0)
			p.px(x, yy - 1, WALL_P)
			p.px(x - 1, yy, WALL_P)
			p.px(x + 1, yy, WALL_P)
			p.px(x, yy + 1, WALL_P)
	p.speckle(0, 12, W, floor_y - 12, WALL_D, 3, 7)
	p.rect(0, 0, W, 9, WALL_D)
	p.hline(0, 9, W, LINE)
	p.hline(0, 10, W, WALL_P)
	_shade(p, 0, 11, W, 26, LINE, 9, 0)
	# floor planks
	p.rect(0, floor_y, W, H - floor_y, FLOOR)
	var row := 0
	for y in range(floor_y + 7, H, 12):
		p.hline(0, y, W, FLOOR_D)
		var off := (row * 37) % 50
		for x in range(off, W, 50):
			p.vline(x, y - 11, 11, FLOOR_D)
		row += 1
	p.speckle(0, floor_y, W, H - floor_y, FLOOR_H, 4, 11)
	p.speckle(0, floor_y, W, H - floor_y, FLOOR_D, 6, 12)
	_shade(p, 0, floor_y + 20, W, H - floor_y - 20, LINE, 0, 11)
	p.box(0, floor_y - 6, W, 8, WALNUT_D, LINE, 1, WALNUT)


static func _window(p: R, x: int, y: int, w: int, h: int, past: bool) -> void:
	p.box(x, y, w, h, WALNUT, LINE, 51, WALNUT_H)
	var ix := x + 4
	var iy := y + 4
	var iw := w - 8
	var ih := h - 8
	if past:
		p.vgrad(ix, iy, iw, ih, Color("e09a64"), Color("7a3e4c"))
	else:
		p.vgrad(ix, iy, iw, ih, NIGHT_D, NIGHT)
	# skyline
	var bx := ix
	var i := 0
	while bx < ix + iw:
		var bw := 6 + R.hash3(i, x, 3) % 8
		var bh := int(ih * 0.25) + R.hash3(i, y, 5) % int(ih * 0.4)
		var top := iy + ih - bh
		var bc := Color("3a2236") if past else Color("05070f")
		p.rect(bx, top, mini(bw, ix + iw - bx), bh, bc)
		for wy in range(top + 2, iy + ih - 1, 3):
			for wx in range(bx + 1, mini(bx + bw - 1, ix + iw), 2):
				var hv := R.hash3(wx, wy, 9) % 11
				if hv == 0:
					p.px(wx, wy, AMBER if past else CYAN_D)
				elif hv == 1 and not past:
					p.px(wx, wy, Color(MAGENTA, 0.7))
				elif hv == 2 and not past:
					p.px(wx, wy, Color(AMBER, 0.6))
		bx += bw + 1
		i += 1
	if not past:
		var sx := ix + int(iw * 0.62)
		var sy := iy + int(ih * 0.3)
		p.glow(sx + 4, sy + 1, 12, Color(MAGENTA, 0.5), 7)
		p.rect(sx, sy, 9, 3, MAGENTA)
		p.hline(sx + 1, sy + 1, 7, Color("ffb0d8"))
		for k in 46:
			var rx := ix + R.hash3(k, 1, 21) % iw
			var ry := iy + R.hash3(k, 2, 21) % ih
			for t in 4:
				if rx - t >= ix and ry + t * 2 < iy + ih:
					p.px(rx - t, ry + t * 2, Color(CYAN, 0.35))
	# mullions and glass sheen
	p.rect(ix + iw / 2 - 1, iy, 2, ih, WALNUT)
	p.vline(ix + iw / 2 - 1, iy, ih, WALNUT_H)
	p.rect(ix, iy + int(ih * 0.45), iw, 2, WALNUT)
	for k in 3:
		for t in 10:
			p.px(ix + 3 + k * 5 + t, iy + 12 + k * 3 + t, Color(GLASS_H, 0.12))


static func _curtains(p: R) -> void:
	for cx in [6, 84]:
		p.box(cx, 28, 15, 123, CRIMSON, LINE, 52 + cx)
		p.vline(cx + 2, 30, 119, CRIMSON_H)
		p.vline(cx + 5, 30, 119, CRIMSON_D)
		p.vline(cx + 10, 30, 119, CRIMSON_D)
		p.vline(cx + 7, 30, 119, CRIMSON_H)
		_shade(p, cx + 1, 30, 13, 119, CRIMSON_D, 0, 6)
	p.hline(4, 26, 98, BRASS)
	p.hline(4, 27, 98, LINE)
	p.disc(4, 26, 1.5, BRASS)
	p.disc(101, 26, 1.5, BRASS)


static func _cup(p: R, cx: int, base: int, m: int, c: Color) -> void:
	var cw := 4 * m + 1
	var ch := 5 * m
	p.box(cx - cw / 2, base - ch, cw, ch, c, LINE, cx)
	p.vline(cx - cw / 2 + 1, base - ch + 1, ch - 2, c.lightened(0.25))
	p.rect(cx + cw / 2 + 1, base - ch + m, m, 2 * m, LINE)
	if m > 1:
		for s in 3:
			p.px(cx - 1 + (s % 2), base - ch - 2 - s * 2, Color(PAPER, 0.5))


static func _seat(p: R) -> void:
	p.box(12, 136, 81, 8, WALNUT, LINE, 54, WALNUT_H)
	_cup(p, 34, 136, 2, PAPER_D)
	_cup(p, 70, 136, 2, RUST)
	p.box(9, 177, 90, 24, WALNUT, LINE, 57, WALNUT_H)
	for x in range(18, 96, 18):
		p.vline(x, 180, 19, WALNUT_D)
	p.box(15, 159, 33, 20, CRIMSON, LINE, 58, CRIMSON_H)
	p.box(57, 159, 33, 20, TEAL, LINE, 59, TEAL_H)
	p.px(31, 168, LINE)
	p.px(73, 168, LINE)
	p.rect(14, 201, 4, 18, LINE)
	p.rect(90, 201, 4, 18, LINE)


static func _lamp(p: R, x: int, top := 10) -> void:
	p.vline(x, top, 23, LINE)
	for r in 12:
		var half := 6 + r / 2
		p.hline(x - half, top + 23 + r, half * 2 + 1, RUST if r > 1 else LINE)
		p.px(x - half, top + 23 + r, LINE)
		p.px(x + half, top + 23 + r, LINE)
		if r > 1:
			p.px(x - half + 1, top + 23 + r, RUST_H)
	p.hline(x - 12, top + 35, 25, AMBER)
	p.hline(x - 5, top + 36, 11, Color("ffe0a0"))


static func _mark(p: R, x: int, y: int, w: int, h: int) -> void:
	p.rect(x, y, w, h, WALL_MARK)
	for xx in range(x, x + w):
		if xx % 10 == 0:
			p.vline(xx, y, h, WALL_MARK_P)


static func _sideboard(p: R) -> void:
	_shade(p, 108, 226, 156, 6, LINE, 12, 2)
	p.box(111, 165, 150, 8, WALNUT, LINE, 61, WALNUT_H)
	p.box(114, 172, 144, 50, WALNUT, LINE, 62)
	for yy in range(175, 220, 3):
		var off := R.hash3(yy, 0, 3) % 30
		for xx in range(116 + off, 255, 34):
			p.hline(xx, yy, 6 + R.hash3(xx, yy, 4) % 9, WALNUT_D)
	for dx in [120, 189]:
		p.box(dx, 177, 63, 18, WALNUT, LINE, dx, WALNUT_H)
		p.box(dx, 199, 63, 20, WALNUT, LINE, dx + 1, WALNUT_H)
		p.box(dx + 4, 202, 55, 14, WALNUT_D, LINE, dx + 2)
		p.rect(dx + 29, 185, 6, 2, BRASS)
		p.px(dx + 29, 185, Color("f0d090"))
	p.rect(117, 222, 4, 9, LINE)
	p.rect(251, 222, 4, 9, LINE)


static func drawer_open(p: R) -> void:
	p.box(117, 193, 69, 9, WALNUT_H, LINE, 65)
	p.rect(119, 194, 65, 3, WALNUT_D)
	p.rect(146, 198, 6, 2, BRASS)


static func _card(p: R, x: int, y: int) -> void:
	p.box(x, y, 21, 36, PAPER, LINE, 21)
	for k in 5:
		p.hline(x + 3, y + 6 + k * 5, 12 + R.hash3(k, x, 2) % 5, PAPER_D)
	_shade(p, x + 13, y + 1, 7, 34, PAPER_D, 0, 8)


static func _rug(p: R) -> void:
	p.box(99, 273, 132, 33, CRIMSON_D, LINE, 2)
	p.box(103, 277, 124, 25, CRIMSON, LINE, 3)
	for x in range(108, 224, 8):
		p.px(x, 289, RUST_H)
		p.px(x + 1, 288, RUST_H)
		p.px(x + 1, 290, RUST_H)
		p.px(x + 2, 289, RUST_H)
	for x in range(100, 230, 3):
		p.px(x, 307, PAPER_D)


static func _leaf(p: R, cx: int, cy: int, rw: int, rh: int) -> void:
	for yy in range(-rh, rh + 1):
		var half := int(rw * sqrt(maxf(0.0, 1.0 - float(yy * yy) / float(rh * rh))))
		p.hline(cx - half, cy + yy, half * 2 + 1, LEAF)
		p.px(cx - half, cy + yy, LINE)
		p.px(cx + half, cy + yy, LINE)
		if yy < 0:
			p.px(cx - half + 1, cy + yy, LEAF_H)
	p.hline(cx - rw + 2, cy, rw * 2 - 3, LINE)


static func _plant(p: R) -> void:
	p.vline(247, 192, 46, LINE)
	p.vline(250, 200, 38, LINE)
	_leaf(p, 237, 207, 10, 5)
	_leaf(p, 260, 195, 9, 5)
	_leaf(p, 241, 224, 8, 4)
	_leaf(p, 257, 217, 8, 4)
	_leaf(p, 250, 186, 5, 6)
	p.box(237, 237, 27, 27, RUST, LINE, 71, RUST_H)
	p.rect(235, 237, 31, 4, RUST_H)
	p.hline(235, 241, 31, LINE)
	p.vline(239, 242, 20, Color(RUST_H, 0.6))


static func _light(p: R, lamp_x: int) -> void:
	p.glow(lamp_x, 70, 78, Color(AMBER, 0.2), 9, 1.2)
	p.glow(lamp_x, 262, 70, Color(AMBER, 0.14), 8, 0.35)
	p.glow(54, 245, 60, Color(CYAN, 0.12), 8, 0.45)


# ================================================================ items (m = pixel multiplier)

static func tall(p: R, cx: int, bottom: int, m := 1) -> void:
	var w := 21 * m
	var h := 36 * m
	var x := cx - w / 2
	var y := bottom - h
	p.box(x, y, w, h, WALNUT, LINE, 11, WALNUT_H, WALNUT_H)
	var ix := x + 3 * m
	var iy := y + 3 * m
	var iw := w - 6 * m
	var ih := h - 6 * m
	p.rect(ix - 1, iy - 1, iw + 2, ih + 2, BRASS)
	p.vgrad(ix, iy, iw, ih, Color("c98a5a"), Color("6a3a32"))
	p.rect(ix + iw / 2, iy + 2 * m, iw / 2 - 2 * m, ih / 3, Color("e8c08a"))
	var ty := iy + int(ih * 0.62)
	p.rect(ix, ty, iw, ih - (ty - iy), WALNUT_H)
	p.hline(ix, ty, iw, LINE)
	_cup(p, ix + iw / 4, ty, m, PAPER)
	_cup(p, ix + iw * 3 / 4, ty, m, RUST_H)
	if m > 1:
		p.rect(ix + iw / 2 - 2 * m, ty - 2 * m, 4 * m, 2 * m, Color("d8a060"))
		p.speckle(ix, iy, iw, ih, Color(1, 0.9, 0.7, 0.25), 3, 5)


static func small(p: R, cx: int, bottom: int, m := 1) -> void:
	var w := 27 * m
	var h := 21 * m
	var x := cx - w / 2
	var y := bottom - h
	p.box(x, y, w, h, CRIMSON, LINE, 13, CRIMSON_H, CRIMSON_H)
	var ix := x + 3 * m
	var iy := y + 3 * m
	var iw := w - 6 * m
	var ih := h - 6 * m
	p.vgrad(ix, iy, iw, ih, Color("2a3a5a"), Color("101828"))
	for k in 5:
		var bx := ix + k * iw / 5
		var bh := ih / 3 + R.hash3(k, 0, 8) % (ih / 3 + 1)
		p.rect(bx, iy + ih - bh, iw / 5 - 1, bh, Color("0a0e1a"))
	for k in 6 * m:
		var rx := ix + R.hash3(k, 3, m) % iw
		var ry := iy + R.hash3(k, 4, m) % maxi(1, ih - 3 * m)
		for t in 2 * m:
			p.px(rx, ry + t, Color(CYAN, 0.5))
	p.vline(ix + iw / 2, iy, ih, CRIMSON_D)


static func _reflect(p: R, cx: int, cy: int, m: int, sees: String) -> void:
	match sees:
		"card":
			p.box(cx - 8 * m, cy - 7 * m, 16 * m, 14 * m, PAPER, LINE, 5)
			if m == 1:
				p.hline(cx - 5, cy - 3, 9, PAPER_D)
				p.hline(cx - 5, cy + 1, 7, PAPER_D)
			p.dither(cx - 8 * m, cy - 7 * m, 16 * m, 14 * m, Color(AMBER, 0.5), 3)
		"window":
			p.rect(cx - 7 * m, cy - 6 * m, 7 * m, 12 * m, NIGHT)
			p.rect(cx - 5 * m, cy - 2 * m, 2 * m, 2 * m, MAGENTA)
			for t in 4 * m:
				p.px(cx - 6 * m + t / 2, cy - 5 * m + t, Color(CYAN, 0.5))
			p.rect(cx, cy - 6 * m, 3 * m, 12 * m, CRIMSON)
		"ceiling":
			p.vline(cx, cy - 8 * m, 4 * m, LINE)
			p.glow(cx, cy, 6 * m, AMBER, 12)
			p.disc(cx, cy - 2 * m, 2.0 * m, Color("ffe0a0"))
		"frame_back":
			p.rect(cx - 9 * m, cy - 8 * m, 7 * m, 16 * m, WALNUT_D)
			p.vline(cx - 6 * m, cy - 8 * m, 16 * m, WALNUT_H)
			p.hline(cx - 9 * m, cy, 7 * m, WALNUT_H)
		"empty":
			p.rect(cx - 9 * m, cy + 1 * m, 18 * m, 8 * m, WALNUT)
			p.hline(cx - 9 * m, cy + 1 * m, 18 * m, WALNUT_H)
			p.rect(cx - 9 * m, cy - 8 * m, 18 * m, 9 * m, WALL)


static func mirror(p: R, cx: int, bottom: int, m: int, sees: String) -> void:
	p.box(cx - 7 * m, bottom - 4 * m, 14 * m, 4 * m, WALNUT, LINE, 17, WALNUT_H)
	p.rect(cx - m, bottom - 16 * m, 2 * m, 12 * m, WALNUT)
	p.vline(cx - m, bottom - 16 * m, 12 * m, LINE)
	var cy := bottom - 26 * m
	var r := 11.0 * m
	p.disc(cx, cy, r, BRASS, LINE)
	p.disc(cx, cy, r - m - 1, GLASS)
	for yy in range(-int(r), int(r)):
		for xx in range(-int(r), int(r)):
			if xx * xx + yy * yy < (r - m - 1) * (r - m - 1) and xx + yy > r * 0.4 and R.bayer(cx + xx, cy + yy) < 6:
				p.px(cx + xx, cy + yy, Color("24434a"))
	var inner := r - m - 1
	var refl := R.new(p.w, p.h)
	_reflect(refl, cx, cy, m, sees)
	for yy in range(-int(inner), int(inner) + 1):
		for xx in range(-int(inner), int(inner) + 1):
			if xx * xx + yy * yy <= inner * inner:
				var c := refl.img.get_pixel(clampi(cx + xx, 0, p.w - 1), clampi(cy + yy, 0, p.h - 1))
				if c.a > 0.0:
					p.px(cx + xx, cy + yy, c)
	for t in int(r * 0.6):
		p.px(cx - int(r * 0.55) + t / 2, cy - int(r * 0.25) - t, Color(GLASS_H, 0.7))


static func bag(p: R, cx: int, bottom: int, m := 1) -> void:
	_shade(p, cx - 22 * m, bottom - 1, 44 * m, 3, LINE, 10, 4)
	p.box(cx - 15 * m, bottom - 44 * m, 4 * m, 16 * m, TEAL_D, LINE, 41)
	p.box(cx + 11 * m, bottom - 44 * m, 4 * m, 16 * m, TEAL_D, LINE, 42)
	p.box(cx - 15 * m, bottom - 45 * m, 30 * m, 3 * m, TEAL_D, LINE, 43)
	p.box(cx - 21 * m, bottom - 30 * m, 42 * m, 30 * m, TEAL, LINE, 44, TEAL_H, TEAL_H)
	p.box(cx - 21 * m, bottom - 30 * m, 42 * m, 11 * m, TEAL_D, LINE, 45, TEAL)
	p.box(cx - 3 * m, bottom - 21 * m, 7 * m, 5 * m, BRASS, LINE, 46)
	p.px(cx - 2 * m, bottom - 20 * m, Color("f0d090"))
	for x in range(cx - 19 * m, cx + 19 * m, 3):
		p.px(x, bottom - 3 * m, TEAL_H)
	for y in range(bottom - 17 * m, bottom - 3 * m, 3):
		p.px(cx - 19 * m, y, TEAL_H)
		p.px(cx + 18 * m, y, TEAL_H)
	_shade(p, cx + 6 * m, bottom - 18 * m, 14 * m, 17 * m, TEAL_D, 0, 9)


# ================================================================ scenes

static func living_base(past := false) -> Image:
	var p := R.new(W, H, VOID)
	_shell(p)
	_window(p, 15, 36, 75, 102, past)
	_curtains(p)
	_seat(p)
	_lamp(p, 120)
	for x in SLOT_X:
		_mark(p, x - 13, 51, 27, 39)
	p.box(138, SHELF_Y, 126, 6, WALNUT, LINE, 6, WALNUT_H)
	_shade(p, 139, SHELF_Y + 6, 124, 4, LINE, 10, 0)
	_sideboard(p)
	if not past:
		_card(p, 129, 129)
	_rug(p)
	_plant(p)
	_light(p, 120)
	return p.img


## Fully composed living room for photos inside the game (past / fridge copy).
static func living_photo(past: bool) -> Image:
	var p := R.new(W, H)
	p.img = living_base(past)
	var order := ["tall", "small", "mirror"]
	for i in 3:
		item(p, order[i], SLOT_X[i], SHELF_Y, 1, "empty" if past else "card")
	if not past:
		bag(p, 141, 168)
	p.tint(Color(0.95, 0.6, 0.3, 0.22))
	_shade(p, 0, 0, W, H, Color(0.15, 0.08, 0.04), 0, 4)
	var out := Image.create(W, 246, false, Image.FORMAT_RGBA8)
	out.blit_rect(p.img, Rect2i(0, 0, W, 246), Vector2i.ZERO)
	return out


static func item(p: R, id: String, cx: int, bottom: int, m: int, sees: String) -> void:
	match id:
		"tall":
			tall(p, cx, bottom, m)
		"small":
			small(p, cx, bottom, m)
		"mirror":
			mirror(p, cx, bottom, m, sees)


static func item_sprite(id: String, sees := "") -> Image:
	var p := R.new(36, 48)
	item(p, id, 18, 47, 1, sees)
	return p.img


static func bag_sprite() -> Image:
	var p := R.new(48, 50)
	bag(p, 24, 48)
	return p.img


static func drawer_sprite() -> Image:
	var p := R.new(W, H)
	drawer_open(p)
	return p.img


static func erase_image(r: Rect2i, seed: int) -> Image:
	var p := R.new(W, H)
	for y in range(r.position.y, r.end.y):
		var edge := r.end.x - 8 + R.hash3(0, y / 3, seed) % 14
		p.rect(r.position.x, y, edge - r.position.x, 1, Color("14111a"))
		if R.hash3(1, y, seed) % 23 == 0:
			p.hline(r.position.x, y, edge - r.position.x, Color(CYAN_D, 0.45))
	p.speckle(r.position.x, r.position.y, r.size.x + 6, r.size.y, Color("3a3542"), 22, seed)
	p.speckle(r.position.x, r.position.y, r.size.x + 6, r.size.y, Color("57525e"), 4, seed + 1)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x + 8):
			if p.img.get_pixel(x, y).a > 0.0 and x > r.end.x - 9 + R.hash3(0, y / 3, seed) % 14 - 1:
				p.img.set_pixel(x, y, NOTHING)
	return p.img


static func vignette() -> Image:
	var p := R.new(W, H)
	for y in H:
		for x in W:
			var dx := (x - W / 2.0) / (W / 2.0)
			var dy := (y - H / 2.0) / (H / 2.0)
			var d := sqrt(dx * dx * 0.8 + dy * dy * 0.7)
			var lvl := int(clampf((d - 0.62) * 34.0, 0.0, 15.0))
			if R.bayer(x, y) < lvl:
				p.px(x, y, LINE)
	return p.img


static func dining_base() -> Image:
	var p := R.new(W, H, VOID)
	_shell(p)
	_window(p, 66, 33, 84, 72, false)
	# fridge
	p.box(213, 45, 51, 177, METAL, LINE, 83, METAL_H, METAL_H)
	p.hline(214, 108, 49, LINE)
	p.rect(255, 70, 3, 24, BRASS)
	p.rect(255, 118, 3, 30, BRASS)
	_shade(p, 240, 46, 23, 175, LINE, 2, 7)
	p.box(222, 123, 24, 20, PAPER, LINE, 84)
	p.rect(224, 125, 20, 13, WALL_MARK)
	p.rect(229, 129, 6, 6, GLASS)
	p.px(231, 131, PAPER)
	p.disc(234, 122, 2.0, MAGENTA, LINE)
	# chairs and table
	p.box(33, 129, 6, 36, WALNUT, LINE, 85, WALNUT_H)
	p.box(30, 162, 33, 9, WALNUT, LINE, 86, WALNUT_H)
	p.rect(32, 171, 4, 54, LINE)
	p.box(186, 129, 6, 36, WALNUT, LINE, 87, WALNUT_H)
	p.box(162, 162, 33, 9, WALNUT, LINE, 88, WALNUT_H)
	p.rect(188, 171, 4, 54, LINE)
	_shade(p, 48, 226, 132, 6, LINE, 12, 2)
	p.box(48, 168, 132, 9, WALNUT, LINE, 89, WALNUT_H)
	p.rect(51, 170, 126, 4, CRIMSON)
	p.rect(60, 177, 6, 48, LINE)
	p.rect(162, 177, 6, 48, LINE)
	p.box(66, 165, 27, 5, TEAL, LINE, 90, TEAL_H)
	p.box(135, 165, 27, 5, TEAL, LINE, 91, TEAL_H)
	_cup(p, 79, 165, 2, PAPER_D)
	_cup(p, 148, 165, 2, RUST)
	_lamp(p, 114)
	_light(p, 114)
	return p.img


# ================================================================ closeups

static func closeup_image(kind: String, sees: String) -> Image:
	var p: R
	match kind:
		"tall":
			p = R.new(72, 116)
			tall(p, 36, 112, 3)
		"small":
			p = R.new(90, 70)
			small(p, 45, 67, 3)
		"mirror", "card_mirror":
			p = R.new(84, 116)
			mirror(p, 42, 112, 3, "card" if kind == "card_mirror" else sees)
		"bag":
			p = R.new(140, 144)
			bag(p, 70, 140, 3)
		"card":
			p = R.new(120, 84)
			p.box(2, 2, 116, 80, PAPER, LINE, 7, Color("e0d0b0"))
			p.speckle(3, 3, 114, 78, PAPER_D, 4, 3)
			_shade(p, 80, 3, 37, 78, PAPER_D, 0, 5)
		"drawer":
			p = R.new(144, 84)
			p.box(0, 0, 144, 84, WALNUT, LINE, 3, WALNUT_H)
			p.rect(5, 5, 134, 74, WALNUT_D)
			_shade(p, 5, 5, 134, 74, LINE, 10, 0)
			var thumb := living_photo(true)
			thumb.resize(56, 51, Image.INTERPOLATE_NEAREST)
			p.box(42, 14, 60, 55, PAPER, LINE, 4)
			p.blit(thumb, 44, 16)
		"photo":
			return living_photo(true)
		"fridge_photo":
			return living_photo(false)
		_:
			p = R.new(8, 8)
	return p.img


static func _framed(photo: Image) -> Image:
	var p := R.new(photo.get_width() + 8, photo.get_height() + 8, PAPER)
	p.blit(photo, 4, 4)
	p.box(0, 0, p.w, p.h, NOTHING, LINE, 9)
	return p.img


static func photo_icon() -> Image:
	var thumb := living_photo(true)
	thumb.resize(30, 27, Image.INTERPOLATE_NEAREST)
	var p := R.new(34, 31, PAPER)
	p.blit(thumb, 2, 2)
	p.box(0, 0, 34, 31, NOTHING, LINE, 2)
	return p.img
