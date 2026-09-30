extends Node3D
## Efectes del temps al món (les dades venen de l'autoload Meteorologia):
##  - vent per als shaders de vegetació i cultius
##  - pluja: gotes que segueixen la càmera i esquitxos a terra; si plou prou, rega els cultius
##  - tempesta: llamps (flaix de llum i sacseig de càmera)
##  - boira: la boira de l'entorn

@export var wind_strength := 0.08   # es fa servir com a base; el temps el multiplica
@export var wind_speed := 1.2
@export var wind_direction := Vector2(1.0, 0.3)

const GOTES_MAXIMES := 1600
const AMPLE_PLUJA := 26.0
const ALCADA_PLUJA := 12.0

var jugador: Node3D
var entorn: WorldEnvironment
var pluja: GPUParticles3D
var esquitxos: GPUParticles3D
var soroll_vent := FastNoiseLite.new()
var temps_seguent_llamp := 5.0
var dia_regat_per_pluja := -1
var capa_flaix: ColorRect

## Des de fora: el flaix del llamp (el llegeix el cicle de dia i nit)
var flaix := 0.0

func _ready():
	jugador = get_tree().get_first_node_in_group("player")
	entorn = get_parent().get_node_or_null("WorldEnvironment")
	soroll_vent.frequency = 0.05
	_crear_pluja()
	# Flaix blanc a tota la pantalla quan cau un llamp
	var capa := CanvasLayer.new()
	capa.layer = 5
	add_child(capa)
	capa_flaix = ColorRect.new()
	capa_flaix.color = Color(0.92, 0.95, 1.0, 0.0)
	capa_flaix.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa_flaix.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(capa_flaix)

func _process(delta):
	# Vent: la força segons el temps, i la direcció que va canviant a poc a poc
	var t := Time.get_ticks_msec() / 1000.0
	var angle := soroll_vent.get_noise_1d(t) * PI * 0.5
	var direccio := wind_direction.normalized().rotated(angle)
	var forca := Meteorologia.vent * (1.0 + 0.3 * soroll_vent.get_noise_1d(t * 3.0 + 100.0))
	RenderingServer.global_shader_parameter_set("wind_strength", forca)
	RenderingServer.global_shader_parameter_set("wind_speed", wind_speed * (1.0 + Meteorologia.vent * 4.0))
	RenderingServer.global_shader_parameter_set("wind_direction", direccio)

	_actualitzar_pluja(direccio, forca)
	_actualitzar_llamps(delta)
	_actualitzar_boira()
	flaix = move_toward(flaix, 0.0, delta * 4.0)
	capa_flaix.color.a = flaix * 0.55

	# Si plou de veritat, els cultius queden regats
	if Meteorologia.pluja > 0.4 and dia_regat_per_pluja != GestorTemps.dia_actual:
		dia_regat_per_pluja = GestorTemps.dia_actual
		get_tree().call_group("cultius", "regar")
		GestorPartida.call_deferred("guardar_mundo")

# ─────────────── Pluja

func _crear_pluja():
	pluja = GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(AMPLE_PLUJA / 2.0, 0.5, AMPLE_PLUJA / 2.0)
	mat.direction = Vector3.DOWN
	mat.spread = 3.0
	mat.initial_velocity_min = 16.0
	mat.initial_velocity_max = 20.0
	mat.gravity = Vector3.ZERO
	mat.color = Color(0.75, 0.85, 1.0, 0.55)
	pluja.process_material = mat
	var gota := QuadMesh.new()
	gota.size = Vector2(0.025, 0.45)
	var mat_gota := StandardMaterial3D.new()
	mat_gota.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_gota.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_gota.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat_gota.vertex_color_use_as_albedo = true
	gota.material = mat_gota
	pluja.draw_pass_1 = gota
	pluja.amount = GOTES_MAXIMES
	pluja.lifetime = ALCADA_PLUJA / 18.0
	pluja.local_coords = false
	pluja.visibility_aabb = AABB(Vector3(-AMPLE_PLUJA, -ALCADA_PLUJA * 2.0, -AMPLE_PLUJA), Vector3(AMPLE_PLUJA * 2.0, ALCADA_PLUJA * 3.0, AMPLE_PLUJA * 2.0))
	pluja.emitting = false
	add_child(pluja)

	# Esquitxos a terra, al voltant del jugador
	esquitxos = GPUParticles3D.new()
	var mat_e := ParticleProcessMaterial.new()
	mat_e.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat_e.emission_box_extents = Vector3(9.0, 0.05, 9.0)
	mat_e.direction = Vector3.UP
	mat_e.spread = 50.0
	mat_e.initial_velocity_min = 0.6
	mat_e.initial_velocity_max = 1.3
	mat_e.gravity = Vector3(0, -8, 0)
	mat_e.color = Color(0.85, 0.92, 1.0, 0.6)
	esquitxos.process_material = mat_e
	var punt := QuadMesh.new()
	punt.size = Vector2(0.05, 0.05)
	var mat_p := StandardMaterial3D.new()
	mat_p.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_p.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_p.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat_p.vertex_color_use_as_albedo = true
	punt.material = mat_p
	esquitxos.draw_pass_1 = punt
	esquitxos.amount = 300
	esquitxos.lifetime = 0.3
	esquitxos.local_coords = false
	esquitxos.emitting = false
	add_child(esquitxos)

func _actualitzar_pluja(direccio: Vector2, forca: float):
	var intensitat := Meteorologia.pluja
	var plou: bool = intensitat > 0.02 and SettingsManager.valor("particules_meteo")
	pluja.emitting = plou
	esquitxos.emitting = plou and intensitat > 0.2
	if not plou or not is_instance_valid(jugador):
		return
	# Segueix el jugador: les gotes neixen a sobre seu
	pluja.global_position = jugador.global_position + Vector3.UP * ALCADA_PLUJA
	esquitxos.global_position = CombatMagic.terra_sota(jugador, jugador.global_position) + Vector3.UP * 0.05
	pluja.amount_ratio = intensitat
	esquitxos.amount_ratio = intensitat
	# Amb vent, la pluja cau inclinada
	var mat: ParticleProcessMaterial = pluja.process_material
	mat.direction = Vector3(direccio.x * forca * 8.0, -1.0, direccio.y * forca * 8.0).normalized()

# ─────────────── Tempesta i boira

func _actualitzar_llamps(delta: float):
	if not Meteorologia.es_tempesta:
		return
	temps_seguent_llamp -= delta
	if temps_seguent_llamp > 0.0:
		return
	temps_seguent_llamp = randf_range(4.0, 11.0)
	# Dos flaixos seguits, com un llamp de veritat
	flaix = 1.0
	get_tree().create_timer(0.12).timeout.connect(func(): flaix = 0.7)
	# El tro arriba una mica després
	get_tree().create_timer(0.4).timeout.connect(_tro)

func _tro():
	if is_instance_valid(jugador) and jugador.has_method("camera_shake"):
		jugador.camera_shake(0.18)

func _actualitzar_boira():
	if entorn == null or entorn.environment == null:
		return
	var env := entorn.environment
	var densitat := Meteorologia.boira * 0.08 + Meteorologia.pluja * 0.015
	env.fog_enabled = densitat > 0.001
	env.fog_density = densitat
	env.fog_light_color = Color(0.72, 0.76, 0.82)
	env.fog_sky_affect = 0.6
