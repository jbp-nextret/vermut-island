extends Node3D

@export var cultiu_escena: PackedScene
@onready var cursor = $CursorPlantacio
@onready var particules_plantar = $ParticulesPlantar
@onready var particules_collir = $ParticulesCollir
@onready var spawn_casa = $SpawnCasa

var blocs_plantables = ["cube-top_001","cube-top_002","cube-top_003","cube-top_004","cube-top_005","cube-top_006","cube-top_007","cube-top_008","cube-top_009","cube_half-top_001", "cube_half-top_002", "cube_half-top_003", "cube_half-top_004","cube_half-top_005","cube_half-top_006","cube_half-top_007","cube_half-top_008","cube_half-top_009","cube-top_019","cube-top_020","cube-top_021","cube-top_023","cube-top_025","cube_008","cube_009","cube_010","cube_half-top_019","cube_half-top_020","cube_half-top_021","cube_half-top_024","cube_half-top_025"]
@onready var roda_seleccio = $RodaSeleccio
# El mode plantar (roda, cursor, vista prèvia, àrees) el porta el Plantador
var plantador: Plantador
var recolector: Recolector
var generador_illes: GeneradorIlles
var regenerador: RegeneradorRecursos
var regador: Regador
var llaurador: Llaurador

# Terra llaurada: l'única on es pot plantar. Hi ha la que ha llaurat el jugador i l'hort
# original (vegeu _marcar_hort_original)
var llaurades := {}   # Vector3i -> true
const NOMS_HERBA := ["cube-top", "cube_half-top"]
## Peça de terra i gir (graus) segons quins veïns són herba (W=oest, E=est, N=nord, S=sud).
## Les tires i els extrems que no tenen peça pròpia fan servir la _019 i la _020 girades.
const VARIANTS_TERRA := {
	"": ["005", 0],
	"W": ["002", 0], "E": ["008", 0], "N": ["006", 0], "S": ["004", 0],
	"WS": ["001", 0], "WN": ["003", 0], "ES": ["007", 0], "EN": ["009", 0],
	"NS": ["020", 0], "WE": ["020", 90],                     # tires
	"WNS": ["019", 0], "ENS": ["021", 0],                    # extrems oberts a l'est / a l'oest
	"WES": ["019", 90], "WEN": ["019", -90],                 # extrems oberts al nord / al sud
	"WENS": ["023", 0],                                      # cel·la aïllada
}
const PECES_AUTOTILE := ["001", "002", "003", "004", "005", "006", "007", "008", "009", "019", "020", "021", "023"]

func _ready():
	cursor.visible = false
	GestorPartida.registrar_mundo(self)
	# La casa i els arbres es tornen semitransparents quan tapen el personatge
	get_node("Casa").add_to_group("ocultables")
	for node in get_children():
		if node is Sprite3D and node.name.begins_with("Tree"):
			node.add_to_group("ocultables")
	# Illetes al voltant de l'illa principal (sempre les mateixes per a la mateixa llavor)
	generador_illes = GeneradorIlles.new()
	generador_illes.name = "GeneradorIlles"
	add_child(generador_illes)
	generador_illes.generar($GridMap)

	# Arbres i herba es poden recol·lectar (les roques ja porten el seu RecursNatural)
	for node in get_children():
		if node is Sprite3D and node.name.begins_with("Tree"):
			_afegir_recurs(node, RecursNatural.Tipus.ARBRE, 3, "fusta", 2, 4, 3, "talar")
		elif node is Sprite3D and node.name.begins_with("Grass"):
			_afegir_recurs(node, RecursNatural.Tipus.HERBA, 1, "fibra", 1, 2, 1, "herba")
	# Recursos que surten sols cada dia (a les illetes i, menys, a l'illa principal)
	regenerador = RegeneradorRecursos.new()
	regenerador.name = "RegeneradorRecursos"
	var model_arbre := get_node_or_null("Tree1") as Node3D
	var model_herba := get_node_or_null("Grass1") as Node3D
	for model in [model_arbre, model_herba]:
		if model:
			model.set_meta("alcada_sobre_terra", model.global_position.y - _terra_sota(model.global_position).y)
	regenerador.configurar(self, $GridMap, model_arbre, model_herba)
	for i in generador_illes.illes.size():
		regenerador.afegir_zona("Illeta %d" % (i + 1), generador_illes.illes[i].herba)
	regenerador.afegir_zona("Illa principal", _celles_herba_principals(), 0.15)
	add_child(regenerador)

	recolector = Recolector.new()
	recolector.name = "Recolector"
	recolector.mon = self
	recolector.jugador = $Personatge
	add_child(recolector)

	var ocultadors := TransparenciaOcultadors.new()
	ocultadors.jugador = $Personatge
	add_child(ocultadors)

	# HUD: vida i rellotge a dalt, diners a sota dels cors, barra d'accions a baix al centre
	get_node("CanvasLayer").visible = false   # el rellotge antic (ara el porta HudJoc)
	add_child(HudJoc.new())
	var hud_diners := HudDiners.new()
	hud_diners.marge_superior = 50   # a sota dels cors, el mana i l'experiència
	add_child(hud_diners)
	add_child(HudOnades.new())

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

	recolector.eines_actives = [plantador, regador, llaurador]
	var barra := BarraAccions.new()
	barra.jugador = $Personatge
	barra.plantador = plantador
	barra.regador = regador
	barra.llaurador = llaurador
	add_child(barra)
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
	_marcar_hort_original()
	carregar_mundo()
	_retirar_recursos_en_conflicte()
	
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
		var camera = player.get_node_or_null("CameraPivot/Camera3D")
		if camera and camera.has_method("centrar_de_cop"):
			camera.centrar_de_cop()
	else:
		print("No s'ha trobat el Personatge o no està preparat")

