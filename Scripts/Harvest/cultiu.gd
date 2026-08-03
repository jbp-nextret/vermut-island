extends Node3D

enum Estat { LLAVOR, CREIXENT, MIG, GRAN, MADUR }
enum TipusCultiu { NORMAL, DEFENSA_RANGED, DEFENSA_MELEE, VINYEDO, FLOR }

@export var dies_per_fase = 2
@export var textures: Array[Texture2D] = []
@export var llavor_drop_escena: PackedScene
@export var projectil_escena: PackedScene

@export var tipus_cultiu: TipusCultiu = TipusCultiu.NORMAL

@export var defensa_range: float = 5.0
@export var defensa_cooldown: float = 1.2
@export var defensa_dany_base: int = 8
@export var defensa_velocitat: float = 18.0
@export var defensa_abast: float = 12.0

@export var radi_influencia: float = 3.0
@export var modificador_dany: float = 0.0
@export var mostrar_radi_influencia: bool = true

@export var vida_maxima: int = 10
@export var es_torre: bool = true

var estat_actual = Estat.LLAVOR
var dies_passats = 0
var recollit = false
var jugador_a_prop = false
var temps_darrer_defensa: float = 0.0
var temps_darrera_recalculacio: float = 0.0
var vida_actual: int = 0
var defensa_dany: int = 0
var modificador_total_actual: float = 0.0

@onready var sprite = $Sprite
@onready var area = $Area3D
@onready var icona = $IconaRecollir

var indicador_radi: MeshInstance3D = null

func _ready():
	icona.text = "🖱️"
	icona.visible = false
	icona.position.y = 1.2
	icona.font_size = 32
	icona.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_to_group("cultius")
	vida_actual = vida_maxima
	defensa_dany = defensa_dany_base

	if not projectil_escena:
		var projectil_path := "res://Scenes/Projectil.tscn"
		if ResourceLoader.exists(projectil_path):
			var loaded_scene = ResourceLoader.load(projectil_path, "PackedScene")
			if loaded_scene:
				projectil_escena = loaded_scene
			else:
				push_error("No s'ha pogut carregar " + projectil_path + " com a PackedScene")
		else:
			push_error("No existeix " + projectil_path)
	
	actualitzar_sprite()

	if (tipus_cultiu == TipusCultiu.VINYEDO or tipus_cultiu == TipusCultiu.FLOR):
		_crear_indicador_radi()
		indicador_radi.visible = EventBus.mode_plantar_actiu
		EventBus.mode_plantar_canviat.connect(_on_mode_plantar_canviat)
			
func _on_mode_plantar_canviat(actiu: bool):
	if indicador_radi:
		indicador_radi.visible = actiu
		
func _crear_indicador_radi():
	indicador_radi = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radi_influencia
	disc.bottom_radius = radi_influencia
	disc.height = 0.02
	indicador_radi.mesh = disc

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var color_base = Color(0.8, 0.1, 0.1, 0.15) if tipus_cultiu == TipusCultiu.VINYEDO else Color(0.1, 0.8, 0.2, 0.15)
	mat.albedo_color = color_base
	indicador_radi.material_override = mat

	add_child(indicador_radi)
	indicador_radi.position = Vector3(0, 0.02, 0)

func passar_dia():
	if recollit or estat_actual == Estat.MADUR:
		return
	dies_passats += 1
	if dies_passats >= dies_per_fase:
		dies_passats = 0
		if estat_actual < Estat.MADUR:
			estat_actual += 1
			actualitzar_sprite()

func actualitzar_sprite():
	if textures.size() == 0:
		print("ERROR: No hi ha textures assignades al cultiu")
		return
	var index_visual = _index_visual_per_estat(estat_actual)
	if index_visual < 0 or index_visual >= textures.size():
		print("ERROR: estat_actual (", estat_actual, ") fora de rang de textures (", textures.size(), ")")
		return
	var material = sprite.get_surface_override_material(0)
	if material == null:
		material = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		sprite.set_surface_override_material(0, material)
	material = material.duplicate()
	material.albedo_texture = textures[index_visual]
	sprite.set_surface_override_material(0, material)

func _index_visual_per_estat(estat: int) -> int:
	match estat:
		Estat.LLAVOR: return 0
		Estat.CREIXENT: return 1
		Estat.MIG: return 1
		Estat.GRAN: return 2
		Estat.MADUR: return 2
		_: return clamp(estat, 0, textures.size() - 1)

