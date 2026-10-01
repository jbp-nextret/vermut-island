extends Node3D
class_name Regador
## Encanteri de rec:
##  - G: entra/surt del mode regar (surt del mode plantar si hi eres).
##  - Clic a terra: cercle màgic + pluja de gotes, i rega els cultius de l'àrea.
##  - En mode regar, els cultius que tenen set porten una gota a sobre.
##  - Clic dret / Esc: surt.
## Més endavant l'encanteri es pot "invocar" amb una regadora, com l'espasa.

signal mode_canviat(actiu: bool)
signal avis(text: String)

const RADI := 1.5             # rega la cel·la i les 8 del voltant (l'habilitat "Pluja ampla" l'amplia)
## Càrregues d'aigua: cada encanteri en gasta una i es recuperen soles (o de cop si plou).
## L'habilitat "Núvol generós" en dona més.
const CARREGUES_BASE := 4.0
const SEGONS_PER_CARREGA := 8.0
const ABAST := 7.0            # distància màxima des del jugador
const RECARREGA := 0.6
const COLOR_AIGUA := Color(0.45, 0.75, 1.0)
const TEXTURA_CERCLE := preload("res://Sprites/Misc/magic-3.png")

var mon: Node3D
var plantador: Plantador
var jugador: Node3D
var actiu := false
var cella: Dictionary = {}
var temps_des_del_rec := 99.0
var carregues := CARREGUES_BASE
var radi_actual := RADI

func radi() -> float:
	return RADI * (1.0 + Progressio.valor("abast_regar"))

func carregues_max() -> float:
	return CARREGUES_BASE + Progressio.valor("aigua_regar")
var anell: AnellAbast

static var _material_cercle: StandardMaterial3D
static var _material_gotes: ParticleProcessMaterial
static var _malla_gota: QuadMesh

func configurar(p_mon: Node3D, p_plantador: Plantador, p_jugador: Node3D) -> void:
	mon = p_mon
	plantador = p_plantador
	jugador = p_jugador

func _ready():
	anell = AnellAbast.new()
	anell.top_level = true
	anell.visible = false
	add_child(anell)
	anell.configurar(RADI, COLOR_AIGUA)

## L'anell del botó: quantes càrregues d'aigua queden
func progres() -> float:
	return clampf(carregues / carregues_max(), 0.0, 1.0)

# ─────────────── Entrada

func _unhandled_input(event: InputEvent) -> void:
	if not GameState.pot_atacar():
		return
	if event.is_action_pressed("regar"):
		if actiu:
			sortir()
		else:
			entrar()
		get_viewport().set_input_as_handled()
		return
	if not actiu:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("accio_secundaria"):
		sortir()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("accio_primaria"):
		_intentar_regar()
		get_viewport().set_input_as_handled()

func entrar():
	if plantador.actiu:
		plantador.sortir()
	actiu = true
	mode_canviat.emit(true)

func sortir_si_actiu():
	if actiu:
		sortir()

func sortir():
	actiu = false
	anell.visible = false
	plantador.cursor.visible = false
	for c in get_tree().get_nodes_in_group("cultius"):
		c.mostrar_set(false)
	mode_canviat.emit(false)

# ─────────────── Cada frame

func _process(delta):
	temps_des_del_rec += delta
	# L'aigua es recupera sola; si plou, s'omple de cop
	var maxim := carregues_max()
	carregues = maxim if Meteorologia.pluja > 0.3 else minf(maxim, carregues + delta / SEGONS_PER_CARREGA)
	if not is_equal_approx(radi_actual, radi()):
		radi_actual = radi()
		anell.configurar(radi_actual, COLOR_AIGUA)
	if not actiu:
		return
	if not GameState.pot_atacar():
		sortir()
		return

	# El mateix cursor fiable del mode plantar (també sobre els cultius)
	cella = plantador._cella_sota_ratoli()
	anell.visible = not cella.is_empty()
	if anell.visible:
		anell.global_position = cella.superficie + Vector3.UP * 0.04
		var a_labast := _a_labast()
		anell.modulate_color(COLOR_AIGUA if a_labast else Color(1, 0.4, 0.4))

	for c in get_tree().get_nodes_in_group("cultius"):
		c.mostrar_set(c.necessita_aigua())

