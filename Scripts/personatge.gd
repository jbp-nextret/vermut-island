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
# Combat màgic
@export var bola_foc_scene: PackedScene
@export var cooldown_magia: float = 0.8
var temps_darrera_magia: float = 0.0
@export var cercle_colors: Array[Color] = [Color(1.0, 0.5, 0.1), Color(1.0, 0.8, 0.2), Color(0.9, 0.2, 0.8)]
@export var cercle_durada_visible: float = 1.5

signal magia_no_disponible

# Combos i cua d'atacs
const DANY_ATAC := {"tall": 20, "estocada": 45}
const FINESTRA_COMBO := 0.45     # segons per encadenar el cop següent
var combo := 0
var temps_des_del_cop := 99.0
var atac_en_cua := ""
var temps_cua := 0.0
var vida_anterior := 0

func _ready():
	add_to_group("player")
	# Interaccions (barrica, clients...) i objecte a la mà
	var interaccio := InteraccioJugador.new()
	interaccio.name = "Interaccio"
	add_child(interaccio)
	pivot_espasa.visible = false
	Customization.aplicar_aparenca(_sprites())
	pivot_espasa.cop_encertat.connect(_on_cop_encertat)
	vida_anterior = SalutJugador.vida_actual
	SalutJugador.vida_canviat.connect(_on_vida_canviat)
	call_deferred("_reset_interpolacio")
	
func _physics_process(delta):
	temps_darrera_magia += delta
	temps_des_del_cop += delta
	if temps_cua > 0.0:
		temps_cua -= delta
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
	if is_on_floor() and Input.is_action_just_pressed("jump") and GameState.pot_moure():
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
	# Construint (o en altres modes que ho bloquegin) el personatge no es mou
	if not GameState.pot_moure():
		input_dir = Vector2.ZERO
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
	# Dins de casa, construint o servint no es pot atacar
	# (i així la Q/E no treuen l'espasa ni llancen boles de foc)
	if not GameState.pot_atacar():
		return
	if event.is_action_pressed("mode_combat"):
		if not te_espasa:
			return
		toggle_mode_combat()
	
	if estat == Estat.COMBAT:
		if event.is_action_pressed("accio_primaria"):
			_demanar_atac("tall")
		elif event.is_action_pressed("accio_secundaria"):
			_demanar_atac("estocada")
	# Atac màgic
	if event.is_action_pressed("atac_magia"):  # crea aquesta input action
		disparar_bola_foc()

## Si ja està atacant, el guarda per quan acabi (així els combos no es perden)
func _demanar_atac(tipus: String):
	if atacant:
		# Es guarda fins que acabi el cop actual (i una mica més)
		atac_en_cua = tipus
		temps_cua = 1.0
	else:
		iniciar_atac(tipus)

func iniciar_atac(tipus: String):
	atacant = true
	pivot_espasa.visible = true

	# Combo de talls: 1r, 2n (en sentit contrari) i 3r (més fort)
	combo = combo + 1 if temps_des_del_cop < FINESTRA_COMBO and combo < 3 else 1
	var dany: int = DANY_ATAC[tipus]
	if tipus == "tall" and combo == 3:
		dany = int(dany * 1.6)

	play_anim("attack_" + ultima_direccio, mirall_horitzontal)
	var animacio := anim_player.get_animation("sword_attack_" + tipus + "_" + ultima_direccio)
	var durada: float = pivot_espasa.atacar(tipus, animacio, dany, combo == 2)
	create_tween().tween_callback(_on_atac_acabat).set_delay(durada)

	if tipus == "estocada":
		dash_actiu = true
		dash_direccio = _direccio_mirada()
		dash_temps_restant = dash_estocada_durada
		
func _test_cercle():
	var cercle := Sprite3D.new()
	cercle.texture = preload("res://Sprites/Misc/magic-3.png")
	cercle.pixel_size = 0.04
	#cercle.billboard = SpriteBase3D.BILLBOARD_DISABLED
	cercle.rotation_degrees.x = -90
	get_tree().current_scene.add_child(cercle)
	cercle.global_position = global_position
	cercle.rotation_degrees.x = -90
	print("Cercle creat a: ", cercle.global_position, " textura: ", cercle.texture)
	
