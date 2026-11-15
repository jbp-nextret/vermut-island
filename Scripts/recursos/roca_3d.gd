extends Node3D
class_name Roca3D
## Una roca feta amb els models de Blender (Models/roca_petita / mitjana / gran.glb).
## Cada roca tria (segons on és, així sempre surt igual) una mida, si té molsa i un gir.
## El tipus de pedra (color) i quanta molsa hi ha depenen del bioma de l'illa (Biomes). Les grans donen més pedra i costen més de picar.
## Té els fills "Cos" (col·lisió) i "Recurs" (RecursNatural) de l'escena roca.tscn.

const SHADER := preload("res://Shaders/roca.gdshader")
## mida -> model, probabilitat, cops, pedra mínima i màxima
const MIDES := {
	"petita": {"model": "res://Models/roca_petita.glb", "pes": 4.0, "cops": 3, "min": 1, "max": 2},
	"mitjana": {"model": "res://Models/roca_mitjana.glb", "pes": 4.5, "cops": 4, "min": 1, "max": 3},
	"gran": {"model": "res://Models/roca_gran.glb", "pes": 1.5, "cops": 6, "min": 3, "max": 5},
}
## Tipus de pedra: color fosc i clar del degradat
const PEDRES := [
	[Color(0.24, 0.24, 0.27), Color(0.62, 0.62, 0.66)],   # grisa
	[Color(0.3, 0.25, 0.19), Color(0.72, 0.62, 0.48)],    # sorrenca
	[Color(0.21, 0.24, 0.31), Color(0.54, 0.6, 0.7)],     # blavosa
	[Color(0.31, 0.2, 0.17), Color(0.68, 0.5, 0.42)],     # rogenca
	[Color(0.17, 0.17, 0.18), Color(0.45, 0.45, 0.47)],   # fosca (basalt)
]

static var _models := {}      # camí -> {malla, centre (desplaçament per centrar-la), mida}
static var _materials := {}   # índex de pedra -> ShaderMaterial

var model: MeshInstance3D
var mida := "mitjana"

func _ready():
	var malla_antiga := get_node_or_null("Malla")
	if malla_antiga:
		return   # una escena antiga, amb la seva malla
	# La posició encara no és la definitiva (el regenerador la posa després): esperem
	call_deferred("_construir")

func _construir():
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(global_position.round()))
	# La mida
	var total := 0.0
	for m in MIDES:
		total += MIDES[m].pes
	var r := rng.randf() * total
	for m in MIDES:
		r -= MIDES[m].pes
		if r <= 0.0:
			mida = m
			break
	var dades := _model(MIDES[mida].model)
	if dades.is_empty():
		return
	model = MeshInstance3D.new()
	model.name = "Model"
	model.mesh = dades.malla
	model.position = dades.centre
	add_child(model)
	var bioma := Biomes.dades(global_position)
	model.material_override = _material(int(bioma.pedra) % PEDRES.size(), dades.textura)
	model.set_instance_shader_parameter("variacio", rng.randf_range(-1.0, 1.0))
	model.set_instance_shader_parameter("molsa", 1.0 if rng.randf() < float(bioma.molsa) else 0.0)
	rotation.y = rng.randf() * TAU
	# La col·lisió, de la mida de la roca
	var forma := get_node_or_null("Cos/Forma") as CollisionShape3D
	if forma:
		var caixa := BoxShape3D.new()
		caixa.size = Vector3(dades.mida.x * 0.85, dades.mida.y, dades.mida.z * 0.85)
		forma.shape = caixa
		forma.position = Vector3.UP * dades.mida.y * 0.5
	# El recurs: les grans costen més i donen més pedra
	var recurs := get_node_or_null("Recurs") as RecursNatural
	if recurs:
		recurs.cops = MIDES[mida].cops
		recurs.quantitat_min = MIDES[mida].min
		recurs.quantitat_max = MIDES[mida].max
		recurs.position.y = minf(dades.mida.y * 0.5, 0.6)
		recurs.radi_ocupat = maxf(dades.mida.x, dades.mida.z) * 0.5

## La malla del model, centrada (els models no tenen l'origen al mig) i amb la base a terra
static func _model(cami: String) -> Dictionary:
	if _models.has(cami):
		return _models[cami]
	if not ResourceLoader.exists(cami):
		return {}
	var escena: Node3D = (load(cami) as PackedScene).instantiate()
	var st := SurfaceTool.new()
	var textura: Texture2D = null
	for m in escena.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			st.append_from(mi.mesh, s, mi.transform)
			var mat := mi.get_active_material(s)
			if mat is BaseMaterial3D and textura == null:
				textura = mat.albedo_texture
	escena.free()
	var malla := st.commit()
	var aabb := malla.get_aabb()
	var centre := Vector3(-aabb.get_center().x, -aabb.position.y, -aabb.get_center().z)
	_models[cami] = {"malla": malla, "centre": centre, "mida": aabb.size, "textura": textura}
	return _models[cami]

static func _material(pedra: int, textura: Texture2D) -> ShaderMaterial:
	if _materials.has(pedra):
		return _materials[pedra]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("textura", textura)
	m.set_shader_parameter("color_fosc", PEDRES[pedra][0])
	m.set_shader_parameter("color_clar", PEDRES[pedra][1])
	_materials[pedra] = m
	return m
