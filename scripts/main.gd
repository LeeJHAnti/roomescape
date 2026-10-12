extends Control
## One-room slice: shared photo frames vs. A's bag. Shortcut erases part of the memory space.

const Art = preload("res://scripts/home_art.gd")
const RoomCanvas = preload("res://scripts/room_canvas.gd")
const CloseupCanvas = preload("res://scripts/closeup_canvas.gd")
const ItemSlot = preload("res://scripts/item_slot.gd")

const SAVE_PATH := "user://home_demo.json"
const SETTINGS_PATH := "user://settings.json"
const TEXT_SIZES := [15, 17, 21]
const TEXT_NAMES := ["작게", "보통", "크게"]
const NEW_HOLD_S := 1.2
const ROOM_W := 180
const ROOM_H := 220
## Art pixels per logical unit; hit areas and tests stay in logical units.
const ART := 1.5
const SLOT_U := [106, 134, 162]
const DRAG_START_PX := 10.0
const SWIPE_PX := 60.0
const SOLUTION := ["tall", "small", "mirror"]
const PLACE_NAMES := {"living": "거실", "dining": "식탁"}

var s: Dictionary = {}
var erase_t := 0.0
var shock := 0.0
var fx: ColorRect
const ERASE_S := 3.6
var _erasing := false
var _line_after_erase := ""

var room: Control
## UI units per art pixel; always a whole number of device pixels (room_k * scale.x).
var room_k := 2.0
var bg: ColorRect
var place_label: Label
var line_label: Label
var menu_btn: Button
var left_btn: Button
var right_btn: Button
var drawer: HBoxContainer
var slots: Array = []
var closeup: Control
var cu_label: Label
var move_btn: Button
var pause_panel: Control
var hold_btn: Button
var hold_bar: ProgressBar

var cu_kind := ""
var cu_move_id := ""
var cu_art_rect := Rect2()
var move_id := ""

var _press := false
var _press_pos := Vector2.ZERO
var _press_target := ""
var _dragging := ""
var _drag_pos := Vector2.ZERO
var _swiping := false
var _line_timer: SceneTreeTimer
var _holding := false
var _hold_t := 0.0
var _tex := {}

var cfg := {"text": 1, "reduce_motion": false, "notice_seen": false}
var notice_panel: ColorRect
var title_panel: ColorRect
var settings_panel: ColorRect
var continue_btn: Button
var new_btn: Button
var new_warn: Label
var settings_btns := {}
var in_game := false
var _new_hold := -1.0
var _menu_btns: Array[Button] = []
var _menu_boxes: Array[VBoxContainer] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_cfg()
	theme = _make_theme()
	_build()
	_load()
	get_window().size_changed.connect(_fit_base)
	_fit_base()
	resized.connect(_layout)
	_layout()
	_apply_cfg()
	if cfg.notice_seen:
		_show_title()
	else:
		notice_panel.visible = true


func _default_state() -> Dictionary:
	return {
		"ledge": ["small", "mirror", "tall"],
		"bag": "mark",
		"drawer_open": false,
		"has_photo": false,
		"loss": false,
		"clue": "",
		"view": "living",
	}


# ---------------------------------------------------------------- build / layout

func _make_theme() -> Theme:
	var t := Theme.new()
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans CJK KR", "Noto Sans KR", "sans-serif"])
	var fb: Array[Font] = [load("res://fonts/Galmuri11.ttf")]
	f.fallbacks = fb
	t.default_font = f
	t.default_font_size = 17
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("15101a")
	sb.border_color = Art.CYAN_D
	sb.set_border_width_all(2)
	sb.set_content_margin_all(8)
	var sb_p := sb.duplicate()
	sb_p.bg_color = Color("241a2c")
	sb_p.border_color = Art.CYAN
	t.set_stylebox("normal", "Button", sb)
	t.set_stylebox("hover", "Button", sb_p)
	t.set_stylebox("pressed", "Button", sb_p)
	t.set_stylebox("focus", "Button", sb_p)
	t.set_color("font_color", "Button", Art.CREAM_UI)
	t.set_color("font_hover_color", "Button", Art.CYAN)
	t.set_color("font_pressed_color", "Button", Art.CYAN)
	t.set_color("font_focus_color", "Button", Art.CYAN)
	t.set_color("font_color", "Label", Art.CREAM_UI)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color("15101a")
	var bar_fg := StyleBoxFlat.new()
	bar_fg.bg_color = Art.AMBER
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fg)
	return t


