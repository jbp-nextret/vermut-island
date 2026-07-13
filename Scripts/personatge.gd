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

# Variables combat
enum Estat { NORMAL, COMBAT }
var estat: Estat = Estat.NORMAL
var atacant: bool = false

@onready var skeleton: Node3D = $Skeleton
@onready var pivot_espasa: Node3D = $Skeleton/PivotEspasa
@onready var anim_player: AnimationPlayer = $AnimationPlayer
var te_espasa: bool = true
@onready var camera_pivot: Node3D = $CameraPivot
var shake_intensitat: float = 0.0

# Estocada (atac secundari)
@export var dash_estocada_velocitat: float = 12.0
@export var dash_estocada_durada: float = 0.15
var dash_actiu: bool = false
var dash_direccio: Vector3 = Vector3.ZERO
var dash_temps_restant: float = 0.0
# Trail
@export var trail_interval: float = 0.03
@export var trail_durada: float = 0.25
@export var trail_color: Color = Color(1, 1, 1, 0.4)
var trail_temps: float = 0.0


func _ready():
	pivot_espasa.visible = false
	Customization.aplicar_aparenca(_sprites())
	anim_player.animation_finished.connect(_on_animation_finished)
	call_deferred("_reset_interpolacio")
	
func _physics_process(delta):
	# Gravetat
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if dash_actiu:
		dash_temps_restant -= delta
		velocity.x = dash_direccio.x * dash_estocada_velocitat
		velocity.z = dash_direccio.z * dash_estocada_velocitat
		move_and_slide()
		# Trail
		trail_temps += delta
		if trail_temps >= trail_interval:
			trail_temps = 0.0
			_crear_trail()
		
		if dash_temps_restant <= 0:
			dash_actiu = false
		return
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
	var direction = Vector3(input_dir.x, 0, input_dir.y)
	if direction.length() > 0:
		direction = direction.normalized()
		var camera = get_viewport().get_camera_3d()
		var cam_angle = atan2(
			camera.global_position.x - global_position.x,
			camera.global_position.z - global_position.z
		)
		direction = direction.rotated(Vector3.UP, cam_angle)
	var current_speed = SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed
	move_and_slide()
	actualitza_animacio(input_dir)
	if SalutJugador.vida_actual <= 0:
		print("Has mort!")
		get_tree().reload_current_scene()
	
func _process(delta):
	for sprite in sprites:
		if sprite == skin:
			continue
		sprite.frame = skin.frame
		sprite.frame_progress = skin.frame_progress
		sprite.flip_h = skin.flip_h
	# Camera shake
	if shake_intensitat > 0:
		camera_pivot.position = Vector3(
			randf_range(-shake_intensitat, shake_intensitat),
			randf_range(-shake_intensitat, shake_intensitat),
			0
		)
		shake_intensitat = lerp(shake_intensitat, 0.0, delta * 10.0)
		if shake_intensitat < 0.01:
			shake_intensitat = 0.0
			camera_pivot.position = Vector3.ZERO
		
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
			sprite.speed_scale = 0.6
		else:
			sprite.speed_scale = 1.0
		if sprite.animation != anim or not sprite.is_playing():
			sprite.stop()
			sprite.animation = anim
			sprite.frame = 0
			sprite.play()

func actualitza_animacio(input_dir: Vector2):
	if atacant:
		return
	var anim = ""
	if input_dir.length() < 0.1:
		anim = "idle"
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
	_actualitzar_orientacio_espasa()

func _actualitzar_orientacio_espasa():
	pivot_espasa.scale.x = -1 if mirall_horitzontal else 1

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
	
# Funcions combat
func camera_shake(intensitat: float = 0.15):
	shake_intensitat = intensitat
			
func _unhandled_input(event):
	if event.is_action_pressed("mode_combat"):
		if not te_espasa:
			return
		toggle_mode_combat()

	if estat == Estat.COMBAT and not atacant:
		if event.is_action_pressed("accio_primaria"):
			iniciar_atac(1, "tall")
		elif event.is_action_pressed("accio_secundaria"):
			iniciar_atac(2, "estocada")

func iniciar_atac(dany: int, tipus: String):
	atacant = true
	pivot_espasa.visible = true
	pivot_espasa.dany_actual = dany
	camera_shake(0.1)

	var nom_animacio = "sword_attack_" + tipus + "_" + ultima_direccio
	play_anim("attack_" + ultima_direccio, mirall_horitzontal)
	anim_player.play(nom_animacio)

	if tipus == "estocada":
		dash_actiu = true
		dash_direccio = _direccio_mirada()
		dash_temps_restant = dash_estocada_durada

func _on_animation_finished(anim_name):
	if anim_name.begins_with("sword_attack_"):
		atacant = false
		pivot_espasa.visible = false

func toggle_mode_combat():
	if estat == Estat.NORMAL:
		estat = Estat.COMBAT
		pivot_espasa.visible = true
	else:
		estat = Estat.NORMAL
		pivot_espasa.visible = false

func _on_atac_finalitzat():
	atacant = false
	
# Estocada
func _direccio_mirada() -> Vector3:
	var dir := Vector3.ZERO
	match ultima_direccio:
		"down": dir = Vector3(0, 0, 1)
		"up": dir = Vector3(0, 0, -1)
		"right": dir = Vector3(1 if not mirall_horitzontal else -1, 0, 0)
	# Rota segons la càmera, igual que fas amb el moviment normal
	var camera = get_viewport().get_camera_3d()
	var cam_angle = atan2(
		camera.global_position.x - global_position.x,
		camera.global_position.z - global_position.z
	)
	return dir.rotated(Vector3.UP, cam_angle)
# Trail
func _crear_trail():
	var ghost := Sprite3D.new()
	ghost.texture = skin.sprite_frames.get_frame_texture(skin.animation, skin.frame)
	ghost.pixel_size = skin.pixel_size
	ghost.billboard = skin.billboard
	ghost.flip_h = skin.flip_h
	ghost.modulate = trail_color
	ghost.global_transform = skin.global_transform
	get_tree().current_scene.add_child(ghost)

	var tween = create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, trail_durada)
	tween.tween_callback(ghost.queue_free)
func _reset_interpolacio():
	reset_physics_interpolation()
	$CameraPivot.reset_physics_interpolation()
	$CameraPivot/Camera3D.reset_physics_interpolation()
