extends Control

var main: Node
var _pressed := false


func _draw() -> void:
	if main:
		main.draw_closeup(self)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_pressed = not main.cu_art_rect.has_point(e.position)
		elif _pressed:
			_pressed = false
			main.close_closeup()
		accept_event()