func _build() -> void:
	bg = ColorRect.new()
	bg.color = Art.VOID
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	room = RoomCanvas.new()
	room.main = self
	room.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(room)

	fx = ColorRect.new()
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/memory_erosion.gdshader")
	fx.material = mat
	fx.visible = false
	add_child(fx)

	place_label = Label.new()
	place_label.add_theme_font_size_override("font_size", 18)
	place_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(place_label)

	line_label = Label.new()
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line_label)

	menu_btn = _button("Ⅱ", _open_pause)
	menu_btn.tooltip_text = "일시정지"
	left_btn = _button("‹", func(): _go(-1))
	left_btn.tooltip_text = "왼쪽 구역"
	right_btn = _button("›", func(): _go(1))
	right_btn.tooltip_text = "오른쪽 구역"
	for b in [left_btn, right_btn]:
		b.add_theme_font_size_override("font_size", 28)

	drawer = HBoxContainer.new()
	drawer.add_theme_constant_override("separation", 8)
	drawer.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(drawer)
	for i in 3:
		var sl: Control = ItemSlot.new()
		sl.main = self
		drawer.add_child(sl)
		slots.append(sl)
	drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for b in [menu_btn, left_btn, right_btn]:
		move_child(b, -1)

	closeup = CloseupCanvas.new()
	closeup.main = self
	closeup.visible = false
	closeup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(closeup)
	cu_label = Label.new()
	cu_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cu_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	closeup.add_child(cu_label)
	move_btn = Button.new()
	move_btn.text = "옮기기"
	move_btn.pressed.connect(_begin_move)
	closeup.add_child(move_btn)

	pause_panel = ColorRect.new()
	(pause_panel as ColorRect).color = Color(0.08, 0.06, 0.12, 0.92)
	pause_panel.visible = false
	add_child(pause_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vb.grow_vertical = Control.GROW_DIRECTION_BOTH
	pause_panel.add_child(vb)
	var resume := Button.new()
	resume.text = "계속"
	resume.custom_minimum_size = Vector2(220, 52)
	resume.pressed.connect(_close_pause)
	vb.add_child(resume)
	var to_title := Button.new()
	to_title.text = "타이틀로"
	to_title.custom_minimum_size = Vector2(220, 52)
	to_title.pressed.connect(_to_title)
	vb.add_child(to_title)
	hold_btn = Button.new()
	hold_btn.text = "처음부터 (길게 누르기)"
	hold_btn.custom_minimum_size = Vector2(220, 52)
	hold_btn.button_down.connect(func():
		_holding = true
		_hold_t = 0.0
	)
	hold_btn.button_up.connect(func():
		_holding = false
		_hold_t = 0.0
		hold_bar.value = 0
	)
	vb.add_child(hold_btn)
	hold_bar = ProgressBar.new()
	hold_bar.max_value = 1.0
	hold_bar.show_percentage = false
	hold_bar.custom_minimum_size = Vector2(220, 8)
	vb.add_child(hold_bar)
	_build_menus()


func _overlay() -> Array:
	var p := ColorRect.new()
	p.color = Art.VOID
	p.visible = false
	add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(vb)
	_menu_boxes.append(vb)
	return [p, vb]


func _mbtn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 52)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if cb.is_valid():
		b.pressed.connect(cb)
	parent.add_child(b)
	_menu_btns.append(b)
	return b


func _mlabel(parent: Control, text: String, fs := 0, col := Art.CREAM_UI) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(280, 0)
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if fs > 0:
		l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _build_menus() -> void:
	var n := _overlay()
	notice_panel = n[0]
	_mlabel(n[1], "이 게임은 상실과 기억, 죽음의 암시를 다룹니다.")
	_mlabel(n[1], "직접적인 묘사나 갑작스런 놀라게 하기는 없습니다.", 0, Art.PAPER_D)
	_mbtn(n[1], "확인", _ack_notice)

	var t := _overlay()
	title_panel = t[0]
	_mlabel(t[1], "ROOM ESCAPE", 30, Art.AMBER)
	_mlabel(t[1], "거실 · 시연판", 0, Art.CYAN_D)
	continue_btn = _mbtn(t[1], "이어하기", _continue)
	new_btn = _mbtn(t[1], "새로 시작", Callable())
	new_btn.button_down.connect(_new_down)
	new_btn.button_up.connect(_new_up)
	new_warn = _mlabel(t[1], "", 0, Art.RUST_H)
	_mbtn(t[1], "설정", _open_settings)

	var st := _overlay()
	settings_panel = st[0]
	_mlabel(st[1], "설정", 22, Art.AMBER)
	for key in ["text", "reduce_motion"]:
		var k: String = key
		settings_btns[k] = _mbtn(st[1], "", func(): _cycle(k))
	_mbtn(st[1], "닫기", _close_settings)


