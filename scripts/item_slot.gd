extends Control

const Art = preload("res://scripts/home_art.gd")

var main: Node
var item := ""
var _pressed := false
var _icon: Texture2D


func _ready() -> void:
	custom_minimum_size = Vector2(56, 56)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color("15101a"))
	draw_rect(r.grow(-1), Art.CYAN_D if item != "" else Color(Art.CYAN_D, 0.35), false, 2.0)
	if item == "photo":
		if _icon == null:
			_icon = ImageTexture.create_from_image(Art.photo_icon())
		var k := maxf(1.0, floorf(minf(size.x - 8, size.y - 8) / _icon.get_width()))
		var s := _icon.get_size() * k
		draw_texture_rect(_icon, Rect2(((size - s) / 2).floor(), s), false)


func _gui_input(e: InputEvent) -> void:
	if item == "" or not (e is InputEventMouseButton) or e.button_index != MOUSE_BUTTON_LEFT:
		return
	if e.pressed:
		_pressed = true
	elif _pressed:
		_pressed = false
		main.use_item(item)
	accept_event()
