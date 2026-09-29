extends Node3D

@export var cultiu_escena: PackedScene
@onready var zona_hort = $ZonaHort
@onready var cursor = $CursorPlantacio
@onready var particules_plantar = $ParticulesPlantar
@onready var particules_collir = $ParticulesCollir
@onready var spawn_casa = $SpawnCasa

var blocs_plantables = ["cube-top_001","cube-top_002","cube-top_003","cube-top_004","cube-top_005","cube-top_006","cube-top_007","cube-top_008","cube-top_009","cube_half-top_001", "cube_half-top_002", "cube_half-top_003", "cube_half-top_004","cube_half-top_005","cube_half-top_006","cube_half-top_007","cube_half-top_008","cube_half-top_009","cube-top_019","cube-top_020","cube-top_021","cube-top_023","cube-top_025","cube_008","cube_009","cube_010","cube_half-top_019","cube_half-top_020","cube_half-top_021","cube_half-top_024","cube_half-top_025"]
@onready var roda_seleccio = $RodaSeleccio
# El mode plantar (roda, cursor, vista prèvia, àrees) el porta el Plantador
var plantador: Plantador
var regador: Regador
var llaurador: Llaurador

# Terra llaurada pel jugador (fora de la ZonaHort també s'hi pot plantar)
var llaurades := {}   # Vector3i -> true
const NOMS_HERBA := ["cube-top", "cube_half-top"]
## Peça de terra segons quins veïns són herba (W=oest, E=est, N=nord, S=sud)
const VARIANTS_TERRA := {"": "005", "W": "002", "E": "008", "N": "006", "S": "004",
	"WS": "001", "WN": "003", "ES": "007", "EN": "009"}

func _ready():
	cursor.visible = false
	GestorPartida.registrar_mundo(self)
	var hud_diners := HudDiners.new()
	hud_diners.marge_superior = 70   # a sota del rellotge
	add_child(hud_diners)
	add_child(HudOnades.new())
	var hud_combat := HudCombat.new()
	hud_combat.jugador = $Personatge
	add_child(hud_combat)

	plantador = Plantador.new()
	plantador.name = "Plantador"
	plantador.configurar(self, $GridMap, roda_seleccio, cursor, blocs_plantables)
	add_child(plantador)
	regador = Regador.new()
	regador.name = "Regador"
	regador.configurar(self, plantador, $Personatge)
	add_child(regador)
	llaurador = Llaurador.new()
	llaurador.name = "Llaurador"
	llaurador.configurar(self, plantador, $Personatge)
	add_child(llaurador)
	# Només un mode d'eina alhora: plantar, regar o llaurar
	for eina in [plantador, regador, llaurador]:
		eina.mode_canviat.connect(func(actiu): if actiu: _nomes_una_eina(eina))

	var hud_llaurar := HudEina.new()
	hud_llaurar.configurar(llaurador, "llaurar", "⛏", Color(0.85, 0.65, 0.35), "Clic: llaurar · Arrossega: àrea · Clic dret: sortir", 1)
	add_child(hud_llaurar)
	var hud_rec := HudEina.new()
	hud_rec.configurar(regador, "regar", "💧", Color(0.45, 0.75, 1.0), "Clic: regar · Clic dret: sortir", 0)
	add_child(hud_rec)
	var hud_plantar := HudPlantar.new()
	hud_plantar.plantador = plantador
	add_child(hud_plantar)
	
	if EventBus.has_signal("player_spawn_requested"):
		EventBus.player_spawn_requested.connect(_on_player_spawn_requested)
	else:
		print("Signal player_spawn_requested no existeix a EventBus")
	
	if EventBus.has_pending_spawn:
		var posicio = EventBus.consume_pending_spawn()
		await get_tree().process_frame
		aplicar_spawn_player(posicio)
	elif is_instance_valid(spawn_casa):
		await get_tree().process_frame
		aplicar_spawn_player(spawn_casa.global_position)
	
	# Crea el material del cursor per codi
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.2, 1.0, 0.2, 0.5)
	cursor.set_surface_override_material(0, material)
	
	# Assigna mesh a les partícules
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.1, 0.1)
	particules_plantar.draw_pass_1 = mesh
		
	# Partícules de collir
	var mesh2 = QuadMesh.new()
	mesh2.size = Vector2(0.1, 0.1)
	particules_collir.draw_pass_1 = mesh2

	var process_mat = ParticleProcessMaterial.new()
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.spread = 180.0
	process_mat.initial_velocity_min = 3.0
	process_mat.initial_velocity_max = 6.0
	process_mat.gravity = Vector3(0, -9.8, 0)
	process_mat.scale_min = 0.3
	process_mat.scale_max = 0.6
	particules_collir.process_material = process_mat
	particules_collir.one_shot = true
	particules_collir.explosiveness = 0.9
	particules_collir.amount = 40
	particules_collir.lifetime = 1.5
	process_mat.color = Color(1.0, 0.85, 0.0, 1.0)

	if EventBus.has_signal("cultiu_recollit"):
		EventBus.cultiu_recollit.connect(_on_cultiu_recollit)
	else:
		print("Signal cultiu_recollit no existeix a EventBus")
	
	# CARREGA EL WORLD
	carregar_mundo()
	
