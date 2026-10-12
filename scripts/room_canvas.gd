extends Control

var main: Node


func _draw() -> void:
	if main:
		main.draw_room(self)


func _gui_input(e: InputEvent) -> void:
	if main:
		main.room_input(e)
