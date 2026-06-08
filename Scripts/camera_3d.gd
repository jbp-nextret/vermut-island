extends Camera3D

const ZOOM_SPEED = 1.0
const MIN_ZOOM = 5.0
const MAX_ZOOM = 20.0
const FOLLOW_SPEED = 5.0

var target: Node3D

func _ready():
	target = get_node("../Personatge")

func _process(delta):
	if target:
		var target_pos = target.position + Vector3(0, 5, 8)
		position = position.lerp(target_pos, FOLLOW_SPEED * delta)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			size = clamp(size - ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			size = clamp(size + ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
