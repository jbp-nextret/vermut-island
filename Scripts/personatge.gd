extends CharacterBody3D

const SPEED = 5.0
const SPRINT_SPEED = 10.0
const JUMP_FORCE = 6.0
const GRAVITY = 20.0

func _physics_process(delta):
	# Gravetat
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	
	# Salt
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_FORCE
	
	# Moviment horitzontal
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
	
	var current_speed = SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED
	
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed
	
	move_and_slide()