# ---------------------------------------------------------------- title / settings

func _load_cfg() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if data is Dictionary:
			for key in cfg.keys():
				if data.has(key):
					cfg[key] = data[key]
	cfg.text = clampi(int(cfg.text), 0, 2)


func _save_cfg() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(cfg))


func _apply_cfg() -> void:
	var fs: int = TEXT_SIZES[cfg.text]
	theme.default_font_size = fs
	place_label.add_theme_font_size_override("font_size", fs + 1)
	for key in settings_btns.keys():
		settings_btns[key].text = _cfg_text(key)


func _cfg_text(key: String) -> String:
	match key:
		"text": return "글자 크기: " + TEXT_NAMES[cfg.text]
		"reduce_motion": return "움직임 줄이기: " + ("켜짐" if cfg.reduce_motion else "꺼짐")
	return key


func _cycle(key: String) -> void:
	match key:
		"text": cfg.text = (int(cfg.text) + 1) % 3
		"reduce_motion": cfg.reduce_motion = not cfg.reduce_motion
	_save_cfg()
	_apply_cfg()
	_layout()


func _ack_notice() -> void:
	cfg.notice_seen = true
	_save_cfg()
	notice_panel.visible = false
	_show_title()


func has_progress() -> bool:
	return FileAccess.file_exists(SAVE_PATH) and s != _default_state()


func _show_title() -> void:
	in_game = false
	close_closeup()
	continue_btn.visible = has_progress()
	new_warn.text = ""
	new_warn.visible = false
	_new_hold = -1.0
	title_panel.visible = true
	if continue_btn.visible:
		continue_btn.grab_focus()
	else:
		new_btn.grab_focus()


func _start_game() -> void:
	title_panel.visible = false
	in_game = true
	_enter_view(s.view)


func _continue() -> void:
	_start_game()


func _new_down() -> void:
	if not has_progress():
		restart()
		_start_game()
		return
	_new_hold = 0.0
	new_warn.visible = true
	new_warn.text = "진행 기록이 지워집니다. 계속 눌러 주세요."


func _new_up() -> void:
	if _new_hold >= 0.0:
		_new_hold = -1.0
		new_warn.text = "진행 기록이 지워집니다. 길게 눌러야 시작됩니다."


func _open_settings() -> void:
	settings_panel.visible = true
	settings_btns["text"].grab_focus()


func _close_settings() -> void:
	settings_panel.visible = false


func _to_title() -> void:
	_close_pause()
	_save()
	_show_title()


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(48, 48)
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_ALL
	add_child(b)
	return b


## Whole-number UI scale from device pixel density, capped so the layout still fits.
func _fit_base() -> void:
	var ws := Vector2(get_window().size)
	var density := DisplayServer.screen_get_scale()
	if OS.has_feature("android"):
		density = DisplayServer.screen_get_dpi() / 160.0
	var fit: int
	if ws.y >= ws.x:
		fit = mini(int(ws.x / 360.0), int(ws.y / 560.0))
	else:
		fit = mini(int(ws.y / 340.0), int(ws.x / 480.0))
	var f := clampi(int(round(density)), 1, maxi(1, fit))
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	scale = Vector2(f, f)
	size = (ws / f).floor()


