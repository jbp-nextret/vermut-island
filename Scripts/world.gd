extends Node3D

@export var cultiu_escena: PackedScene
@onready var zona_hort = $ZonaHort
@onready var cursor = $CursorPlantacio
@onready var particules_plantar = $ParticulesPlantar
@onready var particules_collir = $ParticulesCollir
@onready var spawn_casa = $SpawnCasa

var mode_plantacio = false
var blocs_plantables = ["cube-top_001","cube-top_002","cube-top_003","cube-top_004","cube-top_005","cube-top_006","cube-top_007","cube-top_008","cube-top_009","cube_half-top_001", "cube_half-top_002", "cube_half-top_003", "cube_half-top_004","cube_half-top_005","cube_half-top_006","cube_half-top_007","cube_half-top_008","cube_half-top_009","cube-top_019","cube-top_020","cube-top_021","cube-top_023","cube-top_025","cube_008","cube_009","cube_010","cube_half-top_019","cube_half-top_020","cube_half-top_021","cube_half-top_024","cube_half-top_025"]
var arrastrant = false
var posicio_drag_inici = Vector3.ZERO
var posicio_drag_actual = Vector3.ZERO
var zone_seleccionada = []  # Llista de posicions a plantar

func _ready():
	cursor.visible = false
	GestorPartida.registrar_mundo(self)
	
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

func _input(event):
	if Input.is_action_just_pressed("plantar"):
		mode_plantacio = true
		cursor.visible = true
		print("Mode plantació activat — clica i arrastra per seleccionar")
	
	# Cancel·la el mode plantació amb Escape
	if Input.is_action_just_pressed("ui_cancel"):
		mode_plantacio = false
		cursor.visible = false
		arrastrant = false
		zone_seleccionada.clear()
		print("Mode plantació cancel·lat")
	
	# Confirma la selecció amb accio_secundaria
	if mode_plantacio and Input.is_action_just_pressed("accio_secundaria"):
		if arrastrant:
			arrastrant = false
			plantar_zona_seleccionada()
			zone_seleccionada.clear()
			print("Plantació confirmada")
			GestorPartida.guardar_mundo()  # Guarda després d'una plantació
	
	# Drag amb accio_primaria
	if mode_plantacio and Input.is_action_just_pressed("accio_primaria"):
		arrastrant = true
		posicio_drag_inici = cursor.global_position
		zone_seleccionada.clear()
		print("Drag iniciat")
	
	if mode_plantacio and Input.is_action_just_released("accio_primaria"):
		if arrastrant:
			print("Drag finalitzat — Clica accio_secundaria per confirmar o Escape per cancel·lar")

func _physics_process(delta: float) -> void:
	var camera = get_viewport().get_camera_3d()
	#print("Càmera actual: ", camera.name, " path: ", camera.get_path())