func _on_atac_acabat():
	atacant = false
	temps_des_del_cop = 0.0
	pivot_espasa.visible = estat == Estat.COMBAT
	if not atac_en_cua.is_empty() and temps_cua > 0.0:
		var seguent := atac_en_cua
		atac_en_cua = ""
		iniciar_atac(seguent)
	atac_en_cua = ""

## Cop encertat: sacseig i una aturada molt curta (hitstop) perquè es noti l'impacte
func _on_cop_encertat(_enemic: Node3D, dany: int):
	camera_shake(0.08 if dany < 30 else 0.16)
	_hitstop(0.045 if dany < 30 else 0.08)

func _hitstop(durada: float):
	Engine.time_scale = 0.05
	# El temporitzador ignora el time_scale, si no duraria 20 vegades més
	get_tree().create_timer(durada, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)

## Quan el jugador rep mal: parpelleig vermell i sacseig
func _on_vida_canviat(actual, _maxima):
	if actual < vida_anterior:
		camera_shake(0.2)
		for sprite in sprites:
			if sprite:
				sprite.modulate = Color(1, 0.35, 0.35)
		var t := create_tween()
		for sprite in sprites:
			if sprite:
				t.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.3)
	vida_anterior = actual

func progres_magia() -> float:
	return clampf(temps_darrera_magia / cooldown_magia, 0.0, 1.0)

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

func disparar_bola_foc():
	if temps_darrera_magia < cooldown_magia:
		magia_no_disponible.emit()
		return
	temps_darrera_magia = 0.0

	_crear_cercle_alquimia()

	var bola = bola_foc_scene.instantiate()
	get_tree().current_scene.add_child(bola)
	bola.global_position = global_position + Vector3(0, 1.0, 0)
	bola.direccio = _direccio_cap_al_cursor()


func _crear_cercle_alquimia():
	var cercle := Sprite3D.new()
	cercle.texture = preload("res://Sprites/Misc/magic-3.png")
	cercle.pixel_size = 0.04
	cercle.scale = Vector3.ONE * 0.3
	cercle.modulate = cercle_colors[0]
	cercle.modulate.a = 0.0

	add_child(cercle)  # fill del Personatge, es mou amb ell
	cercle.position = Vector3(0, 0.05, 0)
	cercle.rotation_degrees.x = -90

	var tween_aparicio = create_tween()
	tween_aparicio.set_parallel(true)
	tween_aparicio.tween_property(cercle, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_aparicio.tween_property(cercle, "modulate:a", 1.0, 0.15)

	var tween_rotacio = create_tween()
	tween_rotacio.set_loops()
	tween_rotacio.tween_property(cercle, "rotation_degrees:y", 360.0, 2.0).as_relative()

	var tween_colors = create_tween()
	tween_colors.set_loops()
	for color in cercle_colors:
		tween_colors.tween_property(cercle, "modulate", Color(color.r, color.g, color.b, 1.0), 0.4)

	var tween_final = create_tween()
	tween_final.tween_interval(cercle_durada_visible)
	tween_final.tween_callback(func():
		tween_rotacio.kill()
		tween_colors.kill()
		var fade_out = create_tween()
		fade_out.set_parallel(true)
		fade_out.tween_property(cercle, "modulate:a", 0.0, 0.5)
		fade_out.tween_property(cercle, "scale", Vector3.ONE * 1.3, 0.5)
		fade_out.chain().tween_callback(cercle.queue_free)
	)

func _direccio_cap_al_cursor() -> Vector3:
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()

	var origen = camera.project_ray_origin(mouse_pos)
	var direccio_ray = camera.project_ray_normal(mouse_pos)

	var pla = Plane(Vector3.UP, global_position.y + 1.0)
	var punt_impacte = pla.intersects_ray(origen, direccio_ray)

	if punt_impacte == null:
		return _direccio_mirada()

	var direccio = (punt_impacte - global_position)
	direccio.y = 0
	return direccio.normalized()

func _reset_interpolacio():
	reset_physics_interpolation()
	$CameraPivot.reset_physics_interpolation()
	$CameraPivot/Camera3D.reset_physics_interpolation()
