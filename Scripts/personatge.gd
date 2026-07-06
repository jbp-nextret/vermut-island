extends CharacterBody3D

const SPEED = 5.0
const SPRINT_SPEED = 10.0
const JUMP_FORCE = 8.0
const GRAVITY = 20.0

# Personalitzacio
@export var hair: AnimatedSprite3D
@export var skin: AnimatedSprite3D
@export var eyes: AnimatedSprite3D
@export var tshirt: AnimatedSprite3D
@export var jeans: AnimatedSprite3D
@export var boots: AnimatedSprite3D

@onready var sprites: Array[AnimatedSprite3D] = [
	hair,
	skin,
	eyes,
	tshirt,
	jeans,
	boots
]

var ultima_direccio = "down"

func _ready():
	Customization.aplicar_aparenca(_sprites())
	for child in get_children():
		if child is AnimatedSprite3D:
			sprites.append(child)

func play_anim(anim: String):
	print(anim)
	for sprite in sprites:
		if sprite.sprite_frames.has_animation(anim):
			sprite.play(anim)
			print(hair.is_playing(), hair.frame)
			
func actualitza_animacio(input_dir: Vector2):
	var anim = ""

	if input_dir.length() < 0.1:
		anim = "idle"
	else:
		if abs(input_dir.x) > abs(input_dir.y):
			if input_dir.x > 0:
				ultima_direccio = "right"
			else:
				ultima_direccio = "left"
		else:
			if input_dir.y > 0:
				ultima_direccio = "down"
			else:
				ultima_direccio = "up"

		anim = "walk_" + ultima_direccio

	play_anim(anim)

func _sprites() -> Dictionary:
	return {
		"hair": hair,
		"skin": skin,
		"eyes": eyes,
		"tshirt": tshirt,
		"jeans": jeans,
		"boots": boots,
	}

func canviar_color(nom_part: String, nou_color: Color) -> void:
	Customization.canviar_color(nom_part, nou_color, _sprites())

func _process(delta):
	print(hair.animation, hair.frame)
	
		
func _physics_process(delta):
	# Gravetat
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Salt
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_FORCE

	# Direcció segons les tecles
	var input_dir = Vector2.ZERO

	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1
	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1

	# Convertim a Vector3
	var direction = Vector3(input_dir.x, 0, input_dir.y)

	if direction.length() > 0:
		direction = direction.normalized()

		# Rota segons la càmera
		var camera = get_viewport().get_camera_3d()
		var cam_angle = atan2(
			camera.global_position.x - global_position.x,
			camera.global_position.z - global_position.z
		)

		direction = direction.rotated(Vector3.UP, cam_angle)

	# Velocitat
	var current_speed = SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED

	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed

	move_and_slide()

	# Actualitza les animacions
	actualitza_animacio(input_dir)

	# Mort
	if SalutJugador.vida_actual <= 0:
		print("Has mort!")
		get_tree().reload_current_scene()
