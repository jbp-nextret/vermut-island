extends CharacterBody3D

const SPEED = 5.0
const SPRINT_SPEED = 10.0
const JUMP_FORCE = 8.0
const GRAVITY = 20.0

func _ready():
	add_to_group("jugador")
	
func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_FORCE
	
	var direction = Vector3.ZERO
	if Input.is_action_pressed("move_right"): direction.x += 1
	if Input.is_action_pressed("move_left"): direction.x -= 1
	if Input.is_action_pressed("move_down"): direction.z += 1
	if Input.is_action_pressed("move_up"): direction.z -= 1
	
	if direction.length() > 0:
		direction = direction.normalized()  # <-- Això hauria de mantenir velocitat constant
		
		# Rota la direcció segons la càmera
		var camera = get_viewport().get_camera_3d()
		var cam_angle = atan2(camera.global_position.x - global_position.x, 
							  camera.global_position.z - global_position.z)
		direction = direction.normalized()  # Normalitza de nou
		direction = direction.rotated(Vector3.UP, cam_angle)
	
	var current_speed = SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed
	
	move_and_slide()
# Mort
	if SalutJugador.vida_actual <= 0:
		print("Has mort!")
		get_tree().reload_current_scene()