func _layout() -> void:
	_cancel_pointer()
	var w := size.x
	var h := size.y
	bg.size = size
	pause_panel.size = size
	closeup.size = size
	for p in [notice_panel, title_panel, settings_panel]:
		p.size = size
	var tight := w > h
	for b in _menu_btns:
		b.custom_minimum_size = Vector2(240, 38 if tight else 52)
	for vb in _menu_boxes:
		vb.add_theme_constant_override("separation", 4 if tight else 14)
	var portrait := h >= w
	var area: Rect2
	if portrait:
		var top := 48.0
		var drawer_h := 68.0
		var line_h := 56.0
		area = Rect2(0, top, w, h - top - drawer_h - line_h)
		place_label.position = Vector2(16, 10)
		place_label.size = Vector2(w - 90, 30)
		menu_btn.position = Vector2(w - 56, 0)
		line_label.position = Vector2(12, h - drawer_h - line_h)
		line_label.size = Vector2(w - 24, line_h)
		drawer.position = Vector2(0, h - drawer_h + 4)
		drawer.size = Vector2(w, 60)
		left_btn.position = Vector2(8, h - drawer_h + 2)
		right_btn.position = Vector2(w - 56, h - drawer_h + 2)
	else:
		var side := clampf(w * 0.34, 200.0, 320.0)
		area = Rect2(0, 0, w - side, h)
		var sx := w - side
		place_label.position = Vector2(sx + 12, 10)
		place_label.size = Vector2(side - 80, 30)
		menu_btn.position = Vector2(w - 56, 0)
		line_label.position = Vector2(sx + 8, 48)
		line_label.size = Vector2(side - 16, maxf(48.0, h - 48 - 128))
		drawer.position = Vector2(sx, h - 66)
		drawer.size = Vector2(side, 60)
		left_btn.position = Vector2(sx + 12, h - 126)
		right_btn.position = Vector2(w - 60, h - 126)
	var dev := maxf(1.0, scale.x)
	var device_k := maxi(1, int(floor(minf(area.size.x * dev / Art.W, area.size.y * dev / Art.H))))
	room_k = device_k / dev
	room.size = Vector2(Art.W, Art.H) * room_k
	room.position = ((area.position + (area.size - room.size) / 2) * dev).floor() / dev
	fx.position = room.position
	fx.size = room.size
	for b in [left_btn, right_btn]:
		b.custom_minimum_size = Vector2(48, 56)
		b.size = b.custom_minimum_size
	_layout_closeup()
	_refresh()


func _layout_closeup() -> void:
	var w := size.x
	var h := size.y
	var u := _closeup_units(cu_kind)
	var photo := cu_kind == "photo" or cu_kind == "fridge_photo"
	var avail := Vector2(w if photo else w - 32, h - 150)
	if w > h:
		avail = Vector2(w - 220, h - 16)
	var k := maxi(1, int(floor(minf(avail.x / u.x, avail.y / u.y))))
	var art := u * k
	if w > h:
		cu_art_rect = Rect2(Vector2(8, ((h - art.y) / 2)).floor(), art)
		cu_label.position = Vector2(art.x + 20, 24)
		cu_label.size = Vector2(w - art.x - 32, 90)
		move_btn.size = Vector2(140, 52)
		move_btn.position = Vector2(art.x + 20 + (w - art.x - 32 - 140) / 2, 130)
		return
	cu_art_rect = Rect2(((Vector2(w, h - 120) - art) / 2).floor(), art)
	cu_label.position = Vector2(16, cu_art_rect.end.y + 10)
	cu_label.size = Vector2(w - 32, 60)
	move_btn.size = Vector2(140, 52)
	move_btn.position = Vector2((w - 140) / 2, cu_art_rect.end.y + 74)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_cancel_pointer()


func _process(delta: float) -> void:
	if _new_hold >= 0.0:
		_new_hold += delta
		var bars := int(_new_hold / NEW_HOLD_S * 10.0)
		new_warn.text = "진행 기록이 지워집니다. " + "■".repeat(bars) + "□".repeat(10 - mini(10, bars))
		if _new_hold >= NEW_HOLD_S:
			_new_hold = -1.0
			restart()
			_start_game()
	if _erasing and not get_tree().paused:
		erase_t = minf(1.0, erase_t + delta / ERASE_S)
		shock = maxf(0.0, shock - delta / 0.6)
		if erase_t >= 1.0:
			_erasing = false
			shock = 0.0
			say(_line_after_erase)
	_update_fx()
	if _holding:
		_hold_t += delta
		hold_bar.value = minf(1.0, _hold_t / 1.0)
		if _hold_t >= 1.0:
			_holding = false
			restart()


# ---------------------------------------------------------------- state