## Planta un cultiu a `posicio` (ja validada pel Plantador). Gasta una llavor.
func plantar_cultiu(escena: PackedScene, posicio: Vector3) -> bool:
	var plantat := _plantar_cultiu(escena, posicio)
	if plantat:
		Progressio.guanyar_xp("plantar")
	return plantat

func _plantar_cultiu(escena: PackedScene, posicio: Vector3) -> bool:
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
	
## La superfície del terreny just a sota d'un punt (mirant les cel·les del GridMap, que en
## el _ready encara no tenen col·lisions)
func _terra_sota(punt: Vector3) -> Vector3:
	var gridmap: GridMap = $GridMap
	var c: Vector3i = gridmap.local_to_map(gridmap.to_local(punt))
	for y in range(c.y, c.y - 12, -1):
		if gridmap.get_cell_item(Vector3i(c.x, y, c.z)) != GridMap.INVALID_CELL_ITEM:
			return Vector3(punt.x, gridmap.to_global(Vector3(0, y + 1, 0)).y, punt.z)
	return punt

## Les cel·les d'herba de l'illa principal (on poden sortir recursos nous)
func _celles_herba_principals() -> Array:
	var gridmap: GridMap = $GridMap
	var illetes := {}
	for illa in generador_illes.illes:
		for c in illa.herba:
			illetes[c] = true
	var llista := []
	for c in gridmap.get_used_cells():
		if illetes.has(c) or gridmap.get_cell_item(c + Vector3i.UP) != GridMap.INVALID_CELL_ITEM:
			continue
		if gridmap.mesh_library.get_item_name(gridmap.get_cell_item(c)) == "cube-top":
			llista.append(c)
	return llista

## Alçada de la superfície del mar
func nivell_aigua() -> float:
	var mar := get_node_or_null("Sea") as Node3D
	return mar.global_position.y if mar else -INF

## Hi ha cultius, terra llaurada o la zona de l'hort a menys de `radi`? (els recursos no hi
## tornen a sortir, per no ficar-se al mig dels camps)
func zona_de_conreu_a_prop(posicio: Vector3, radi: float) -> bool:
	for c in get_tree().get_nodes_in_group("cultius"):
		if Vector2(c.global_position.x - posicio.x, c.global_position.z - posicio.z).length() < radi:
			return true
	# Terra on es pot plantar (la llaurada; la sorra de la platja no compta)
	var gridmap: GridMap = $GridMap
	var centre: Vector3i = gridmap.local_to_map(gridmap.to_local(posicio))
	var abast := ceili(radi)
	for dx in range(-abast, abast + 1):
		for dz in range(-abast, abast + 1):
			for dy in range(-3, 3):
				var cella := centre + Vector3i(dx, dy, dz)
				var item := gridmap.get_cell_item(cella)
				if item == GridMap.INVALID_CELL_ITEM or gridmap.get_cell_item(cella + Vector3i.UP) != GridMap.INVALID_CELL_ITEM:
					continue   # buida, o no és la de dalt de tot
				var p := gridmap.to_global(gridmap.map_to_local(cella))
				# La mateixa regla que per plantar (així la sorra de la platja no compta)
				if not es_plantable(cella, gridmap.mesh_library.get_item_name(item), p):
					continue
				if Vector2(p.x - posicio.x, p.z - posicio.z).length() < radi:
					return true
	return false

