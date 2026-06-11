extends Camera3D

const ZOOM_SPEED = 1.0
const MIN_ZOOM = 5.0
const MAX_ZOOM = 20.0

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			size = clamp(size - ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			size = clamp(size + ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
