extends Node
## Drives real pointer events through the viewport for both routes and saves captures.
## User args: --out=<dir> saves PNGs; --watch slows input and shows steps/pointer on screen.

const MainScene = preload("res://scenes/main.tscn")
## Synthetic events carry this device id; real mouse input is swallowed so a hovering cursor cannot interfere.
const TEST_DEVICE := 4242

var out_dir := ""
var watch := false
var main: Control
var fails: Array[String] = []
var checks := 0
var caption: Label
var marker: Control
var _marker_pos := Vector2(-100, -100)
var _marker_down := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a == "--watch":
			watch = true
	if FileAccess.file_exists("user://home_demo.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://home_demo.json"))
	if FileAccess.file_exists("user://settings.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.json"))
	_build_overlay()
	await _spawn()
	if not main.has_method("restart"):
		await _finish_with(["main scene did not load"])
		return
	print("SIZES window=%s ui_scale=%d main=%s room_k=%s device_px_per_art_px=%s" % [DisplayServer.window_get_size(), main.ui_scale(), main.size, main.room_k, main.room_k * main.ui_scale()])
	await _first_launch()
	await _route_shortcut()
	await _route_preserve()
	await _title_and_settings()
	await _reload_and_landscape()
	await _new_game_hold()
	await _finish_with(fails)


func _input(e: InputEvent) -> void:
	if (e is InputEventMouse or e is InputEventScreenTouch or e is InputEventScreenDrag) and e.device != TEST_DEVICE:
		get_viewport().set_input_as_handled()


func _finish_with(f: Array) -> void:
	print("RESULT checks=%d fails=%d" % [checks, f.size()])
	for x in f:
		print("FAIL ", x)
	if watch:
		caption.text = "완료: 검사 %d개 / 실패 %d개" % [checks, f.size()]
		if f.size() > 0:
			caption.text += "\n" + "\n".join(f)
		await get_tree().create_timer(6.0).timeout
	get_tree().quit(1 if f.size() > 0 else 0)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	marker = Control.new()
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.set_anchors_preset(Control.PRESET_FULL_RECT)
	marker.draw.connect(func():
		var c := Color(1, 0.2, 0.3) if _marker_down else Color(1, 1, 1)
		marker.draw_arc(_marker_pos, 16, 0, TAU, 32, Color.BLACK, 6)
		marker.draw_arc(_marker_pos, 16, 0, TAU, 32, c, 3)
		if _marker_down:
			marker.draw_circle(_marker_pos, 6, c)
	)
	marker.visible = watch
	layer.add_child(marker)
	caption = Label.new()
	caption.visible = watch
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color.WHITE)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 8)
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Malgun Gothic", "sans-serif"])
	caption.add_theme_font_override("font", sys)
	caption.position = Vector2(10, 52)
	layer.add_child(caption)


func step(text: String) -> void:
	print("STEP ", text)
	if watch:
		caption.size = Vector2(DisplayServer.window_get_size().x - 20, 80)
		caption.text = text
		await get_tree().create_timer(0.9).timeout


func _spawn() -> void:
	if main:
		main.queue_free()
		await get_tree().process_frame
	main = MainScene.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame


func check(cond: bool, label: String) -> void:
	checks += 1
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		fails.append(label)
	if watch:
		caption.text = ("✔ " if cond else "✘ ") + label
		await get_tree().create_timer(0.5 if cond else 2.0).timeout


func _set_marker(pos: Vector2, down: bool) -> void:
	_marker_pos = pos
	_marker_down = down
	marker.queue_redraw()


