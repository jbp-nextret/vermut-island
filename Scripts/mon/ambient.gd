extends Node3D
class_name Ambient
## Efectes que fan el món més viu, segons l'hora i el temps (tots fets amb codi):
##  - de dia: pol·len i vilans que suren a la llum, i papallones que volen a prop
##  - de nit: cuques de llum que s'encenen i s'apaguen arran d'herba
##  - raigs de sol que travessen l'aire, sobretot al matí i al capvespre (amb el color del sol)
##  - ombres de núvols que passen pel terra (al postprocessat), més com més ennuvolat
## Res d'això surt si plou fort. L'opció "efectes_ambient" ho apaga tot.
## Va al voltant del jugador; el crea world.gd.

const AMPLE := 22.0          # zona al voltant del jugador on hi ha partícules
const PAPALLONES := 6
const RAIGS := 7

var jugador: Node3D
var sol: DirectionalLight3D
var meteo: Node
var pollen: GPUParticles3D
var cuques: GPUParticles3D
var papallones: Array[Node3D] = []
var raigs: Array[MeshInstance3D] = []
var material_raig: ShaderMaterial
var desplacament_nuvols := Vector2.ZERO

func _ready():
	jugador = get_tree().get_first_node_in_group("player")
	sol = get_parent().get_node_or_null("GridMap/DirectionalLight3D")
	meteo = get_parent().get_node_or_null("WeatherManager")
	pollen = _particules_pollen()
	add_child(pollen)
	cuques = _particules_cuques()
	add_child(cuques)
	for i in PAPALLONES:
		var p := _papallona(i)
		add_child(p)
		papallones.append(p)
	_crear_raigs()

func _process(delta):
	if not is_instance_valid(jugador):
		return
	var actiu: bool = SettingsManager.valor("efectes_ambient")
	var hora: float = GestorTemps.hora_actual
	var dia := _llum_de_dia(hora)
	var pluja: float = Meteorologia.pluja
	var nuvols: float = Meteorologia.nuvols
	var sec := 1.0 - clampf(pluja * 1.5, 0.0, 1.0)   # 0 si plou fort
	var centre := jugador.global_position
	var vent: Vector2 = meteo.direccio_vent if meteo else Vector2.RIGHT
	var forca_vent: float = meteo.forca_vent if meteo else 0.05

	# Pol·len de dia, cuques de llum de nit
	pollen.amount_ratio = dia * sec * (1.0 - nuvols * 0.5) if actiu else 0.0
	pollen.emitting = pollen.amount_ratio > 0.02
	pollen.global_position = centre + Vector3.UP * 1.5
	(pollen.process_material as ParticleProcessMaterial).gravity = Vector3(vent.x, 0.05, vent.y) * (0.05 + forca_vent * 2.0)
	var nit := clampf(1.0 - dia * 1.5, 0.0, 1.0)
	cuques.amount_ratio = nit * sec if actiu else 0.0
	cuques.emitting = cuques.amount_ratio > 0.02
	cuques.global_position = centre + Vector3.UP * 0.6

	# Papallones: de dia i si no plou
	var hi_ha_papallones := actiu and dia > 0.6 and sec > 0.9 and nuvols < 0.6
	for p in papallones:
		_moure_papallona(p, delta, centre, hi_ha_papallones)

	# Raigs de sol
	var calidesa := clampf(absf(hora - 13.0) / 6.0, 0.0, 1.0)   # més al matí i a la tarda
	var forca_raigs := dia * (1.0 - nuvols) * sec * lerpf(0.35, 1.0, calidesa)
	_actualitzar_raigs(delta, centre, forca_raigs if actiu else 0.0)

	# Ombres de núvols al postprocessat
	desplacament_nuvols += vent * (0.4 + forca_vent * 6.0) * delta
	var ombra := (0.22 + nuvols * 0.25) * clampf(dia * 1.5, 0.0, 1.0) * (1.0 - pluja * 0.6)
	var camera := get_viewport().get_camera_3d()
	if camera and "postprocessat" in camera and camera.postprocessat:
		var m := camera.postprocessat.material_override as ShaderMaterial
		m.set_shader_parameter("ombra_nuvols", ombra if actiu else 0.0)
		m.set_shader_parameter("desplacament_nuvols", desplacament_nuvols)

