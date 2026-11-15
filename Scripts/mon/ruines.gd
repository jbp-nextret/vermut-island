extends Node3D
class_name Ruines
## Ruïnes antigues a les illetes: un grup de columnes (Models/Dungeons/Columna.glb) en
## cercle o en filera, algunes trencades o caigudes. La pedra i les plantes enfiladisses
## són les del bioma de l'illa (Biomes). Sempre surten igual (la llavor és la posició).
## Ocupen terreny: el regenerador i les marques d'excavació no hi posen res a sobre
## (grup "ocupa_terreny", amb el meta "radi").

const MODEL := "res://Models/Dungeons/Columna.glb"
const SHADER_PEDRA := preload("res://Shaders/columna.gdshader")
const SHADER_PLANTES := preload("res://Shaders/enfiladisses.gdshader")
const ESCALA := 0.28            # el model fa 10 m d'alt: queda de 2,8 m
const RADI_COLUMNA := 0.35
const ALCADA := 2.8
const RADI_LLOC := 3.4          # el que ocupa tota la ruïna
const NODES_PLANTES := ["Lower-vine-left", "Lower-vine-right", "Upper-vine-back", "Upper-vine-front"]

static var _escena: PackedScene
static var _materials := {}   # "pedra_<bioma>" / "plantes_<bioma>" -> ShaderMaterial

var bioma := "prat"
var mida := 1.0   # 1 = amb tot l'espai; més petita a les illetes estretes
var rng := RandomNumberGenerator.new()

## Una ruïna a cada illeta (on hi hagi prou lloc pla)
static func crear_a_les_illetes(mon: Node3D, gridmap: GridMap, illes: Array) -> void:
	if not ResourceLoader.exists(MODEL):
		return
	for i in illes.size():
		var lloc = _lloc_pla(mon, gridmap, illes[i].herba, 0)
		if lloc == null:
			continue
		var r := Ruines.new()
		r.name = "Ruines%d" % (i + 1)
		# Amb poc espai, més petita
		r.mida = clampf(float(lloc.espai) / 49.0, 0.65, 1.0)
		mon.add_child(r)
		r.global_position = lloc.posicio
		r.construir()

## El lloc més pla i ample de l'illa: la cel·la amb més cel·les lliures al voltant (al
## mateix nivell i sense res a sobre) en un quadrat de 7 × 7. Les illetes són petites, i
## la ruïna s'hi adapta (vegeu `espai`).
static func _lloc_pla(mon: Node3D, gridmap: GridMap, celles: Array, _llavor: int) -> Variant:
	var millor = null
	var millor_punts := 0
	for cella in celles:
		var punts := 0
		for dx in range(-3, 4):
			for dz in range(-3, 4):
				var v: Vector3i = cella + Vector3i(dx, 0, dz)
				if gridmap.get_cell_item(v) != GridMap.INVALID_CELL_ITEM and gridmap.get_cell_item(v + Vector3i.UP) == GridMap.INVALID_CELL_ITEM:
					punts += 1
		if punts > millor_punts:
			millor_punts = punts
			millor = cella
	if millor == null or millor_punts < 20:
		return null
	var p := gridmap.to_global(gridmap.map_to_local(millor))
	p.y = gridmap.to_global(Vector3(0, millor.y + 1, 0)).y
	return {"posicio": p, "espai": millor_punts}

func construir():
	add_to_group("ocupa_terreny")
	set_meta("radi", RADI_LLOC * mida)
	bioma = Biomes.a(global_position)
	# Si d'una partida d'abans hi havia arbres o roques on ara hi ha la ruïna, fora
	get_tree().create_timer(0.6).timeout.connect(_treure_recursos_de_sota)
	rng.seed = hash(Vector3i(global_position.round()))
	if rng.randf() < 0.55:
		# En cercle (un antic temple), amb algun buit
		var n := rng.randi_range(5, 7)
		var radi := rng.randf_range(2.0, 2.5) * mida
		var gir := rng.randf() * TAU
		for i in n:
			if rng.randf() < 0.15:
				continue
			var a := gir + TAU * i / n
			_columna(Vector3(cos(a), 0, sin(a)) * radi)
	else:
		# En filera (una columnata)
		var n := rng.randi_range(3, 5 if mida > 0.85 else 4)
		var dir := Vector3.RIGHT.rotated(Vector3.UP, rng.randi_range(0, 3) * PI / 2.0)
		for i in n:
			_columna(dir * (i - (n - 1) / 2.0) * 1.7 * mida)