func _load() -> void:
	s = _default_state()
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var data = JSON.parse_string(f.get_as_text())
		if data is Dictionary:
			for key in s.keys():
				if data.has(key):
					s[key] = data[key]
	erase_t = 1.0 if s.loss else 0.0


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(s))


func restart() -> void:
	s = _default_state()
	erase_t = 0.0
	_erasing = false
	move_id = ""
	_save()
	_close_pause()
	close_closeup()
	_enter_view("living", true)
	say("")


func mirror_sees() -> String:
	var i: int = s.ledge.find("mirror")
	if i == 2:
		return "frame_back" if s.ledge[1] == "tall" else "card"
	return "ceiling" if i == 1 else "window"


func _refresh() -> void:
	slots[0].item = "photo" if s.has_photo else ""
	for sl in slots:
		sl.queue_redraw()
	left_btn.visible = s.view == "dining"
	right_btn.visible = s.view == "living" and s.clue != ""
	room.queue_redraw()


func say(text: String) -> void:
	line_label.text = text
	line_label.modulate.a = 1.0
	if text == "":
		return
	_line_timer = get_tree().create_timer(4.0, false)
	var t := _line_timer
	t.timeout.connect(func():
		if _line_timer == t:
			line_label.text = ""
	)


func _enter_view(v: String, quiet := false) -> void:
	s.view = v
	erase_t = 1.0 if s.loss else 0.0
	_save()
	place_label.text = PLACE_NAMES[v]
	place_label.modulate.a = 1.0
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tw.tween_interval(1.4)
	if cfg.reduce_motion:
		tw.tween_callback(func(): place_label.modulate.a = 0.0)
	else:
		tw.tween_property(place_label, "modulate:a", 0.0, 0.5)
		room.modulate = Color(0.2, 0.16, 0.28)
		var fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
		fade.tween_property(room, "modulate", Color.WHITE, 0.45)
	if not quiet:
		say("")
	_refresh()


func _go(dir: int) -> void:
	if dir > 0 and s.view == "living" and s.clue != "":
		_enter_view("dining")
	elif dir < 0 and s.view == "dining":
		_enter_view("living")


# ---------------------------------------------------------------- room drawing / hits

func _update_fx() -> void:
	if fx == null:
		return
	var on := in_game and (erase_t > 0.0 or shock > 0.0)
	fx.visible = on
	if not on:
		return
	var er: Rect2i = Art.ERASE_LIVING if s.view == "living" else Art.ERASE_DINING
	var m := fx.material as ShaderMaterial
	m.set_shader_parameter("px", room_k * scale.x)
	m.set_shader_parameter("region", Vector4(er.position.x, er.position.y, er.size.x, er.size.y))
	m.set_shader_parameter("origin", Vector2(52, 168) if s.view == "living" else Vector2(46, 165))
	m.set_shader_parameter("progress", erase_t)
	m.set_shader_parameter("dim", shock)
	m.set_shader_parameter("motion", 0.0 if cfg.reduce_motion else 1.0)


func _t(key: String, make: Callable) -> Texture2D:
	if not _tex.has(key):
		_tex[key] = ImageTexture.create_from_image(make.call())
	return _tex[key]


func _sprite(ci: CanvasItem, key: String, make: Callable, bottom_center: Vector2) -> void:
	var t := _t(key, make)
	ci.draw_texture(t, (bottom_center - Vector2(t.get_width() / 2.0, t.get_height() - 1)).floor())