func _btn(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.device = TEST_DEVICE
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	get_viewport().push_input(e, true)
	_set_marker(pos, pressed)


func _motion(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.device = TEST_DEVICE
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(e, true)
	_set_marker(pos, true)


func _pause(t: float) -> void:
	if watch:
		await get_tree().create_timer(t).timeout


func center(c: Control) -> Vector2:
	return c.get_global_transform() * (c.size / 2)


func tap(pos: Vector2) -> void:
	_set_marker(pos, false)
	await _pause(0.45)
	_btn(pos, true)
	await get_tree().process_frame
	await _pause(0.15)
	_btn(pos, false)
	await get_tree().process_frame
	await get_tree().process_frame
	await _pause(0.6)


func tap_room(u: Vector2) -> void:
	await tap(main.room_to_screen(u))


func drag_room(a: Vector2, b: Vector2) -> void:
	var pa: Vector2 = main.room_to_screen(a)
	var pb: Vector2 = main.room_to_screen(b)
	_set_marker(pa, false)
	await _pause(0.45)
	_btn(pa, true)
	await get_tree().process_frame
	var n := 30 if watch else 8
	for i in range(1, n + 1):
		_motion(pa.lerp(pb, float(i) / n))
		await get_tree().process_frame
		await _pause(0.02)
	await _pause(0.2)
	_btn(pb, false)
	await get_tree().process_frame
	await get_tree().process_frame
	await _pause(0.6)


func close_cu() -> void:
	await tap(Vector2(6, 6))


func shot(name: String) -> void:
	await get_tree().create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	if out_dir == "":
		return
	marker.visible = false
	caption.visible = false
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	marker.visible = watch
	caption.visible = watch


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func button(panel: Control, text: String) -> Button:
	for b in panel.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(text):
			return b
	return null


func _first_launch() -> void:
	await step("[최초 실행] 내용 안내 화면")
	await check(main.notice_panel.visible and not main.title_panel.visible, "최초 실행 시 내용 안내")
	await shot("00a_notice")
	await tap(center(button(main.notice_panel, "확인")))
	await check(main.title_panel.visible and not main.continue_btn.visible, "타이틀: 기록 없으면 이어하기 숨김")
	await shot("00b_title")
	await step("새로 시작")
	await tap(center(main.new_btn))
	await check(main.in_game and not main.title_panel.visible, "게임 시작")


func _route_shortcut() -> void:
	main.restart()
	await step("[쉬운 길] 시작 화면")
	await shot("01_start")
	await step("서랍을 탭해 옛 사진을 얻는다")
	await tap_room(Vector2(100, 124))
	await check(main.closeup.visible and main.cu_kind == "drawer", "서랍 확대 화면")
	await check(main.s.has_photo, "사진 획득")
	await close_cu()
	await check(not main.closeup.visible, "바깥 탭으로 확대 닫힘")
	await step("아래 칸의 사진을 탭해 크게 본다")
	await tap(center(main.slots[0]))
	await check(main.cu_kind == "photo", "옛 사진 확대")
	await shot("02_past_photo")
	await close_cu()
	await step("가방을 탭: 조사만 하고 옮기지 않는다")
	await tap_room(Vector2(94, 104))
	await check(main.cu_kind == "bag" and main.move_btn.visible, "가방 확대와 옮기기 버튼")
	await check(main.s.bag == "mark", "탭으로는 가방이 안 움직임")
	await shot("03_bag_closeup")
	await close_cu()
	await step("가방을 벽 쪽에 놓기: 취소되어야 한다")
	await drag_room(Vector2(94, 104), Vector2(40, 60))
	await check(main.s.bag == "mark" and not main.s.loss, "엉뚱한 곳에 놓으면 취소")
	await step("가방을 바닥으로 끌어내린다 (지름길)")
	await drag_room(Vector2(94, 104), Vector2(110, 190))
	await check(main.s.bag == "floor" and main.s.loss, "가방 이동 → 기억 손실 시작")
	await wait(0.5)
	await shot("04a_erasing_early")
	await wait(0.9)
	await shot("04b_erasing_mid")
	await wait(1.0)
	await shot("04c_erasing_late")
	await wait(1.5)
	await check(main.erase_t >= 1.0 and main.shock == 0.0 and main.fx.visible, "기억 왜곡 효과 완료 후 유지")
	await shot("04_shortcut_loss")
	await step("드러난 카드를 탭해 읽는다")
	await tap_room(Vector2(93, 95))
	await check(main.s.clue == "direct" and main.cu_kind == "card", "카드를 직접 읽음")
	await shot("05_card")
	await close_cu()
	await check(main.right_btn.visible, "다음 구역 열림")
	await step("오른쪽 화살표로 식탁 구역에 간다")
	await tap(center(main.right_btn))
	await check(main.s.view == "dining", "식탁 구역 진입")
	await wait(0.3)
	await shot("06_dining_loss")
	await step("냉장고 사진: 원래 해결법을 뒤늦게 본다")
	await tap_room(Vector2(156, 88))
	await check(main.cu_kind == "fridge_photo", "냉장고 사진 확대")
	await shot("07_fridge_photo")
	await close_cu()
	await step("거실로 돌아가 가방을 제자리에 놓는다")
	await tap(center(main.left_btn))
	await drag_room(Vector2(52, 186), Vector2(94, 100))
	await check(main.s.bag == "mark" and main.s.loss, "가방은 돌아오고 손실은 남음")


func _route_preserve() -> void:
	main.restart()
	await step("[어려운 길] 처음부터 다시 시작")
	await step("거울을 탭: 지금은 천장만 비친다")
	await tap_room(Vector2(134, 40))
	await check(main.cu_kind == "mirror", "거울 확대 (천장)")
	await close_cu()
	await step("거울을 오른쪽 칸으로 끌어 옮긴다")
	await drag_room(Vector2(134, 42), Vector2(162, 42))
	await check(main.s.ledge == ["small", "tall", "mirror"], "드래그로 자리 교환")
	await check(main.mirror_sees() == "frame_back", "큰 액자가 거울 시야를 가림")
	await step("탭 대체 조작: 큰 액자 확대 → 옮기기 → 왼쪽 칸 탭")
	await tap_room(Vector2(134, 46))
	await check(main.cu_kind == "tall", "큰 액자 확대")
	await tap(center(main.move_btn))
	await check(main.move_id == "tall" and not main.closeup.visible, "옮기기 모드")
	await shot("08_move_mode")
	await tap_room(Vector2(106, 46))
	await check(main.s.ledge == ["tall", "small", "mirror"], "사진 속 순서로 복원")
	await check(main.mirror_sees() == "card", "거울에 카드가 비침")
	await shot("09_arranged")
	await step("거울을 탭해 뒤집힌 글씨를 읽는다")
	await tap_room(Vector2(162, 40))
	await check(main.cu_kind == "card_mirror" and main.s.clue == "mirror", "거울로 단서 확보")
	await check(not main.s.loss and main.s.bag == "mark", "손실 없음, 가방 그대로")
	await shot("10_mirror_card")
	await close_cu()
	await step("왼쪽으로 스와이프해 식탁 구역에 간다")
	await drag_room(Vector2(90, 150), Vector2(20, 150))
	await check(main.s.view == "dining", "스와이프 이동")
	await wait(0.3)
	await shot("11_dining_kept")
	await step("일시정지 메뉴")
	await tap(center(main.menu_btn))
	await check(get_tree().paused, "일시정지")
	await shot("12_pause")


func _title_and_settings() -> void:
	await step("[타이틀] 일시정지 → 타이틀로")
	await tap(center(button(main.pause_panel, "타이틀로")))
	await check(main.title_panel.visible and main.continue_btn.visible and not get_tree().paused, "타이틀에 이어하기 표시")
	await step("설정: 글자 크게, 움직임 줄이기")
	await tap(center(button(main.title_panel, "설정")))
	await tap(center(main.settings_btns["text"]))
	await tap(center(main.settings_btns["reduce_motion"]))
	await check(main.theme.default_font_size == 21 and main.cfg.reduce_motion, "설정 적용")
	await shot("00c_settings")
	await tap(center(button(main.settings_panel, "닫기")))
	await step("이어하기")
	await tap(center(main.continue_btn))
	await check(main.in_game and main.s.clue == "mirror", "이어하기로 같은 상태 복귀")


func _new_game_hold() -> void:
	await step("[새로 시작] 짧게 누르면 지워지지 않아야 한다")
	await tap(center(main.menu_btn))
	await tap(center(button(main.pause_panel, "타이틀로")))
	await tap(center(main.new_btn))
	await check(main.title_panel.visible and main.s.clue == "mirror", "짧게 누르면 기록 유지")
	await step("길게 눌러 새로 시작")
	var p := center(main.new_btn)
	_set_marker(p, false)
	_btn(p, true)
	await wait(0.5)
	await shot("16_new_hold")
	await wait(1.0)
	_btn(p, false)
	await get_tree().process_frame
	await check(main.in_game and main.s.clue == "" and not main.s.loss, "길게 누르면 새 게임")


func _reload_and_landscape() -> void:
	await step("[저장] 다시 실행한 것처럼 불러오기")
	await _spawn()
	await check(not main.notice_panel.visible and main.title_panel.visible and main.theme.default_font_size == 21, "재실행: 안내 생략, 설정 유지")
	await tap(center(main.continue_btn))
	await check(main.s.clue == "mirror" and main.s.view == "dining", "저장 상태 복원")
	await step("[가로 화면] 창을 가로로 바꾼다")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await wait(0.4)
	main._go(-1)
	await wait(0.3)
	print("SIZES landscape ui_scale=%d main=%s room_k=%s device_px_per_art_px=%s" % [main.ui_scale(), main.size, main.room_k, main.room_k * main.ui_scale()])
	await check(main.room.position.x + main.room.size.x <= main.size.x - 150, "가로 배치: 오른쪽 패널 분리")
	await shot("13_landscape")
	await tap_room(Vector2(162, 40))
	await shot("14_landscape_closeup")
	await close_cu()
	await tap(center(main.slots[0]))
	await shot("15_landscape_photo")
	await close_cu()
	await tap(center(main.menu_btn))
	await tap(center(button(main.pause_panel, "타이틀로")))
	await check(_inside(main.continue_btn) and _inside(button(main.title_panel, "설정")), "가로 타이틀 버튼이 화면 안")
	await shot("17_landscape_title")
	await tap(center(button(main.title_panel, "설정")))
	await check(_inside(button(main.settings_panel, "닫기")), "가로 설정 버튼이 화면 안")
	await shot("18_landscape_settings")
	await tap(center(button(main.settings_panel, "닫기")))
	await tap(center(main.continue_btn))


func _inside(c: Control) -> bool:
	var top := c.get_global_transform() * Vector2.ZERO
	var bottom := c.get_global_transform() * c.size
	return top.y >= 0 and bottom.y <= DisplayServer.window_get_size().y
