extends Camera3D

const ZOOM_SPEED = 0.5
const MIN_ZOOM = 6.0
const MAX_ZOOM = 12.0

var target_zoom = 10.0
var target_size = 7.0

func _ready():
	position.z = target_zoom

func _process(delta):
	size = lerp(size, target_size, delta * 8.0)

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_size = clamp(target_size - ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_size = clamp(target_size + ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