func _process(delta):
	if not mode_plantacio: return
	var espai = get_world_3d().direct_space_state
	var camera = get_viewport().get_camera_3d()
	var pos_ratolí = get_viewport().get_mouse_position()
	var origen = camera.project_ray_origin(pos_ratolí)
	var direccio = camera.project_ray_normal(pos_ratolí)
	
	var query = PhysicsRayQueryParameters3D.create(origen, origen + direccio * 100.0)
	var resultat = espai.intersect_ray(query)
	
	if resultat:
		var posicio = resultat.position
		var gridmap = get_node("GridMap")
		
		# Busca el bloc directament a sota (mateixa X, Z)
		var pos_x = int(round(posicio.x))
		var pos_z = int(round(posicio.z))
		
		var bloc_trobat = false
		var item_name_mes_propa = ""
		var cell_coords_mes_propa = Vector3i.ZERO
		
		# Busca de dalt a baix a la columna X, Z
		for y in range(int(posicio.y), int(posicio.y) - 5, -1):
			var cell_coords = Vector3i(pos_x, y, pos_z)
			var cell_item = gridmap.get_cell_item(cell_coords)
			if cell_item >= 0:
				var item_name = gridmap.mesh_library.get_item_name(cell_item)
				if item_name in blocs_plantables:
					bloc_trobat = true
					item_name_mes_propa = item_name
					cell_coords_mes_propa = cell_coords
					break
		
		if bloc_trobat:
			var posicio_cursor = gridmap.map_to_local(cell_coords_mes_propa)
			
			if item_name_mes_propa.contains("half"):
				posicio_cursor.y = float(cell_coords_mes_propa.y) + 0.5
			else:
				posicio_cursor.y = float(cell_coords_mes_propa.y) + 1.0
			
			cursor.global_position = posicio_cursor
			cursor.visible = true
			posicio_drag_actual = posicio_cursor
			
			# Si està arrastrant, calcula la zona rectangular
			if arrastrant:
				actualitzar_zona_seleccionada(gridmap, cell_coords_mes_propa, item_name_mes_propa)
		else:
			cursor.visible = false
		
		var mat = cursor.get_surface_override_material(0)
		if mat == null: return
		
		# Canvia color segons si la posició és vàlida
		var posicio_valida = bloc_trobat and not cultiu_a_prop(cursor.global_position) and dins_zona_hort(cursor.global_position)
		
		if arrastrant:
			# Mentre arrossega, mostra feedback
			if posicio_valida:
				mat.albedo_color = Color(0.2, 1.0, 0.2, 0.7)
			else:
				mat.albedo_color = Color(1.0, 0.2, 0.2, 0.7)
		else:
			# Quan no arrossega, mostra color normal
			if posicio_valida:
				mat.albedo_color = Color(0.2, 1.0, 0.2, 0.5)
			else:
				mat.albedo_color = Color(1.0, 0.2, 0.2, 0.5)
	else:
		cursor.visible = false


func actualitzar_zona_seleccionada(gridmap: GridMap, cell_coords: Vector3i, item_name: String):
	# Calcula el rectangle entre la posició inicial i l'actual
	var min_x = mini(gridmap.local_to_map(posicio_drag_inici).x, cell_coords.x)
	var max_x = maxi(gridmap.local_to_map(posicio_drag_inici).x, cell_coords.x)
	var min_z = mini(gridmap.local_to_map(posicio_drag_inici).z, cell_coords.z)
	var max_z = maxi(gridmap.local_to_map(posicio_drag_inici).z, cell_coords.z)
	var y = cell_coords.y
	
	zone_seleccionada.clear()
	
	# Omple el rectangle
	for x in range(min_x, max_x + 1):
		for z in range(min_z, max_z + 1):
			var cell_coords_rect = Vector3i(x, y, z)
			var cell_item = gridmap.get_cell_item(cell_coords_rect)
			if cell_item >= 0:
				var item = gridmap.mesh_library.get_item_name(cell_item)
				if item in blocs_plantables:
					var posicio_final = gridmap.map_to_local(cell_coords_rect)
					if item.contains("half"):
						posicio_final.y = float(cell_coords_rect.y) + 1
					else:
						posicio_final.y = float(cell_coords_rect.y) + 1.5
					
					# Mostra els punts de feedback visual
					visualitzar_posicio_plantacio(posicio_final)
					zone_seleccionada.append({"posicio": posicio_final, "cell_coords": cell_coords_rect, "item_name": item})


func visualitzar_posicio_plantacio(posicio: Vector3):
	# Crea visuals de feedback (petits cursors verds)
	var debug_sphere = MeshInstance3D.new()
	debug_sphere.mesh = SphereMesh.new()
	debug_sphere.mesh.radius = 0.1
	debug_sphere.mesh.height = 0.2
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 1.0, 0.2, 0.8)
	debug_sphere.set_surface_override_material(0, mat)
	add_child(debug_sphere)
	debug_sphere.global_position = posicio
	
	# Elimina el sphere després d'un moment
	await get_tree().create_timer(0.1).timeout
	debug_sphere.queue_free()