## L'arbre, roca o herba que ocupa el terra en aquest punt (o null)
func recurs_a(posicio: Vector3) -> RecursNatural:
	for r in get_tree().get_nodes_in_group("recursos"):
		if r.ocupa(posicio):
			return r
	return null

## En carregar: els recursos que han quedat dins de zones conreades es retiren
func _retirar_recursos_en_conflicte():
	for r in get_tree().get_nodes_in_group("recursos"):
		if r.disponible() and r.conreu_a_prop():
			r.retirar()

func _afegir_recurs(node: Node3D, tipus: int, cops: int, objecte: String, q_min: int, q_max: int, dies: int, xp: String):
	var r := RecursNatural.new()
	r.name = "Recurs"
	r.tipus = tipus
	r.cops = cops
	r.objecte = objecte
	r.quantitat_min = q_min
	r.quantitat_max = q_max
	r.dies_per_tornar = dies
	r.motiu_xp = xp
	node.add_child(r)

## En entrar en un mode d'eina, surt dels altres
func _nomes_una_eina(eina: Node) -> void:
	for altra in [plantador, regador, llaurador]:
		if altra != eina and altra.actiu:
			altra.sortir()

## Es pot plantar a la cel·la? Només a la terra llaurada (també l'hort original)
func es_plantable(cella: Vector3i, _nom: String = "", _posicio: Vector3 = Vector3.ZERO) -> bool:
	return llaurades.has(cella)

## Sota aquesta alçada, les peces de terra són la sorra de la platja (no l'hort)
const ALCADA_MINIMA_HORT := 0

## L'hort que ja ve fet a l'escena: les peces de terra de la superfície per sobre del nivell
## del mar compten com a llaurades des del principi (la platja usa les mateixes peces, però
## queda més avall).
func _marcar_hort_original():
	var gridmap: GridMap = $GridMap
	for cella in gridmap.get_used_cells():
		if cella.y < ALCADA_MINIMA_HORT or gridmap.get_cell_item(cella + Vector3i.UP) != GridMap.INVALID_CELL_ITEM:
			continue
		if gridmap.mesh_library.get_item_name(gridmap.get_cell_item(cella)) in blocs_plantables:
			llaurades[cella] = true

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
	# Només les peces de terra d'autotiling (la resta d'especials de l'hort no es toquen)
	if not nom.begins_with(prefix) or not nom.trim_prefix(prefix) in PECES_AUTOTILE:
		return
	var clau := ""
	for costat in [["W", Vector3i(-1, 0, 0)], ["E", Vector3i(1, 0, 0)], ["N", Vector3i(0, 0, -1)], ["S", Vector3i(0, 0, 1)]]:
		if not _es_terra(cella + costat[1]):
			clau += costat[0]
	var variant: Array = VARIANTS_TERRA.get(clau, ["005", 0])
	var nou := gridmap.mesh_library.find_item_by_name(prefix + variant[0])
	if nou != GridMap.INVALID_CELL_ITEM:
		var gir := gridmap.get_orthogonal_index_from_basis(Basis(Vector3.UP, deg_to_rad(variant[1])))
		gridmap.set_cell_item(cella, nou, gir)

func _es_terra(cella: Vector3i) -> bool:
	var gridmap: GridMap = $GridMap
	var item := gridmap.get_cell_item(cella)
	if item == GridMap.INVALID_CELL_ITEM:
		return false
	return llaurades.has(cella) or gridmap.mesh_library.get_item_name(item) in blocs_plantables

	
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
		"recursos": RecursNatural.estats(self),
		"recursos_dinamics": regenerador.estat(),
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
	RecursNatural.restaurar(self, mundo_data.get("recursos", {}))
	if mundo_data.has("recursos_dinamics"):
		regenerador.restaurar(mundo_data.recursos_dinamics)
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