func _process(delta):
	if recollit:
		return

	if tipus_cultiu == TipusCultiu.DEFENSA_RANGED or tipus_cultiu == TipusCultiu.DEFENSA_MELEE:
		temps_darrera_recalculacio += delta
		if temps_darrera_recalculacio >= 1.0:
			temps_darrera_recalculacio = 0.0
			recalcular_dany()

	if es_torre and GestorTemps.es_nit() and estat_actual == Estat.MADUR:
		temps_darrer_defensa += delta
		if tipus_cultiu == TipusCultiu.DEFENSA_MELEE:
			atacar_enemic_melee()
		else:
			atacar_enemic_proper()
		return

	if es_torre:
		return

	if estat_actual != Estat.MADUR:
		return

	var personatge = get_node("../Personatge")
	if personatge == null:
		return

	var distancia = global_position.distance_to(personatge.global_position)

	if distancia < 1.5:
		icona.visible = true
		if not jugador_a_prop:
			jugador_a_prop = true
		var escala = 1.0 + sin(Time.get_ticks_msec() * 0.005) * 0.2
		icona.modulate = Color(1.0, 1.0, 1.0, escala)
		icona.font_size = int(32 * escala)
		if Input.is_action_just_pressed("accio_secundaria"):
			recollit = true
			Inventari.afegir("raim", 1)
			for i in range(randi_range(1, 3)):
				generar_llavor_drop()
			EventBus.emit_signal("cultiu_recollit", global_position)
			GestorPartida.guardar_mundo()
			queue_free()
	else:
		icona.visible = false
		if jugador_a_prop:
			jugador_a_prop = false
			$Sprite.scale = Vector3.ONE

func recalcular_dany():
	var modificador_total: float = 0.0
	for cultiu in get_tree().get_nodes_in_group("cultius"):
		if cultiu == self or not is_instance_valid(cultiu):
			continue
		if cultiu.tipus_cultiu != TipusCultiu.VINYEDO and cultiu.tipus_cultiu != TipusCultiu.FLOR:
			continue
		var dist = global_position.distance_to(cultiu.global_position)
		if dist <= cultiu.radi_influencia:
			modificador_total += cultiu.modificador_dany

	modificador_total_actual = modificador_total
	defensa_dany = max(1, int(round(defensa_dany_base * (1.0 + modificador_total))))
	_actualitzar_tint_influencia()

func _actualitzar_tint_influencia():
	var material = sprite.get_surface_override_material(0)
	if material == null:
		return
	material = material.duplicate()

	if modificador_total_actual < -0.01:
		var intensitat = clamp(abs(modificador_total_actual), 0.0, 1.0)
		material.albedo_color = Color(1.0, 1.0 - intensitat * 0.6, 1.0 - intensitat * 0.6)
	elif modificador_total_actual > 0.01:
		var intensitat = clamp(modificador_total_actual, 0.0, 1.0)
		material.albedo_color = Color(1.0 - intensitat * 0.6, 1.0, 1.0 - intensitat * 0.6)
	else:
		material.albedo_color = Color.WHITE

	sprite.set_surface_override_material(0, material)

func generar_llavor_drop():
	if not llavor_drop_escena:
		print("Falta assignar llavor_drop_escena a l'Inspector")
		return
	var drop = llavor_drop_escena.instantiate()
	get_parent().add_child(drop)
	var offset = Vector3(randf_range(-0.3, 0.3), 0.5, randf_range(-0.3, 0.3))
	drop.global_position = global_position + offset
	drop.tipus_llavor = "llavor_raim"
	drop.quantitat = 1

func atacar_enemic_proper():
	if temps_darrer_defensa < defensa_cooldown:
		return
	var millor: Node3D = null
	var millor_dist = INF
	for enemic in get_tree().get_nodes_in_group("enemics"):
		if not is_instance_valid(enemic):
			continue
		var dist = global_position.distance_to(enemic.global_position)
		if dist <= defensa_range and dist < millor_dist:
			millor_dist = dist
			millor = enemic
	if millor:
		temps_darrer_defensa = 0.0
		disparar_projectil(millor)

func atacar_enemic_melee():
	if temps_darrer_defensa < defensa_cooldown:
		return
	for enemic in get_tree().get_nodes_in_group("enemics"):
		if not is_instance_valid(enemic):
			continue
		var dist = global_position.distance_to(enemic.global_position)
		if dist <= defensa_range:
			temps_darrer_defensa = 0.0
			if enemic.has_method("prendre_dany"):
				enemic.prendre_dany(defensa_dany)
			return

func disparar_projectil(objetiu: Node3D):
	if not projectil_escena:
		print("No hi ha escena de projectil assignada")
		return
	var projectil = projectil_escena.instantiate()
	if not projectil:
		print("No s'ha pogut instanciar el projectil")
		return
	get_parent().add_child(projectil)
	projectil.global_position = global_position + Vector3(0, 0.5, 0)
	if projectil.has_method("inicialitzar"):
		projectil.inicialitzar(objetiu, defensa_dany, defensa_velocitat, defensa_abast, self)

func prendre_dany(quantitat: int):
	vida_actual -= quantitat
	print("Cultiu rep ", quantitat, " dany. Vida: ", vida_actual)
	if vida_actual <= 0:
		queue_free()