## Una columna: dreta, trencada (més baixa) o caiguda
func _columna(on: Vector3):
	if _escena == null:
		_escena = load(MODEL)
	var model: Node3D = _escena.instantiate()
	var cos := StaticBody3D.new()
	add_child(cos)
	cos.position = on
	cos.rotation.y = rng.randf() * TAU
	cos.add_child(model)
	model.scale = Vector3.ONE * ESCALA
	var forma := CollisionShape3D.new()
	var estat := rng.randf()
	if estat < 0.15:
		# Caiguda: estirada a terra
		model.rotation.x = PI / 2.0
		model.position = Vector3(0, RADI_COLUMNA * 0.9, -ALCADA * 0.5)
		var caixa := BoxShape3D.new()
		caixa.size = Vector3(RADI_COLUMNA * 2.0, RADI_COLUMNA * 1.8, ALCADA)
		forma.shape = caixa
		forma.position = Vector3(0, RADI_COLUMNA * 0.9, 0)
	else:
		var alcada := 1.0
		if estat < 0.45:
			alcada = rng.randf_range(0.35, 0.7)   # trencada
			model.scale.y *= alcada
		var cilindre := CylinderShape3D.new()
		cilindre.radius = RADI_COLUMNA
		cilindre.height = ALCADA * alcada
		forma.shape = cilindre
		forma.position = Vector3.UP * ALCADA * alcada * 0.5
	cos.add_child(forma)
	_pintar(model)

## Els materials del bioma; les plantes, només algunes (segons el bioma)
func _pintar(model: Node3D):
	var dades: Dictionary = Biomes.BIOMES[bioma]
	var plantes: Array = dades.get("enfiladisses", [Color(0.27, 0.5, 0.22), 0.6])
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if mi.name in NODES_PLANTES:
			mi.visible = rng.randf() < float(plantes[1])
			mi.material_override = _material_plantes(mi, plantes[0])
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			mi.material_override = _material_pedra(mi, int(dades.pedra))
			mi.set_instance_shader_parameter("variacio", rng.randf_range(-1.0, 1.0))

func _material_pedra(mi: MeshInstance3D, pedra: int) -> ShaderMaterial:
	var clau := "pedra_%s" % bioma
	if not _materials.has(clau):
		var m := ShaderMaterial.new()
		m.shader = SHADER_PEDRA
		m.set_shader_parameter("textura", _textura(mi))
		var colors: Array = Roca3D.PEDRES[pedra % Roca3D.PEDRES.size()]
		m.set_shader_parameter("color_fosc", colors[0])
		m.set_shader_parameter("color_clar", colors[1])
		m.set_shader_parameter("color_molsa", Biomes.BIOMES[bioma].get("enfiladisses", [Color(0.27, 0.5, 0.22)])[0])
		_materials[clau] = m
	return _materials[clau]

func _material_plantes(mi: MeshInstance3D, color: Color) -> ShaderMaterial:
	# Cada tros de planta té la seva textura: una clau per bioma i per textura
	var textura := _textura(mi)
	var clau := "plantes_%s_%d" % [bioma, textura.get_instance_id() if textura else 0]
	if not _materials.has(clau):
		var m := ShaderMaterial.new()
		m.shader = SHADER_PLANTES
		m.set_shader_parameter("textura", textura)
		m.set_shader_parameter("color", color)
		_materials[clau] = m
	return _materials[clau]

static func _textura(mi: MeshInstance3D) -> Texture2D:
	var mat := mi.get_active_material(0)
	return mat.albedo_texture if mat is BaseMaterial3D else null

func _treure_recursos_de_sota():
	for r in get_tree().get_nodes_in_group("recursos"):
		if not is_instance_valid(r) or r.is_queued_for_deletion():
			continue
		if Vector2(r.global_position.x - global_position.x, r.global_position.z - global_position.z).length() < RADI_LLOC * mida:
			var node: Node = r.get_parent() if r.get_parent() is Node3D and r.get_parent() != get_parent() else r
			node.queue_free()
