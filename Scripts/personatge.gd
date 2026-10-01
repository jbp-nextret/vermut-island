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

# Moviment suau en monitors de més de 60 Hz: la física va a 60 tics per segon, però el
# sprite es dibuixa en un punt intermedi entre l'últim tic i l'actual (interpolació).
var pos_fisica_anterior := Vector3.ZERO
var posicio_visual := Vector3.ZERO
var offset_esquelet := Vector3.ZERO
@onready var pivot_espasa: Node3D = $Skeleton/PivotEspasa
@onready var anim_player: AnimationPlayer = $AnimationPlayer
var te_espasa: bool = true
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
var shake_intensitat: float = 0.0   # (ja no es fa servir: ara és `trauma`)
## Sacseig de càmera: cada cop suma "trauma" (0..1). El sacseig és trauma², i es mou
## amb soroll suau (no salts aleatoris). Una mica de desplaçament i una mica de rotació.
const SACSEIG_DESPLACAMENT := 0.35
const SACSEIG_ROTACIO := 0.0     # sense inclinar la imatge: l'horitzó sempre recte
const SACSEIG_RECUPERACIO := 1.6    # trauma que es perd per segon
var trauma := 0.0
var soroll_sacseig := FastNoiseLite.new()

# Estocada (atac secundari)
@export var dash_estocada_velocitat: float = 12.0
@export var dash_estocada_durada: float = 0.18
var dash_actiu: bool = false
var dash_direccio: Vector3 = Vector3.ZERO
var dash_temps_restant: float = 0.0
# Trail
@export var trail_interval: float = 0.03
@export var trail_durada: float = 0.25
@export var trail_color: Color = Color(0.6, 0.85, 1.0, 0.45)
var trail_temps: float = 0.0
# Combat màgic
@export var bola_foc_scene: PackedScene
@export var cooldown_magia: float = 0.8
var temps_darrera_magia: float = 0.0
@export var cercle_colors: Array[Color] = [Color(1.0, 0.5, 0.1), Color(1.0, 0.8, 0.2), Color(0.9, 0.2, 0.8)]
@export var cercle_durada_visible: float = 1.5

signal magia_no_disponible

# Atacs màgics a curta distància (substitueixen l'espasa)
var combat: CombatMagic
var atac_en_cua := ""        # si prems mentre es recarrega, surt quan pugui
var temps_cua := 0.0
const MEMORIA_ATAC := 0.45   # una mica més que la recàrrega del tall
var vida_anterior := 0

# Les capes del personatge (pell, roba, cabell...) són retallades i escriuen profunditat
# (així tenen vora i l'aigua no les tapa). Perquè no parpellegin al mateix pla, cada capa
# s'avança una mica cap a la càmera segons el seu ordre, exactament en la direcció en què
# mira la càmera: amb càmera ortogràfica això no les mou gens a la pantalla, i no queden
# escletxes entre capes.
const SEPARACIO_CAPES := 0.002
var posicions_capes := {}

func _ready():
	offset_esquelet = skeleton.position
	pos_fisica_anterior = global_position
	posicio_visual = global_position
	add_to_group("player")
	# Interaccions (barrica, clients...) i objecte a la mà
	var interaccio := InteraccioJugador.new()
	interaccio.name = "Interaccio"
	add_child(interaccio)
	pivot_espasa.visible = false
	Customization.aplicar_aparenca(_sprites())
	# L'espasa ja no es fa servir: els atacs són màgics
	pivot_espasa.visible = false
	pivot_espasa.process_mode = Node.PROCESS_MODE_DISABLED
	combat = CombatMagic.new()
	combat.name = "CombatMagic"
	add_child(combat)
	combat.cop_encertat.connect(_on_cop_encertat)
	vida_anterior = SalutJugador.vida_actual
	SalutJugador.vida_canviat.connect(_on_vida_canviat)
	call_deferred("_reset_interpolacio")
	
func _physics_process(delta):
	pos_fisica_anterior = global_position
	temps_darrera_magia += delta
	if temps_cua > 0.0:
		temps_cua -= delta
		if temps_cua <= 0.0:
			atac_en_cua = ""
		elif not atac_en_cua.is_empty():
			_atac_magic(atac_en_cua)
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
	_interpolar_visual()
	_separar_capes()
	for sprite in sprites:
		if sprite == skin:
			continue
		sprite.frame = skin.frame
		sprite.frame_progress = skin.frame_progress
		sprite.flip_h = skin.flip_h
	# Sacseig de càmera
	_actualitzar_sacseig(delta)
		
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
	pass   # l'espasa ja no es fa servir

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
	
