extends CharacterBody3D
class_name Barca
## Barca que el jugador condueix lliurement pel mar per anar a les illetes.
##
##  - F a prop (des del moll o la platja): hi puja. Els companys del grup també hi pugen.
##  - WASD: cap on vols anar (relatiu a la càmera, com caminant). La barca gira cap allà
##    i accelera; amb Shift va més ràpid. Sense tecles, va frenant sola.
##  - F a prop de terra: en baixa (busca el tros de terra o moll més proper).
##
## La forma de la barca és una càpsula estirada: xoca amb les illes (blocs d'herba), però
## passa per sobre de la sorra de les platges, que és sota l'aigua.
## El model (`Model`) és provisional: es pot substituir per un .glb propi mentre la proa
## miri cap a -Z i la coberta quedi a l'alçada de `ALCADA_COBERTA`.

@export var velocitat_max := 6.5
@export var velocitat_turbo := 10.0       ## amb sprint
@export var acceleracio := 4.5
@export var fregament := 2.2              ## frenada quan no es prem res
@export var gir := 2.2                    ## rad/s
@export var calat := 0.05                 ## quant s'enfonsa per sota del nivell del mar
## Fins que no es completi aquesta missió la barca no hi és (p. ex. "fusta_moll").
## Buit: sempre disponible.
@export var missio_requerida := ""
@export var radi_desembarcar := 4.0
@export var limit_mar := 62.0

const ALCADA_COBERTA := 0.25
## Seients: 0 = qui condueix (popa), 1 i 2 = companys (proa), 3 = la criatura (a la punta)
const SEIENTS := [Vector3(0.0, ALCADA_COBERTA, 1.05), Vector3(-0.42, ALCADA_COBERTA, -0.55), Vector3(0.42, ALCADA_COBERTA, -0.55), Vector3(0.0, ALCADA_COBERTA, -1.6)]
## Diferència entre els peus i l'origen del personatge
const ALCADA_PEUS := 0.19
const MEITAT_LLARG := 1.7   # per trobar el punt de la barca més proper al jugador

@onready var model: Node3D = $Model
@onready var forma: CollisionShape3D = $Forma
@onready var estela: CPUParticles3D = $Model/Estela

var conductor: Node3D = null
var rumb := 0.0          # cap on mira la proa (rotation.y)
var velocitat := 0.0     # endavant (+) o enrere (-)
var gir_actual := 0.0
var temps := 0.0
var lloc_inicial: Transform3D

# Interpolació visual manual (com el jugador)
var pos_anterior := Vector3.ZERO
var rumb_anterior := 0.0

var indicador: Label3D
var punt_baixada = null    # Vector3 o null
var temps_cerca := 0.0

func _ready():
	add_to_group("interactuables")
	add_to_group("barques")
	# Primer es mou la barca i després el jugador i els companys s'hi asseuen
	process_physics_priority = -10
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	lloc_inicial = global_transform
	rumb = rotation.y
	_ajustar_alcada()
	pos_anterior = global_position
	rumb_anterior = rumb

	indicador = Label3D.new()
	indicador.top_level = true
	indicador.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	indicador.no_depth_test = true
	indicador.font_size = 44
	indicador.outline_size = 12
	indicador.pixel_size = 0.004
	indicador.visible = false
	add_child(indicador)

	# El jugador no empeny la barca (si no, en caminar pel moll la desplaçaria)
	var jugador := get_tree().get_first_node_in_group("player")
	if jugador is PhysicsBody3D:
		add_collision_exception_with(jugador)

	_actualitzar_disponible()
	if not missio_requerida.is_empty():
		Missions.missio_completada.connect(func(_m): _actualitzar_disponible())

func disponible() -> bool:
	return missio_requerida.is_empty() or Missions.completada(missio_requerida)

func _actualitzar_disponible():
	var si := disponible()
	visible = si
	forma.disabled = not si

func _exit_tree():
	if conductor:
		GameState.a_barca = false

# ─────────────── Interacció (pujar)

func pot_interactuar(jugador: Node) -> bool:
	return conductor == null and disponible() and not GameState.a_barca

func text_interaccio(_jugador: Node) -> String:
	return "Pujar a la barca"

