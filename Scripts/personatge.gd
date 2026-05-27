extends MeshInstance3D

const SPEED = 5.0
const SPRINT_SPEED = 10.0
const JUMP_FORCE = 8.0
const GRAVITY = 20.0

var velocity_y = 0.0
var on_ground = true
const GROUND_Y = 0.75

func _physics_process(delta):
	var direction = Vector3.ZERO
	
	if Input.is_action_pressed("move_right"):
		direction.x += 1
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_down"):
		direction.z += 1
	if Input.is_action_pressed("move_up"):
		direction.z -= 1
	
	if direction.length() > 0:
		direction = direction.normalized()
	
	# Sprint
	var current_speed = SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED
	
	# Moviment horitzontal
	position.x += direction.x * current_speed * delta
	position.z += direction.z * current_speed * delta
	
	# Salt i gravetat
	if on_ground and Input.is_action_just_pressed("jump"):
		velocity_y = JUMP_FORCE
		on_ground = false
	
	velocity_y -= GRAVITY * delta
	position.y += velocity_y * delta
	
	# Comprova si ha tocat terra
	if position.y <= GROUND_Y:
		position.y = GROUND_Y
		velocity_y = 0.0
		on_ground = true
	
	# Límits del terreny
	position.x = clamp(position.x, -9.0, 9.0)
	position.z = clamp(position.z, -9.0, 9.0)
