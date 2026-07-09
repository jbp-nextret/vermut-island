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
var mirall_horitzontal = false

func _ready():
	sprites = [hair, skin, eyes, tshirt, jeans, boots]
	Customization.aplicar_aparenca(_sprites())
	
func _process(delta):
	pass
	for sprite in sprites:
		if sprite == skin:
			continue
		sprite.frame = skin.frame
		sprite.frame_progress = skin.frame_progress
		sprite.flip_h = skin.flip_h
		
func play_anim(anim: String, flip: bool = false):
	for sprite in sprites:
		if sprite == null:
			continue
		if not sprite.sprite_frames.has_animation(anim):
			sprite.visible = false
			continue
		sprite.visible = true
		sprite.flip_h = flip
		if anim == "idle":
			sprite.speed_scale = 0.6  # 60% de la velocitat normal, només per idle
		else:
			sprite.speed_scale = 1.0
		if sprite.animation != anim or not sprite.is_playing():
			sprite.stop()
			sprite.animation = anim
			sprite.frame = 0
			sprite.play()

func actualitza_animacio(input_dir: Vector2):
	var anim = ""
	if input_dir.length() < 0.1:
		anim = "idle"
		# no toquem mirall_horitzontal: es manté l'última direcció horitzontal
	else:
		if abs(input_dir.x) > abs(input_dir.y):
			if input_dir.x > 0:
				ultima_direccio = "right"
				mirall_horitzontal = false
			else:
				ultima_direccio = "right"
				mirall_horitzontal = true
		else:
			if input_dir.y > 0:
				ultima_direccio = "down"
			else:
				ultima_direccio = "up"
			mirall_horitzontal = false
		anim = "walk_" + ultima_direccio
	play_anim(anim, mirall_horitzontal)

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