func _a_labast() -> bool:
	return not cella.is_empty() and Vector2(cella.superficie.x - jugador.global_position.x, cella.superficie.z - jugador.global_position.z).length() <= ABAST

# ─────────────── Encanteri

func _intentar_regar():
	if cella.is_empty():
		return
	if not _a_labast():
		avis.emit("Massa lluny")
		return
	if temps_des_del_rec < RECARREGA:
		return
	if carregues < 1.0:
		avis.emit("No queda aigua (es recupera sola, o amb la pluja)")
		return
	carregues -= 1.0
	temps_des_del_rec = 0.0
	var centre: Vector3 = cella.superficie

	# El personatge es gira cap allà i fa el gest de l'encanteri
	var direccio := centre - jugador.global_position
	direccio.y = 0
	if direccio.length() > 0.1 and jugador.has_method("_mirar_cap_a"):
		jugador._mirar_cap_a(direccio.normalized())
		jugador.play_anim("attack_" + jugador.ultima_direccio, jugador.mirall_horitzontal)

	_cercle_magic(centre)
	_pluja(centre)
	# L'aigua arriba a terra una mica després
	get_tree().create_timer(0.35).timeout.connect(func(): _mullar(centre))

func _mullar(centre: Vector3):
	var regats := 0
	for c in get_tree().get_nodes_in_group("cultius"):
		if not is_instance_valid(c):
			continue
		if Vector2(c.global_position.x - centre.x, c.global_position.z - centre.z).length() <= radi():
			if c.necessita_aigua():
				regats += 1
				Progressio.guanyar_xp("regar")
			c.regar()
	if regats > 0:
		GestorPartida.call_deferred("guardar_mundo")

func _cercle_magic(centre: Vector3):
	if _material_cercle == null:
		_material_cercle = StandardMaterial3D.new()
		_material_cercle.albedo_texture = TEXTURA_CERCLE
		_material_cercle.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_material_cercle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material_cercle.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material_cercle.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material_cercle.vertex_color_use_as_albedo = true
	var cercle := Sprite3D.new()
	cercle.texture = TEXTURA_CERCLE
	cercle.material_override = _material_cercle
	cercle.modulate = Color(COLOR_AIGUA, 0.95)
	cercle.rotation_degrees.x = 90
	cercle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mon.add_child(cercle)
	cercle.global_position = CombatMagic.terra_sota(jugador, centre) + Vector3.UP * 0.02
	var mida_final: float = radi() * 2.0 / (TEXTURA_CERCLE.get_width() * cercle.pixel_size)
	cercle.scale = Vector3.ONE * mida_final * 0.3
	var t := cercle.create_tween().set_parallel(true)
	t.tween_property(cercle, "scale", Vector3.ONE * mida_final, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(cercle, "rotation_degrees:y", 120.0, 0.9)
	t.tween_property(cercle, "modulate:a", 0.0, 0.4).set_delay(0.5)
	t.chain().tween_callback(cercle.queue_free)

## Gotes que cauen des de dalt sobre l'àrea
func _pluja(centre: Vector3):
	if _material_gotes == null:
		_material_gotes = ParticleProcessMaterial.new()
		_material_gotes.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		_material_gotes.emission_sphere_radius = RADI
		_material_gotes.direction = Vector3.DOWN
		_material_gotes.spread = 5.0
		_material_gotes.initial_velocity_min = 5.0
		_material_gotes.initial_velocity_max = 7.0
		_material_gotes.gravity = Vector3(0, -12, 0)
		_material_gotes.scale_min = 0.6
		_material_gotes.scale_max = 1.2
		_material_gotes.color = Color(COLOR_AIGUA, 0.9)
		_malla_gota = QuadMesh.new()
		_malla_gota.size = Vector2(0.05, 0.18)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		mat.vertex_color_use_as_albedo = true
		_malla_gota.material = mat
	_material_gotes.emission_sphere_radius = radi()
	var gotes := GPUParticles3D.new()
	gotes.process_material = _material_gotes
	gotes.draw_pass_1 = _malla_gota
	gotes.amount = 40
	gotes.lifetime = 0.35
	gotes.one_shot = true
	gotes.explosiveness = 0.6
	gotes.local_coords = false
	mon.add_child(gotes)
	gotes.global_position = centre + Vector3.UP * 2.2
	gotes.emitting = true
	gotes.finished.connect(gotes.queue_free)
