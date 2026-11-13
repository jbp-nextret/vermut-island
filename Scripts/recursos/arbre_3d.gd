extends Node3D
class_name Arbre3D
## Un arbre fet amb el model de Blender (Models/arbre.glb). L'origen és a la base del tronc.
##
## Hi ha un model per a cada estat: soca (quan el tales), brot, jove i adult (vegeu MODELS).
## El .glb porta el tronc i moltes fulles separades (cada fulla és un node). Per no
## tenir centenars de nodes per arbre, la primera vegada s'ajunten en una sola malla
## amb dues superfícies (tronc i fulles) que comparteixen tots els arbres.
## El color es posa aquí (vegeu Shaders/arbre.gdshader): les textures són en gris.

## Un model per estat. Si n'hi falta algun, es fa servir l'adult (encongit, com abans);
## l'adult, si no hi és arbre_adult.glb, és el primer model (arbre.glb).
const MODELS := {
	"soca": "res://Models/arbre_soca.glb",
	"brot": "res://Models/arbre_brot.glb",
	"jove": "res://Models/arbre_jove.glb",
	"adult": "res://Models/arbre_adult.glb",
}
const MODEL_ADULT_ANTIC := "res://Models/arbre.glb"
const SHADER := preload("res://Shaders/arbre.gdshader")
const ESCALA := 1.0

## Colors del degradat (del gris fosc al clar de la textura)
const COLOR_TRONC_FOSC := Color(0.2, 0.12, 0.07)
const COLOR_TRONC_CLAR := Color(0.58, 0.4, 0.25)
const COLOR_BRANCA := Color(0.12, 0.26, 0.11)     # el negre de la textura de les fulles
const COLOR_FULLA := Color(0.56, 0.82, 0.3)

## camí del model -> {malla: ArrayMesh, materials: Array[ShaderMaterial]}
static var _models := {}
static var _material_fulles: ShaderMaterial   # compartit per tots (estacions)

var model: MeshInstance3D
var estat := "adult"

func _ready():
	model = get_node_or_null("Model") as MeshInstance3D
	if model == null:
		model = MeshInstance3D.new()
		model.name = "Model"
		model.scale = Vector3.ONE * ESCALA
		add_child(model)
		posar_estat(estat)
	# Cada arbre girat i amb un to una mica diferent
	model.rotation.y = randf() * TAU
	model.set_instance_shader_parameter("variacio", randf_range(-1.0, 1.0))

## Hi ha un model propi per a aquest estat?
static func te_model(e: String) -> bool:
	return ResourceLoader.exists(MODELS.get(e, ""))

## Posa el model de l'estat ("soca", "brot", "jove" o "adult"). Retorna false si no n'hi ha
## de propi (llavors posa l'adult, i qui el crida l'ha d'encongir).
func posar_estat(e: String) -> bool:
	estat = e
	var propi := te_model(e)
	var cami: String = MODELS[e] if propi else (MODELS.adult if te_model("adult") else MODEL_ADULT_ANTIC)
	var dades := carregar(cami)
	if model and dades:
		model.mesh = dades.malla
		for i in dades.materials.size():
			model.set_surface_override_material(i, dades.materials[i])
	return propi

## Per la transparència quan tapa el personatge (0 = invisible, 1 = opac)
func posar_opacitat(o: float):
	if model:
		model.set_instance_shader_parameter("opacitat", o)

## La malla del model (les fulles i el tronc ajuntats) i els seus materials, compartits
## per tots els arbres que fan servir aquest model
static func carregar(cami: String) -> Dictionary:
	if _models.has(cami):
		return _models[cami]
	if not ResourceLoader.exists(cami):
		return {}
	var escena: Node3D = (load(cami) as PackedScene).instantiate()
	var tronc := SurfaceTool.new()
	var fulles := SurfaceTool.new()
	var textura_tronc: Texture2D = null
	var textura_fulles: Texture2D = null
	var hi_ha_tronc := false
	var hi_ha_fulles := false
	for m in escena.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		# Transformació respecte de l'arrel de l'escena
		var xf := mi.transform
		var pare := mi.get_parent()
		while pare and pare != escena:
			if pare is Node3D:
				xf = (pare as Node3D).transform * xf
			pare = pare.get_parent()
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			var es_fulla := mat != null and mat.resource_name.to_lower().begins_with("full")
			var textura: Texture2D = mat.albedo_texture if mat is BaseMaterial3D else null
			if es_fulla:
				fulles.append_from(mi.mesh, s, xf)
				textura_fulles = textura
				hi_ha_fulles = true
			else:
				tronc.append_from(mi.mesh, s, xf)
				textura_tronc = textura
				hi_ha_tronc = true
	escena.free()
	var malla := ArrayMesh.new()
	var materials: Array[ShaderMaterial] = []
	if hi_ha_tronc:
		tronc.commit(malla)
		materials.append(_material(textura_tronc, false, COLOR_TRONC_FOSC, COLOR_TRONC_CLAR))
	if hi_ha_fulles:
		fulles.commit(malla)
		var m := _material(textura_fulles, true, COLOR_BRANCA, COLOR_FULLA)
		if _material_fulles:
			m.set_shader_parameter("color_fosc", _material_fulles.get_shader_parameter("color_fosc"))
			m.set_shader_parameter("color_clar", _material_fulles.get_shader_parameter("color_clar"))
		_material_fulles = m
		materials.append(m)
	_models[cami] = {"malla": malla, "materials": materials}
	return _models[cami]

## La malla de l'arbre adult (per a qui la necessiti)
static func malla() -> ArrayMesh:
	var d := carregar(MODELS.adult if te_model("adult") else MODEL_ADULT_ANTIC)
	return d.malla if d else null

static func _material(textura: Texture2D, es_fulles: bool, fosc: Color, clar: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("textura", textura)
	m.set_shader_parameter("es_fulles", es_fulles)
	m.set_shader_parameter("color_fosc", fosc)
	m.set_shader_parameter("color_clar", clar)
	return m

## Canvia el color de les fulles de tots els arbres (per a les estacions, per exemple)
static func posar_color_fulles(fosc: Color, clar: Color):
	for cami in _models:
		for m in _models[cami].materials:
			if m.get_shader_parameter("es_fulles"):
				m.set_shader_parameter("color_fosc", fosc)
				m.set_shader_parameter("color_clar", clar)