## 0 de nit, 1 de dia (les mateixes hores que el cicle de dia i nit)
static func _llum_de_dia(hora: float) -> float:
	if hora < 5.5 or hora > 20.5:
		return 0.0
	if hora < 7.5:
		return (hora - 5.5) / 2.0
	if hora > 18.5:
		return (20.5 - hora) / 2.0
	return 1.0

# ─────────────── Pol·len i cuques de llum

static func _punt(color: Color, mida: float, additiu: bool) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(mida, mida)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additiu else BaseMaterial3D.BLEND_MODE_MIX
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.albedo_texture = _textura_punt()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	q.material = m
	return q

## Un punt de 4×4 amb el centre més brillant
static func _textura_punt() -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for x in [1, 2]:
		for y in [1, 2]:
			img.set_pixel(x, y, Color(1, 1, 1, 1))
	for p in [Vector2i(0, 1), Vector2i(0, 2), Vector2i(3, 1), Vector2i(3, 2), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 3), Vector2i(2, 3)]:
		img.set_pixelv(p, Color(1, 1, 1, 0.35))
	return ImageTexture.create_from_image(img)

static func _rampa(punts: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(punts.map(func(p): return p[0]))
	g.colors = PackedColorArray(punts.map(func(p): return p[1]))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

func _particules_pollen() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(AMPLE / 2.0, 2.0, AMPLE / 2.0)
	mat.direction = Vector3.UP
	mat.spread = 180.0
	mat.initial_velocity_min = 0.02
	mat.initial_velocity_max = 0.12
	mat.gravity = Vector3(0, 0.03, 0)
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 0.6
	mat.turbulence_noise_scale = 4.0
	mat.turbulence_influence_min = 0.02
	mat.turbulence_influence_max = 0.06
	mat.scale_min = 0.6
	mat.scale_max = 1.3
	mat.color_ramp = _rampa([[0.0, Color(1, 1, 1, 0)], [0.2, Color(1, 1, 1, 0.8)], [0.8, Color(1, 1, 1, 0.8)], [1.0, Color(1, 1, 1, 0)]])
	mat.color_initial_ramp = _rampa([[0.0, Color(1.0, 0.97, 0.85)], [0.6, Color(1.0, 0.92, 0.6)], [1.0, Color(0.95, 1.0, 0.8)]])
	p.process_material = mat
	p.draw_pass_1 = _punt(Color(1.4, 1.35, 1.1), 0.09, false)
	p.amount = 70
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-AMPLE, -6, -AMPLE), Vector3(AMPLE * 2.0, 12, AMPLE * 2.0))
	return p

func _particules_cuques() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(AMPLE / 2.0, 0.8, AMPLE / 2.0)
	mat.direction = Vector3.UP
	mat.spread = 180.0
	mat.initial_velocity_min = 0.1
	mat.initial_velocity_max = 0.4
	mat.gravity = Vector3.ZERO
	mat.damping_min = 0.1
	mat.damping_max = 0.3
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 1.2
	mat.turbulence_noise_scale = 2.5
	mat.turbulence_influence_min = 0.05
	mat.turbulence_influence_max = 0.12
	# S'encenen i s'apaguen un parell de vegades
	mat.color_ramp = _rampa([[0.0, Color(1, 1, 1, 0)], [0.15, Color(1, 1, 1, 1)], [0.35, Color(1, 1, 1, 0.1)],
		[0.55, Color(1, 1, 1, 1)], [0.8, Color(1, 1, 1, 0.15)], [1.0, Color(1, 1, 1, 0)]])
	p.process_material = mat
	p.draw_pass_1 = _punt(Color(1.6, 2.0, 0.6), 0.16, true)
	p.amount = 45
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-AMPLE, -6, -AMPLE), Vector3(AMPLE * 2.0, 12, AMPLE * 2.0))
	return p

# ─────────────── Papallones

const COLORS_PAPALLONA := [Color(1.0, 1.0, 0.95), Color(1.0, 0.85, 0.25), Color(1.0, 0.55, 0.2), Color(0.45, 0.65, 1.0), Color(0.95, 0.6, 0.85)]

func _papallona(i: int) -> Node3D:
	var p := Node3D.new()
	var color: Color = COLORS_PAPALLONA[i % COLORS_PAPALLONA.size()]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for costat in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "Ala%d" % (0 if costat < 0 else 1)
		p.add_child(pivot)
		var ala := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.2, 0.24)
		ala.mesh = q
		ala.material_override = m
		ala.position = Vector3(costat * 0.1, 0, 0)
		ala.rotation_degrees.x = -90.0
		ala.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(ala)
	p.set_meta("fase", randf() * TAU)
	p.set_meta("desti", Vector3.ZERO)
	p.set_meta("temps", 0.0)
	p.visible = false
	return p

