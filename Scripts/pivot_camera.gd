extends Node3D

const ZOOM_SPEED = 1.0
const MIN_ZOOM = 5.0
const MAX_ZOOM = 20.0
const ROT_SPEED = 0.3
const MAX_ROT_Y = 30.0
const MAX_ROT_X = -20.0
const MIN_ROT_X = -60.0
const BASE_ROT_X = -40.0
const BASE_ROT_Y = 0.0
const SMOOTH_SPEED = 6.0

var target_rot_x = BASE_ROT_X
var target_rot_y = BASE_ROT_Y
var target_zoom = 10.0
var rotating = false
var last_mouse_pos = Vector2.ZERO

@onready var camera = $Camera3D

func _ready():
	rotation_degrees.x = BASE_ROT_X
	rotation_degrees.y = BASE_ROT_Y

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = clamp(target_zoom - ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = clamp(target_zoom + ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			rotating = event.pressed
			last_mouse_pos = event.position
	if Input.is_action_just_pressed("reset_camera"):
			print("Reset camera")
			target_rot_x = BASE_ROT_X
			target_rot_y = BASE_ROT_Y

	if event is InputEventMouseMotion and rotating:
		var delta_mouse = event.position - last_mouse_pos
		last_mouse_pos = event.position
		target_rot_y -= delta_mouse.x * ROT_SPEED
		target_rot_x -= delta_mouse.y * ROT_SPEED * 0.5
		target_rot_y = clamp(target_rot_y, -MAX_ROT_Y, MAX_ROT_Y)
		target_rot_x = clamp(target_rot_x, MIN_ROT_X, MAX_ROT_X)

func _process(delta):
	rotation_degrees.x = lerp(rotation_degrees.x, target_rot_x, SMOOTH_SPEED * delta)
	rotation_degrees.y = lerp(rotation_degrees.y, target_rot_y, SMOOTH_SPEED * delta)
	camera.size = lerp(camera.size, target_zoom, SMOOTH_SPEED * delta)