func draw_room(ci: CanvasItem) -> void:
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(room_k, room_k))
	if s.view == "living":
		ci.draw_texture(_t("living", func(): return Art.living_base(false)), Vector2.ZERO)
		if s.drawer_open:
			ci.draw_texture(_t("drawer_open", Art.drawer_sprite), Vector2.ZERO)
		var sees := mirror_sees()
		for i in 3:
			var id: String = s.ledge[i]
			if id != _dragging:
				var key := id + (":" + sees if id == "mirror" else "")
				_sprite(ci, key, func(): return Art.item_sprite(id, sees), Vector2(Art.SLOT_X[i], Art.SHELF_Y))
		if s.bag == "floor" or _dragging == "bag":
			ci.draw_rect(Rect2(120, 164, 42, 2), Art.WALNUT_H.lightened(0.15))
		if _dragging != "bag":
			_sprite(ci, "bag", Art.bag_sprite, Vector2(141, 168) if s.bag == "mark" else Vector2(78, 297))
	else:
		ci.draw_texture(_t("dining", Art.dining_base), Vector2.ZERO)
	if s.view == "living":
		_draw_targets(ci)
		if _dragging != "":
			var a := _drag_pos / room_k
			if _dragging == "bag":
				_sprite(ci, "bag", Art.bag_sprite, a + Vector2(0, 21))
			else:
				var id := _dragging
				var key := id + (":" + mirror_sees() if id == "mirror" else "")
				_sprite(ci, key, func(): return Art.item_sprite(id, mirror_sees()), a + Vector2(0, 18))
	ci.draw_texture(_t("vignette", Art.vignette), Vector2.ZERO)
	# CRT scanline: one device pixel at the bottom of every art row
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var dev := 1.0 / maxf(1.0, scale.x)
	if room_k * scale.x >= 2:
		var y := 0.0
		while y < room.size.y:
			ci.draw_rect(Rect2(0, y + room_k - dev, room.size.x, dev), Color(0, 0, 0, 0.28))
			y += room_k


func _draw_targets(ci: CanvasItem) -> void:
	var id := _dragging if _dragging != "" else move_id
	if id == "":
		return
	var rects: Array = []
	if id == "bag":
		rects = [Rect2(78, 82, 32, 30) if s.bag == "floor" else Rect2(36, 168, 34, 32)]
	else:
		for i in 3:
			rects.append(Rect2(SLOT_U[i] - 11, 30, 22, 32))
	for r in rects:
		_dashed(ci, Rect2(r.position * ART, r.size * ART).abs())


func _dashed(ci: CanvasItem, r: Rect2) -> void:
	var c := Art.CYAN
	r = Rect2(r.position.floor(), r.size.floor())
	for x in range(int(r.position.x), int(r.end.x), 4):
		ci.draw_rect(Rect2(x, r.position.y, 2, 1), c)
		ci.draw_rect(Rect2(x, r.end.y - 1, 2, 1), c)
	for y in range(int(r.position.y), int(r.end.y), 4):
		ci.draw_rect(Rect2(r.position.x, y, 1, 2), c)
		ci.draw_rect(Rect2(r.end.x - 1, y, 1, 2), c)


func hit(u: Vector2) -> String:
	if s.view == "dining":
		if Rect2(144, 76, 24, 24).has_point(u): return "fridge_photo"
		if Rect2(142, 30, 34, 118).has_point(u): return "fridge"
		if Rect2(14, 84, 62, 66).has_point(u): return "table_left"
		if Rect2(76, 84, 58, 66).has_point(u): return "table"
		if Rect2(44, 22, 56, 48).has_point(u): return "dwindow"
		return ""
	for i in 3:
		if Rect2(SLOT_U[i] - 11, 28, 22, 34).has_point(u):
			return "slot%d" % i
	if s.bag == "mark" and Rect2(76, 80, 36, 33).has_point(u): return "bag"
	if s.bag == "floor" and Rect2(34, 166, 36, 34).has_point(u): return "bag"
	if s.bag == "floor" and Rect2(84, 84, 18, 27).has_point(u): return "card"
	if Rect2(78, 116, 46, 16).has_point(u): return "drawer"
	if Rect2(74, 108, 102, 42).has_point(u): return "sideboard"
	if Rect2(150, 122, 30, 56).has_point(u): return "plant"
	if Rect2(70, 18, 22, 14).has_point(u): return "lamp"
	if Rect2(2, 16, 68, 130).has_point(u): return "window_seat"
	return ""


func _id_of(target: String) -> String:
	if target.begins_with("slot"):
		return s.ledge[int(target.substr(4))]
	return "bag" if target == "bag" else ""


# ---------------------------------------------------------------- input