func _moure_papallona(p: Node3D, delta: float, centre: Vector3, hi_son: bool):
	if not hi_son:
		p.visible = false
		return
	var temps: float = p.get_meta("temps") - delta
	var desti: Vector3 = p.get_meta("desti")
	# Si és lluny del jugador (o no volava), reapareix a prop
	if not p.visible or p.global_position.distance_to(centre) > 10.0:
		p.visible = true
		p.global_position = centre + Vector3(randf_range(-6, 6), randf_range(0.6, 1.6), randf_range(-6, 6))
		temps = 0.0
	if temps <= 0.0 or p.global_position.distance_to(desti) < 0.3:
		desti = centre + Vector3(randf_range(-6, 6), randf_range(0.5, 1.8), randf_range(-6, 6))
		temps = randf_range(2.0, 5.0)
	p.set_meta("temps", temps)
	p.set_meta("desti", desti)
	# Vol a batzegades: cap al destí amb una mica de ziga-zaga i bot
	var fase: float = p.get_meta("fase") + delta * 14.0
	p.set_meta("fase", fase)
	var cap := (desti - p.global_position).normalized()
	var costat := cap.cross(Vector3.UP)
	p.global_position += (cap * 1.1 + costat * sin(fase * 0.4) * 0.6 + Vector3.UP * sin(fase * 0.25) * 0.5) * delta
	if cap.length() > 0.01:
		p.rotation.y = atan2(cap.x, cap.z)
	var ales := sin(fase) * 70.0
	p.get_node("Ala0").rotation_degrees.z = -ales
	p.get_node("Ala1").rotation_degrees.z = ales

# ─────────────── Raigs de sol

func _crear_raigs():
	material_raig = ShaderMaterial.new()
	var s := Shader.new()
	s.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 color : source_color = vec3(1.0, 0.9, 0.7);
uniform float forca = 0.0;
instance uniform float fase = 0.0;
void fragment() {
	// Més intens al mig i a dalt, i s'esvaeix cap a les vores i cap a baix
	float amplada = smoothstep(0.0, 0.35, 0.5 - abs(UV.x - 0.5));
	float llarg = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.45, UV.y);
	// Unes franges que es mouen a poc a poc dins del raig
	float franges = 0.85 + 0.15 * sin(UV.x * 9.0 + TIME * 0.6 + fase * 6.0);
	float pols = 0.7 + 0.3 * sin(TIME * 0.35 + fase * 6.28);
	ALBEDO = color;
	ALPHA = amplada * llarg * franges * pols * forca * 0.35;
}
"""
	material_raig.shader = s
	for i in RAIGS:
		var r := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(randf_range(0.5, 1.3), 16.0)
		r.mesh = q
		r.material_override = material_raig
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.set_instance_shader_parameter("fase", randf())
		r.set_meta("lloc", Vector3(randf_range(-9, 9), 0, randf_range(-9, 9)))
		r.visible = false
		add_child(r)
		raigs.append(r)

func _actualitzar_raigs(delta: float, centre: Vector3, forca: float):
	material_raig.set_shader_parameter("forca", forca)
	var hi_son := forca > 0.02 and sol != null
	for r in raigs:
		r.visible = hi_son
	if not hi_son:
		return
	material_raig.set_shader_parameter("color", sol.light_color)
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	# La direcció de la llum (de dalt cap avall), i el pla del raig mirant a la càmera
	var eix := -sol.global_basis.z.normalized()
	var amplada := eix.cross(camera.global_basis.z).normalized()
	if amplada.length() < 0.01:
		return
	var normal := amplada.cross(eix).normalized()
	for r in raigs:
		var lloc: Vector3 = r.get_meta("lloc")
		# Es desplacen a poc a poc i, si queden lluny, tornen a sortir a l'altra banda
		lloc += Vector3(0.15, 0, 0.08) * delta
		if absf(lloc.x) > 10.0 or absf(lloc.z) > 10.0:
			lloc = Vector3(randf_range(-9, 9), 0, randf_range(-9, 9))
		r.set_meta("lloc", lloc)
		# El peu del raig a terra, i el raig cap amunt cap al sol
		var peu := Vector3(centre.x, centre.y, centre.z) + lloc
		r.global_transform = Transform3D(Basis(amplada, -eix, normal), peu - eix * 7.0)
