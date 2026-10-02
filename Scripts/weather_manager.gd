extends Node3D
## Efectes del temps al món (les dades venen de l'autoload Meteorologia):
##  - vent per als shaders de vegetació i cultius
##  - pluja: gotes que segueixen la càmera i esquitxos a terra; si plou prou, rega els cultius
##  - tempesta: llamps (flaix de llum i sacseig de càmera)
##  - boira: la boira de l'entorn
##  - fulles que volen pel mapa (més com més vent; el color depèn de l'estació)

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

# Fulles que volen per l'ambient
const FULLES_MAXIMES := 110
const VIDA_FULLA := 5.0
const AMPLE_FULLES := 28.0
## Colors de les fulles per estació (quan hi hagi estacions, canvia `estacio`)
const COLORS_FULLES := {
	"primavera": [Color(0.45, 0.8, 0.3), Color(0.6, 0.9, 0.4), Color(0.95, 0.75, 0.85)],   # amb algun pètal
	# Verds groguencs i foscos: que destaquin sobre l'herba
	"estiu": [Color(0.7, 0.8, 0.25), Color(0.45, 0.62, 0.15), Color(0.85, 0.85, 0.35), Color(0.3, 0.45, 0.12)],
	"tardor": [Color(0.75, 0.4, 0.12), Color(0.85, 0.55, 0.15), Color(0.6, 0.3, 0.1), Color(0.9, 0.7, 0.25)],
	"hivern": [Color(0.55, 0.45, 0.35), Color(0.45, 0.38, 0.3)],
}
var estacio := "estiu":
	set(valor):
		estacio = valor
		_aplicar_colors_fulles()
var fulles: GPUParticles3D

## Des de fora: el flaix del llamp (el llegeix el cicle de dia i nit)
var flaix := 0.0

func _ready():
	jugador = get_tree().get_first_node_in_group("player")
	entorn = get_parent().get_node_or_null("WorldEnvironment")
	soroll_vent.frequency = 0.05
	_crear_pluja()
	_crear_fulles()
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
	_actualitzar_fulles(direccio, forca)
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

# ─────────────── Fulles

func _crear_fulles():
	fulles = GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(AMPLE_FULLES / 2.0, 2.5, AMPLE_FULLES / 2.0)
	mat.direction = Vector3(1, -0.2, 0)
	mat.spread = 25.0
	mat.initial_velocity_min = 0.6
	mat.initial_velocity_max = 1.4
	mat.gravity = Vector3(0, -0.35, 0)
	# Voleiar: turbulència suau i girs
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 1.4
	mat.turbulence_noise_scale = 3.0
	mat.turbulence_influence_min = 0.05
	mat.turbulence_influence_max = 0.15
	mat.angle_min = -180.0
	mat.angle_max = 180.0
	mat.angular_velocity_min = -120.0
	mat.angular_velocity_max = 120.0
	mat.scale_min = 0.7
	mat.scale_max = 1.2
	# Apareixen i desapareixen fent fos
	var alfa := Gradient.new()
	alfa.set_color(0, Color(1, 1, 1, 0))
	alfa.add_point(0.15, Color(1, 1, 1, 1))
	alfa.add_point(0.85, Color(1, 1, 1, 1))
	alfa.set_color(alfa.get_point_count() - 1, Color(1, 1, 1, 0))
	var rampa := GradientTexture1D.new()
	rampa.gradient = alfa
	mat.color_ramp = rampa
	fulles.process_material = mat

	var quad := QuadMesh.new()
	quad.size = Vector2(0.24, 0.24)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _textura_fulla()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = m
	fulles.draw_pass_1 = quad
	fulles.amount = FULLES_MAXIMES
	fulles.lifetime = VIDA_FULLA
	fulles.preprocess = VIDA_FULLA   # en començar ja n'hi ha pel mapa
	fulles.local_coords = false
	fulles.visibility_aabb = AABB(Vector3(-AMPLE_FULLES, -8, -AMPLE_FULLES), Vector3(AMPLE_FULLES * 2.0, 16, AMPLE_FULLES * 2.0))
	add_child(fulles)
	_aplicar_colors_fulles()

## Cada fulla agafa un dels colors de l'estació
func _aplicar_colors_fulles():
	if fulles == null:
		return
	var colors: Array = COLORS_FULLES.get(estacio, COLORS_FULLES["estiu"])
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.remove_point(1)
	g.set_color(0, colors[0])
	g.set_offset(0, 0.0)
	for i in range(1, colors.size()):
		g.add_point(float(i) / colors.size(), colors[i])
	var t := GradientTexture1D.new()
	t.gradient = g
	(fulles.process_material as ParticleProcessMaterial).color_initial_ramp = t

func _actualitzar_fulles(direccio: Vector2, forca: float):
	fulles.emitting = SettingsManager.valor("particules_meteo")
	if not fulles.emitting or not is_instance_valid(jugador):
		return
	# Amb vent hi ha més fulles i van més de pressa, cap on bufa
	fulles.amount_ratio = clampf(0.2 + forca * 4.0, 0.2, 1.0)
	var mat := fulles.process_material as ParticleProcessMaterial
	var cap := Vector3(direccio.x, 0.0, direccio.y).normalized()
	mat.direction = Vector3(cap.x, -0.25, cap.z).normalized()
	mat.initial_velocity_min = 0.4 + forca * 3.0
	mat.initial_velocity_max = 0.9 + forca * 6.0
	# Neixen a contravent: així creuen la pantalla en lloc de marxar-ne de seguida
	var recorregut := (mat.initial_velocity_min + mat.initial_velocity_max) * 0.5 * VIDA_FULLA
	fulles.global_position = jugador.global_position + Vector3.UP * 3.0 - cap * recorregut * 0.5

## Una fulla de 8x8 en pixel art (el color el posa cada partícula)
static func _textura_fulla() -> ImageTexture:
	var dibuix := [
		"........",
		".....##.",
		"...####.",
		"..#####.",
		".#####..",
		".####...",
		"#.##....",
		"#.......",
	]
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			if dibuix[y][x] == "#":
				# Una mica més fosc al nervi central, per donar-li forma
				var fosc := 0.8 if x + y == 7 else 1.0
				img.set_pixel(x, y, Color(fosc, fosc, fosc, 1))
	return ImageTexture.create_from_image(img)

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
	# Pensat per a una càmera a 10 unitats: si és més lluny, la boira s'aprima en proporció
	var camera := get_viewport().get_camera_3d()
	if camera:
		densitat *= 10.0 / maxf(10.0, camera.position.z)
	env.fog_enabled = densitat > 0.001
	env.fog_density = densitat
	env.fog_light_color = Color(0.72, 0.76, 0.82)
	env.fog_sky_affect = 0.6