func plantar_zona_seleccionada():
	if zone_seleccionada.is_empty():
		print("Cap zona seleccionada")
		return
	
	print("Plantant ", zone_seleccionada.size(), " cultius...")
	
	for data in zone_seleccionada:
		plantar_en_posicio(data["posicio"], get_node("GridMap"), data["cell_coords"], data["item_name"])
	
	GestorPartida.guardar_mundo()
	
	# Desactiva el mode si no queden llavors
	if Inventari.tenir("llavor_raim") <= 0:
		mode_plantacio = false
		cursor.visible = false


func plantar_en_posicio(posicio_cultiu: Vector3, gridmap: GridMap, cell_coords: Vector3i, item_name: String):
	# Comprova si tens llavors
	if Inventari.tenir("llavor_raim") <= 0:
		return
	
	if not dins_zona_hort(posicio_cultiu):
		return
	
	if cultiu_a_prop(posicio_cultiu):
		return
	
	var cultiu = cultiu_escena.instantiate()
	cultiu.add_to_group("cultius")
	add_child(cultiu)
	cultiu.global_position = posicio_cultiu
	if _has_property(cultiu, "es_torre"):
		cultiu.es_torre = true
	llançar_particules(particules_plantar, posicio_cultiu)
	Inventari.items["llavor_raim"] -= 1
	
	print("Cultiu plantat a: ", posicio_cultiu)
	
func llançar_particules(particules: GPUParticles3D, posicio: Vector3):
	particules.global_position = posicio
	particules.restart()
	particules.emitting = true
	
func cultiu_a_prop(posicio: Vector3) -> bool:
	for node in get_tree().get_nodes_in_group("cultius"):
		if node.global_position.distance_to(posicio) < 1.0:
			return true
	return false
	
func dins_zona_hort(posicio: Vector3) -> bool:
	return zona_hort.conte_punt(posicio)
	
func guardar_mundo():
	var cultius_data = []
	var plantes_data = []
	
	# Guarda tots els cultius
	for cultiu in get_tree().get_nodes_in_group("cultius"):
		cultius_data.append({
			"posicio": {"x": cultiu.global_position.x, "y": cultiu.global_position.y, "z": cultiu.global_position.z},
			"estat": cultiu.estat_actual,
			"dies_passats": cultiu.dies_passats,
			"es_torre": cultiu.es_torre if _has_property(cultiu, "es_torre") else false,
			"vida_actual": cultiu.vida_actual if _has_property(cultiu, "vida_actual") else 0
		})
	
	# Guarda totes les plantes (si n'hi ha al mundo)
	for planta in get_tree().get_nodes_in_group("decoracio"):
		if planta.get_parent() == self:  # Només les del mundo
			plantes_data.append({
				"posicio": {"x": planta.global_position.x, "y": planta.global_position.y, "z": planta.global_position.z},
				"rotacio": {"x": planta.rotation.x, "y": planta.rotation.y, "z": planta.rotation.z}
			})
	
	var mundo_data = {
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
	var cultius_data = mundo_data.get("cultius", [])
	for data in cultius_data:
		var cultiu = cultiu_escena.instantiate()
		add_child(cultiu)
		
		var posicio = Vector3(data.get("posicio")["x"], data.get("posicio")["y"], data.get("posicio")["z"])
		cultiu.global_position = posicio
		var estat_guardat = data.get("estat", 0)
		cultiu.estat_actual = int(clamp(estat_guardat, 0, cultiu.Estat.MADUR))
		cultiu.dies_passats = data.get("dies_passats", 0)
		if _has_property(cultiu, "es_torre"):
			cultiu.es_torre = data.get("es_torre", true)
		if _has_property(cultiu, "vida_actual"):
			cultiu.vida_actual = data.get("vida_actual", cultiu.vida_maxima)
		
		print("Carregant cultiu: posicio=", posicio, " estat=", cultiu.estat_actual, " dies=", cultiu.dies_passats, " textures=", cultiu.textures.size())
		
		cultiu.actualitzar_sprite()
	
	print("Cultius carregats!")