func room_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press = true
			_press_pos = e.position
			_press_target = hit(_u(e.position))
			_dragging = ""
			_swiping = false
		elif _press:
			_press = false
			if _dragging != "":
				_drop(_u(e.position))
			elif _swiping:
				var dx: float = e.position.x - _press_pos.x
				if absf(dx) >= SWIPE_PX:
					_go(-1 if dx > 0 else 1)
			elif move_id != "":
				_move_to(_u(e.position))
			else:
				_tap(_press_target)
			_swiping = false
			room.queue_redraw()
		room.accept_event()
	elif e is InputEventMouseMotion and _press:
		if _dragging != "":
			_drag_pos = e.position
			room.queue_redraw()
		elif not _swiping and e.position.distance_to(_press_pos) > DRAG_START_PX:
			var id := _id_of(_press_target) if s.view == "living" else ""
			if id != "" and move_id == "":
				_dragging = id
				_drag_pos = e.position
			else:
				_swiping = true
			room.queue_redraw()
		room.accept_event()


func _u(local: Vector2) -> Vector2:
	return local / (room_k * ART)


func _cancel_pointer() -> void:
	_press = false
	_dragging = ""
	_swiping = false
	if room:
		room.queue_redraw()


func _drop(u: Vector2) -> void:
	var id := _dragging
	_dragging = ""
	_place(id, u)


func _move_to(u: Vector2) -> void:
	var id := move_id
	move_id = ""
	_place(id, u)


func _place(id: String, u: Vector2) -> void:
	if id == "bag":
		if s.bag == "mark" and u.y > 156:
			_move_bag("floor")
		elif s.bag == "floor" and Rect2(70, 76, 48, 42).has_point(u):
			_move_bag("mark")
		return
	for i in 3:
		if Rect2(SLOT_U[i] - 13, 24, 26, 42).has_point(u):
			var from: int = s.ledge.find(id)
			if from != i:
				var other: String = s.ledge[i]
				s.ledge[i] = id
				s.ledge[from] = other
				_after_ledge_change()
			return


func _after_ledge_change() -> void:
	_save()
	if mirror_sees() == "card" and s.clue == "":
		say("거울 속에 뭔가 비친다.")
	_refresh()


func _move_bag(dest: String) -> void:
	s.bag = dest
	if dest == "floor" and not s.loss:
		s.loss = true
		_line_after_erase = "창가 쪽이 지워져 버렸다."
		Input.vibrate_handheld(80)
		if cfg.reduce_motion:
			erase_t = 1.0
			say(_line_after_erase)
		else:
			_erasing = true
			erase_t = 0.0
			shock = 1.0
			say("")
	elif dest == "floor":
		say("가방을 내려놓았다.")
	else:
		say("제자리에 돌려놓았다.")
	_save()
	_refresh()


func _tap(target: String) -> void:
	match target:
		"slot0", "slot1", "slot2":
			var id := _id_of(target)
			if id == "mirror":
				_tap_mirror()
			else:
				open_closeup(id, "아침 식탁 사진. 컵이 두 개다." if id == "tall" else "비 오는 창가 사진이다.", id)
		"bag":
			if s.bag == "mark":
				open_closeup("bag", "내 것은 아닌데, 저 자리가 익숙하다.", "bag")
			else:
				open_closeup("bag", "원래 자리에 흔적이 남아 있다.", "bag")
		"card":
			open_closeup("card", "메모다. 11월 3일, 3층 측정실.")
			_set_clue("direct")
		"drawer":
			if not s.has_photo:
				s.has_photo = true
				s.drawer_open = true
				_save()
				_refresh()
				open_closeup("drawer", "서랍 속에 사진 한 장이 있다.")
			else:
				say("서랍은 비어 있다.")
		"sideboard":
			say("낮은 수납장이다.")
		"plant":
			say("흙이 아직 촉촉하다.")
		"lamp":
			say("불은 꺼져 있다.")
		"window_seat":
			say("여기 뭔가 있었는데, 떠오르지 않는다." if s.loss else "쿠션 두 개, 머그 두 개. 둘이 앉던 자리 같다.")
		"fridge_photo":
			open_closeup("fridge_photo", "가방 뒤에 메모를 두고, 거울로 읽곤 했구나." if s.loss else "가방 뒤 메모를 거울로 읽던 날의 사진이다.")
		"fridge":
			say("메모 하나 없이 깨끗하다.")
		"table_left":
			say("이쪽 자리가 비어 있다." if s.loss else "마주 앉는 식탁이다.")
		"table":
			say("남은 컵은 하나뿐이다." if s.loss else "컵 두 개가 마주 놓여 있다.")
		"dwindow":
			say("같은 하늘이다.")