## El punt de la barca més proper al jugador (perquè s'hi pugui pujar per qualsevol costat)
func punt_interaccio() -> Vector3:
	var jugador := get_tree().get_first_node_in_group("player") as Node3D
	var eix := endavant()
	if jugador == null:
		return global_position
	var cap := jugador.global_position - global_position
	var t := clampf(cap.dot(eix), -MEITAT_LLARG, MEITAT_LLARG)
	var punt := global_position + eix * t
	# ...i fins a la borda del costat del jugador
	var costat := jugador.global_position - punt
	costat.y = 0.0
	return punt + costat.limit_length(0.8) + Vector3.UP * 0.6

func interactuar(interaccio: Node) -> void:
	var jugador := interaccio.get_parent()
	if not jugador.has_method("pujar_a_barca"):
		return
	conductor = jugador
	jugador.pujar_a_barca(self)
	velocitat = 0.0

func baixar():
	if conductor == null:
		return
	if punt_baixada == null:
		punt_baixada = _buscar_terra()
	if punt_baixada == null:
		EventBus.avis.emit("No hi ha terra a prop per baixar")
		return
	var jugador := conductor
	conductor = null
	velocitat = 0.0
	jugador.baixar_de_barca(punt_baixada)
	punt_baixada = null
	indicador.visible = false

func _unhandled_input(event):
	if conductor and event.is_action_pressed("interactuar") and GameState.pot_moure():
		get_viewport().set_input_as_handled()
		baixar()

# ─────────────── Seients

func endavant() -> Vector3:
	return Vector3(-sin(rumb), 0.0, -cos(rumb))

## On s'ha de posar l'origen de qui seu al seient `i`
func seient(i: int) -> Vector3:
	var s: Vector3 = SEIENTS[clampi(i, 0, SEIENTS.size() - 1)]
	return global_position + s.rotated(Vector3.UP, rumb) + Vector3.UP * (ALCADA_PEUS + _balanceig())

# ─────────────── Conducció

func _physics_process(delta):
	pos_anterior = global_position
	rumb_anterior = rumb
	temps += delta
	if not visible:
		return

	var dir := Vector3.ZERO
	var turbo := false
	if conductor and GameState.pot_moure():
		var entrada := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if entrada.length() > 0.1:
			dir = Vector3(entrada.x, 0, entrada.y).normalized().rotated(Vector3.UP, _angle_camera())
		turbo = Input.is_action_pressed("sprint")

	var gir_desitjat := 0.0
	var objectiu := 0.0
	if dir != Vector3.ZERO:
		var rumb_desitjat := atan2(-dir.x, -dir.z)
		var diferencia := angle_difference(rumb, rumb_desitjat)
		gir_desitjat = clampf(diferencia * 4.0, -1.0, 1.0) * gir
		# Si ha de girar molt, primer gira i després accelera (no fa marxa enrere)
		var alineacio := clampf(cos(diferencia), 0.0, 1.0)
		objectiu = (velocitat_turbo if turbo else velocitat_max) * (0.25 + 0.75 * alineacio * alineacio)
		velocitat = move_toward(velocitat, objectiu, acceleracio * delta)
	else:
		velocitat = move_toward(velocitat, 0.0, fregament * delta)
	gir_actual = lerpf(gir_actual, gir_desitjat, minf(1.0, 6.0 * delta))
	_girar(gir_actual * delta)

	velocity = endavant() * velocitat
	velocity.y = 0.0
	var abans := velocitat
	move_and_slide()
	if get_slide_collision_count() > 0:
		# Ha topat amb una illa: perd velocitat (i si anava ràpid, es nota)
		var real := Vector2(get_real_velocity().x, get_real_velocity().z).length()
		velocitat = signf(velocitat) * minf(absf(velocitat), real)
		if abans > 4.0 and real < abans * 0.5 and conductor and conductor.has_method("camera_shake"):
			conductor.camera_shake(0.08)
	# Que no se'n vagi del mapa
	global_position.x = clampf(global_position.x, -limit_mar, limit_mar)
	global_position.z = clampf(global_position.z, -limit_mar, limit_mar)
	_ajustar_alcada()

	# Busca on es pot baixar de tant en tant (per ensenyar "[F] Baixar")
	if conductor:
		temps_cerca -= delta
		if temps_cerca <= 0.0:
			temps_cerca = 0.25
			punt_baixada = _buscar_terra() if absf(velocitat) < 3.5 else null