func _on_cultiu_recollit(posicio: Vector3):
	print("Event rebut a posicio: ", posicio)
	llançar_particules(particules_collir, posicio)

func _exit_tree():
	GestorPartida.desregistrar_mundo()

func _has_property(obj: Object, name: String) -> bool:
	for prop in obj.get_property_list():
		if prop["name"] == name:
			return true
	return false

func _on_player_spawn_requested(posicio: Vector3):
	await get_tree().process_frame
	aplicar_spawn_player(posicio)

func aplicar_spawn_player(posicio: Vector3):
	var player = get_node_or_null("Personatge")
	if player and is_instance_valid(player) and player.is_inside_tree():
		var spawn_pos = posicio
		spawn_pos.y = max(posicio.y, 1.0)
		player.global_position = spawn_pos
		player.global_rotation = Vector3.ZERO
		print("Personatge reposicionat a: ", spawn_pos)
	else:
		print("No s'ha trobat el Personatge o no està preparat")

## Planta un cultiu a `posicio` (ja validada pel Plantador). Gasta una llavor.
func plantar_cultiu(escena: PackedScene, posicio: Vector3) -> bool:
	if not Inventari.treure("llavor_raim"):
		return false
	var cultiu = escena.instantiate()
	cultiu.add_to_group("cultius")
	add_child(cultiu)
	cultiu.global_position = posicio
	# Petit bot en aparèixer
	cultiu.scale = Vector3.ONE * 0.4
	cultiu.create_tween().tween_property(cultiu, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	llançar_particules(particules_plantar, posicio)
	GestorPartida.call_deferred("guardar_mundo")
	return true

func llançar_particules(particules: GPUParticles3D, posicio: Vector3):
	particules.global_position = posicio
	particules.restart()
	particules.emitting = true
	
func cultiu_a_prop(posicio: Vector3) -> bool:
	for node in get_tree().get_nodes_in_group("cultius"):
		if node.global_position.distance_to(posicio) < 1.0:
			return true
	return false
	
## En entrar en un mode d'eina, surt dels altres
func _nomes_una_eina(eina: Node) -> void:
	for altra in [plantador, regador, llaurador]:
		if altra != eina and altra.actiu:
			altra.sortir()

## Es pot plantar a la cel·la? A la ZonaHort (peces de terra) o on el jugador ha llaurat
func es_plantable(cella: Vector3i, nom: String, posicio: Vector3) -> bool:
	if llaurades.has(cella):
		return true
	return nom in blocs_plantables and dins_zona_hort(posicio)

func es_herba(nom: String) -> bool:
	return nom in NOMS_HERBA

## Converteix l'herba de la cel·la en terra i arregla les vores de les veïnes
func llaurar_cella(cella: Vector3i) -> void:
	var gridmap: GridMap = $GridMap
	var nom := gridmap.mesh_library.get_item_name(gridmap.get_cell_item(cella))
	llaurades[cella] = true
	if es_herba(nom):
		gridmap.set_cell_item(cella, gridmap.mesh_library.find_item_by_name(_prefix_terra(nom) + "005"))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			_autotile(cella + Vector3i(dx, 0, dz))

func _prefix_terra(nom: String) -> String:
	return "cube_half-top_" if nom.begins_with("cube_half") else "cube-top_"

## Tria la peça de terra (centre, vora o cantonada) segons quins veïns són herba
func _autotile(cella: Vector3i) -> void:
	var gridmap: GridMap = $GridMap
	var item := gridmap.get_cell_item(cella)
	if item == GridMap.INVALID_CELL_ITEM:
		return
	var nom := gridmap.mesh_library.get_item_name(item)
	var prefix := _prefix_terra(nom)
	# Només les 9 peces de terra "normals" (les especials de l'hort no es toquen)
	if not nom.begins_with(prefix) or not nom.trim_prefix(prefix) in VARIANTS_TERRA.values():
		return
	var clau := ""
	for costat in [["W", Vector3i(-1, 0, 0)], ["E", Vector3i(1, 0, 0)], ["N", Vector3i(0, 0, -1)], ["S", Vector3i(0, 0, 1)]]:
		if not _es_terra(cella + costat[1]):
			clau += costat[0]
	var variant: String = VARIANTS_TERRA.get(clau, "005")
	var nou := gridmap.mesh_library.find_item_by_name(prefix + variant)
	if nou != GridMap.INVALID_CELL_ITEM:
		gridmap.set_cell_item(cella, nou)

func _es_terra(cella: Vector3i) -> bool:
	var gridmap: GridMap = $GridMap
	var item := gridmap.get_cell_item(cella)
	if item == GridMap.INVALID_CELL_ITEM:
		return false
	return llaurades.has(cella) or gridmap.mesh_library.get_item_name(item) in blocs_plantables

func dins_zona_hort(posicio: Vector3) -> bool:
	return zona_hort.conte_punt(posicio)
	
func guardar_mundo():
	var cultius_data = []
	var plantes_data = []
	
	# Guarda tots els cultius
	for cultiu in get_tree().get_nodes_in_group("cultius"):
		cultius_data.append({
			"escena": cultiu.scene_file_path,
			"posicio": {"x": cultiu.global_position.x, "y": cultiu.global_position.y, "z": cultiu.global_position.z},
			"estat": cultiu.estat_actual,
			"dies_passats": cultiu.dies_passats,
			"es_torre": cultiu.es_torre if _has_property(cultiu, "es_torre") else false,
			"vida_actual": cultiu.vida_actual if _has_property(cultiu, "vida_actual") else 0,
			"regat": cultiu.regat
		})
	
	# Guarda totes les plantes (si n'hi ha al mundo)
	for planta in get_tree().get_nodes_in_group("decoracio"):
		if planta.get_parent() == self:  # Només les del mundo
			plantes_data.append({
				"posicio": {"x": planta.global_position.x, "y": planta.global_position.y, "z": planta.global_position.z},
				"rotacio": {"x": planta.rotation.x, "y": planta.rotation.y, "z": planta.rotation.z}
			})
	
	var mundo_data = {
		"llaurades": llaurades.keys().map(func(c): return [c.x, c.y, c.z]),
		"cultius": cultius_data,
		"plantes": plantes_data
	}
	
	var json = JSON.stringify(mundo_data)
	var fitxer = FileAccess.open("user://mundo_cultius.save", FileAccess.WRITE)
	if fitxer:
		fitxer.store_string(json)
		print("Mundo guardat!")
	else:
		print("Error: No es pot guardar el mundo")

func carregar_mundo():
	var fitxer = FileAccess.open("user://mundo_cultius.save", FileAccess.READ)
	if not fitxer:
		print("Cap mundo guardat prèviament")
		return
	
	var json_string = fitxer.get_as_text()
	if json_string.is_empty():
		print("Fitxer buit")
		return
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		print("Error al parsejar JSON")
		return
	
	var mundo_data = json.data
	
	if mundo_data == null:
		print("Error: Dades nules")
		return
	
	# Carrega cultius
	# Terra que el jugador havia llaurat
	for c in mundo_data.get("llaurades", []):
		llaurar_cella(Vector3i(int(c[0]), int(c[1]), int(c[2])))
	var cultius_data = mundo_data.get("cultius", [])
	for data in cultius_data:
		var escena: PackedScene = CatalegCultius.TOTS[0]
		var ruta = data.get("escena", "")
		if ruta is String and not ruta.is_empty() and ResourceLoader.exists(ruta):
			escena = load(ruta)
		var cultiu = escena.instantiate()
		add_child(cultiu)
		
		var posicio = Vector3(data.get("posicio")["x"], data.get("posicio")["y"], data.get("posicio")["z"])
		cultiu.global_position = posicio
		var estat_guardat = data.get("estat", 0)
		cultiu.estat_actual = int(clamp(estat_guardat, 0, cultiu.Estat.MADUR))
		cultiu.dies_passats = data.get("dies_passats", 0)
		if _has_property(cultiu, "vida_actual"):
			cultiu.vida_actual = data.get("vida_actual", cultiu.vida_maxima)
		
		
		cultiu.actualitzar_sprite()
		if data.get("regat", false):
			cultiu.regar()
	
	print("Cultius carregats!")

# ─────────────── Abast del cultiu seleccionat (sota el cursor de plantar)