func _tap_mirror() -> void:
	match mirror_sees():
		"card":
			open_closeup("card_mirror", "뒤집힌 글씨의 메모. 11월 3일, 3층 측정실.", "mirror")
			_set_clue("mirror")
		"window":
			open_closeup("mirror", "창밖만 비친다.", "mirror")
		"ceiling":
			open_closeup("mirror", "천장 조명이 비친다.", "mirror")
		"frame_back":
			open_closeup("mirror", "옆 액자 뒷면이 거울을 가린다.", "mirror")


func _set_clue(via: String) -> void:
	if s.clue == "":
		s.clue = via
		_save()
		_refresh()


func use_item(id: String) -> void:
	if id == "photo":
		open_closeup("photo", "같은 거실, 다른 날이다.")


# ---------------------------------------------------------------- closeup

func open_closeup(kind: String, text: String, movable := "") -> void:
	cu_kind = kind
	cu_move_id = movable
	cu_label.text = text
	move_btn.visible = movable != ""
	_cancel_pointer()
	_layout_closeup()
	closeup.visible = true
	closeup.queue_redraw()


func close_closeup() -> void:
	closeup.visible = false
	cu_kind = ""


func _begin_move() -> void:
	move_id = cu_move_id
	close_closeup()
	room.queue_redraw()


func _closeup_units(kind: String) -> Vector2:
	if kind == "":
		return Vector2(40, 40)
	return Vector2(_cu_tex().get_size())


func _cu_tex() -> Texture2D:
	var sees := mirror_sees()
	var kind := cu_kind
	return _t("cu_" + kind + ":" + sees, func(): return Art.closeup_image(kind, sees))


func draw_closeup(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, closeup.size), Color(0.02, 0.015, 0.035, 0.94))
	if cu_kind == "":
		return
	var tex := _cu_tex()
	var k := cu_art_rect.size.x / tex.get_width()
	ci.draw_texture_rect(tex, cu_art_rect, false)
	var font: Font = closeup.get_theme_default_font()
	var ink := Color("2a1a14")
	if cu_kind == "card":
		var r := Rect2(cu_art_rect.position + Art.CARD_TEXT_RECT.position * k, Art.CARD_TEXT_RECT.size * k)
		var fs := int(r.size.y * 0.3)
		ci.draw_string(font, r.position + Vector2(r.size.x * 0.08, r.size.y * 0.42), "11월 3일", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		ci.draw_string(font, r.position + Vector2(r.size.x * 0.08, r.size.y * 0.86), "3층 측정실", HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 0.9), ink)
	elif cu_kind == "card_mirror":
		var r := Rect2(cu_art_rect.position + Art.MIRROR_CARD_RECT.position * k, Art.MIRROR_CARD_RECT.size * k)
		var fs := int(r.size.y * 0.24)
		ci.draw_set_transform(Vector2(r.end.x, 0), 0.0, Vector2(-1, 1))
		ci.draw_string(font, Vector2(r.size.x * 0.1, r.position.y + r.size.y * 0.42), "11월 3일", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		ci.draw_string(font, Vector2(r.size.x * 0.1, r.position.y + r.size.y * 0.8), "3층 측정실", HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 0.85), ink)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if cu_kind == "photo" or cu_kind == "fridge_photo":
		ci.draw_rect(cu_art_rect.grow(3), Art.PAPER_D, false, 6.0)
		var below := cu_art_rect.end.y + 6
		ci.draw_rect(Rect2(0, below, closeup.size.x, closeup.size.y - below), Color(0.02, 0.015, 0.035))


# ---------------------------------------------------------------- pause

func _open_pause() -> void:
	_cancel_pointer()
	pause_panel.visible = true
	get_tree().paused = true


func _close_pause() -> void:
	pause_panel.visible = false
	get_tree().paused = false
	_holding = false
	hold_bar.value = 0


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		if settings_panel.visible:
			_close_settings()
		elif not in_game:
			return
		elif closeup.visible:
			close_closeup()
		elif pause_panel.visible:
			_close_pause()
		else:
			_open_pause()


# ---------------------------------------------------------------- test hooks

func room_to_screen(u: Vector2) -> Vector2:
	return room.get_global_transform() * (u * room_k * ART)


func ui_scale() -> int:
	return int(scale.x)


func snapshot() -> Dictionary:
	return s.duplicate(true)