## Gira només si la barca hi cap (si no, quedaria encastada a la riba)
func _girar(angle: float):
	if absf(angle) < 0.0001:
		return
	var nou := Transform3D(Basis(Vector3.UP, rumb + angle), global_position)
	var consulta := PhysicsShapeQueryParameters3D.new()
	var shape := forma.shape.duplicate() as CapsuleShape3D
	shape.radius -= 0.06
	shape.height -= 0.12
	consulta.shape = shape
	consulta.transform = nou * forma.transform
	consulta.collision_mask = collision_mask
	var excloure: Array[RID] = [get_rid()]
	if conductor:
		excloure.append(conductor.get_rid())
	consulta.exclude = excloure
	if get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty():
		rumb += angle
		rotation.y = rumb
	else:
		gir_actual = 0.0

func _ajustar_alcada():
	var mon := get_tree().current_scene
	if mon and mon.has_method("nivell_aigua"):
		global_position.y = mon.nivell_aigua() - calat

func _balanceig() -> float:
	return sin(temps * 1.7) * 0.045

func _angle_camera() -> float:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return 0.0
	var enrere := camera.global_basis.z
	return atan2(enrere.x, enrere.z)

## El tros de terra (herba, sorra o moll) més proper on es pot baixar, o null
func _buscar_terra():
	var espai := get_world_3d().direct_space_state
	var nivell := global_position.y + calat
	var millor = null
	var millor_puntuacio := INF
	var excloure: Array[RID] = [get_rid()]
	if conductor:
		excloure.append(conductor.get_rid())
	for anell: float in [1.6, 2.2, 2.8, 3.4, radi_desembarcar]:
		for i in 16:
			var angle := TAU * i / 16.0
			var p := global_position + Vector3(cos(angle), 0, sin(angle)) * anell
			var raig := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p + Vector3.DOWN * 3.0, 1)
			raig.exclude = excloure
			var cop := espai.intersect_ray(raig)
			if cop.is_empty() or cop.normal.y < 0.7:
				continue
			# Ni el fons del mar ni un arbre: terra a la vora de l'aigua (o per sobre)
			if cop.position.y < nivell - 0.55 or cop.position.y > nivell + 1.2:
				continue
			if not (cop.collider is GridMap or cop.collider.is_in_group("moll")):
				continue
			var puntuacio: float = anell - (2.0 if cop.position.y > nivell else 0.0)
			if puntuacio < millor_puntuacio:
				millor_puntuacio = puntuacio
				millor = cop.position + Vector3.UP * (ALCADA_PEUS + 0.05)
	return millor

# ─────────────── Aspecte

func _process(_delta):
	if not visible:
		return
	# Interpolació entre passos de física (posició i gir)
	var f := Engine.get_physics_interpolation_fraction()
	var pos_visual := pos_anterior.lerp(global_position, f)
	var rumb_visual := lerp_angle(rumb_anterior, rumb, f)
	var balanceig := _balanceig()
	model.position = global_basis.inverse() * (pos_visual - global_position) + Vector3.UP * balanceig
	# Escora en girar, capcineja una mica amb la velocitat i balanceja sola
	model.rotation = Vector3(
		sin(temps * 1.3) * 0.02 + velocitat * 0.006,
		angle_difference(rumb, rumb_visual),
		-gir_actual * absf(velocitat) * 0.035 + sin(temps * 1.1) * 0.025)
	estela.emitting = absf(velocitat) > 1.0
	if conductor and punt_baixada != null:
		indicador.text = "[%s] Baixar" % _tecla()
		indicador.global_position = punt_baixada + Vector3.UP * 1.3
		indicador.visible = true
	else:
		indicador.visible = false

func _tecla() -> String:
	for ev in InputMap.action_get_events("interactuar"):
		if ev is InputEventKey:
			return ev.as_text_physical_keycode()
	return "F"