func _separar_capes():
	var cap_camera: Vector3 = camera.global_basis.z   # l'eix de visió, cap a la càmera
	for sprite in sprites:
		if sprite == null:
			continue
		if not posicions_capes.has(sprite):
			posicions_capes[sprite] = sprite.position
		sprite.global_position = sprite.get_parent().to_global(posicions_capes[sprite]) + cap_camera * SEPARACIO_CAPES * (sprite.render_priority + 1)

# Funcions combat
func camera_shake(intensitat: float = 0.15):
	# Els valors d'abans (0,08-0,2) equivalen a un terç-mig de trauma
	trauma = minf(1.0, trauma + intensitat * 2.5 * SettingsManager.valor("sacseig"))

func _actualitzar_sacseig(delta: float):
	if trauma <= 0.0:
		return
	trauma = maxf(0.0, trauma - SACSEIG_RECUPERACIO * delta)
	var forca := trauma * trauma
	var t := Time.get_ticks_msec() * 0.06
	camera.h_offset = SACSEIG_DESPLACAMENT * forca * soroll_sacseig.get_noise_2d(t, 0.0)
	camera.v_offset = SACSEIG_DESPLACAMENT * forca * soroll_sacseig.get_noise_2d(0.0, t)
	camera.rotation.z = SACSEIG_ROTACIO * forca * soroll_sacseig.get_noise_2d(t, 100.0)
	if trauma <= 0.0:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		camera.rotation.z = 0.0
			
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
			_atac_magic("tall")
		elif event.is_action_pressed("accio_secundaria"):
			_atac_magic("estocada")
	# Atac màgic
	if event.is_action_pressed("atac_magia"):  # crea aquesta input action
		disparar_bola_foc()

## Llança un atac màgic cap al ratolí. Si encara es recarrega, el guarda uns instants.
## `direccio` buida = cap al ratolí (des de la barra d'accions es passa la de la mirada)
func _atac_magic(tipus: String, direccio := Vector3.ZERO):
	if direccio == Vector3.ZERO:
		direccio = _direccio_cap_al_cursor()
	var fet: bool = combat.tall(direccio) if tipus == "tall" else combat.estocada(direccio)
	if not fet:
		if atac_en_cua != tipus:
			atac_en_cua = tipus
			temps_cua = MEMORIA_ATAC
		return
	atac_en_cua = ""
	temps_cua = 0.0
	# El cos es gira cap on ataca i fa l'animació d'atac
	_mirar_cap_a(direccio)
	if tipus == "estocada":
		dash_actiu = true
		dash_direccio = direccio
		dash_temps_restant = dash_estocada_durada
		# Invulnerable mentre dura el dash (per travessar enemics sense rebre)
		SalutJugador.invulnerable_fins = maxf(SalutJugador.invulnerable_fins, Time.get_ticks_msec() / 1000.0 + dash_estocada_durada + 0.1)
	atacant = true
	play_anim("attack_" + ultima_direccio, mirall_horitzontal)
	create_tween().tween_callback(func(): atacant = false).set_delay(0.25)

## Converteix una direcció del món en "up/down/right" (+ mirall) relatiu a la càmera
func _mirar_cap_a(direccio: Vector3):
	var camera = get_viewport().get_camera_3d()
	var cam_angle = atan2(camera.global_position.x - global_position.x, camera.global_position.z - global_position.z)
	var local := direccio.rotated(Vector3.UP, -cam_angle)
	if absf(local.x) > absf(local.z):
		ultima_direccio = "right"
		mirall_horitzontal = local.x < 0
	else:
		ultima_direccio = "down" if local.z > 0 else "up"
		mirall_horitzontal = false

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
	estat = Estat.COMBAT if estat == Estat.NORMAL else Estat.NORMAL

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

func disparar_bola_foc(direccio := Vector3.ZERO):
	if temps_darrera_magia < cooldown_magia:
		magia_no_disponible.emit()
		return
	temps_darrera_magia = 0.0

	_crear_cercle_alquimia()

	var bola = bola_foc_scene.instantiate()
	get_tree().current_scene.add_child(bola)
	bola.global_position = global_position + Vector3(0, 1.0, 0)
	bola.direccio = direccio if direccio != Vector3.ZERO else _direccio_cap_al_cursor()


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

## On es dibuixa el personatge: entre la posició del tic de física anterior i l'actual
func _interpolar_visual():
	if pos_fisica_anterior.distance_to(global_position) > 2.0:
		pos_fisica_anterior = global_position   # ha aparegut en un altre lloc: sense interpolar
	var fraccio := Engine.get_physics_interpolation_fraction()
	posicio_visual = pos_fisica_anterior.lerp(global_position, fraccio)
	skeleton.position = offset_esquelet + (posicio_visual - global_position)

func _reset_interpolacio():
	pos_fisica_anterior = global_position
	posicio_visual = global_position
	reset_physics_interpolation()
	$CameraPivot.reset_physics_interpolation()
	$CameraPivot/Camera3D.reset_physics_interpolation()
