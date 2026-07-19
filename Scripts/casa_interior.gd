extends Node3D

# Variables mobles
@export var mobles_disponibles: Array[PackedScene]
@export var grid_size: float = 1.0

var mode_decoracio = false
var mode_construccio = false
var mode_eliminacio = false
var moble_actual: Node3D = null
var moble_preview: Node3D = null
var moble_hovered: Node3D = null
var punts_grid: Array[Node3D] = []
var index_preview := -1
var rotacio_preview := 0.0
var moble_seleccionat: Node3D = null

# Variables càmera
var camera_rotation_x = 0.0
var camera_rotation_y = 0.0
var camera_distance = 8.0
var camera_height = 5.0

# Variables UI
@onready var panel_ui = $CanvasLayer/Panel
@onready var item_list = $CanvasLayer/ItemList
@onready var porta_sortida = $PortaSortida

# Gestió colors
var materials_originals := {}
var material_hover := StandardMaterial3D.new()

func _ready():
	crear_interior()
	porta_sortida.salir_casa.connect(_on_salir_casa)
	
	# Mobles
	item_list.clear()
	var noms_mobles = ["Barra Normal", "Barra Mig", "Barra Lateral", "Cadira", "Rosa", "Cactus", "Amapola"]
	for nom in noms_mobles:
		item_list.add_item(nom)
	
	panel_ui.visible = false
	item_list.item_selected.connect(_on_moble_seleccionat)
	# CARREGA LA DECORACIÓ GUARDADA
	carregar_decoracio()
	material_hover.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_hover.albedo_color = Color(1, 0, 0, 0.8)

func crear_interior():
	# Sòl
	var sol_static = StaticBody3D.new()
	sol_static.name = "Sol"
	add_child(sol_static)
	
	var sol_mesh = MeshInstance3D.new()
	sol_mesh.mesh = PlaneMesh.new()
	sol_mesh.mesh.size = Vector2(10, 10)
	sol_mesh.position.y = 0
	sol_static.add_child(sol_mesh)
	
	var material_sol = StandardMaterial3D.new()
	material_sol.albedo_color = Color(0.8, 0.7, 0.6)
	sol_mesh.set_surface_override_material(0, material_sol)
	
	var collision = CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	collision.shape.size = Vector3(10, 0.2, 10)
	collision.position.y = -0.1
	sol_static.add_child(collision)
	
	# Parets
	crear_paret("Paret Fons", Vector3(0, 0, -5), Vector3(10, 3, 0.2))
	crear_paret("Paret Esquerra", Vector3(-5, 0, 0), Vector3(0.2, 3, 10))
	crear_paret("Paret Dreta", Vector3(5, 0, 0), Vector3(0.2, 3, 10))
	
	crear_finestra(Vector3(0, 1.5, -5), Vector3(2, 1.5, 0.1))
	crear_porta_visual(Vector3(5, 0, 2), Vector3(0.1, 2, 1))

func crear_paret(nom: String, posicio: Vector3, mida: Vector3):
	var paret_static = StaticBody3D.new()
	paret_static.position = posicio
	paret_static.name = nom
	add_child(paret_static)
	
	var paret_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = mida
	paret_mesh.mesh = box
	paret_static.add_child(paret_mesh)
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.85, 0.8)
	paret_mesh.set_surface_override_material(0, material)
	
	var collision = CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	collision.shape.size = mida
	paret_static.add_child(collision)

func crear_finestra(posicio: Vector3, mida: Vector3):
	var finestra = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = mida
	finestra.mesh = box
	finestra.position = posicio
	finestra.name = "Finestra"
	add_child(finestra)
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.7, 1.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	finestra.set_surface_override_material(0, material)

func crear_porta_visual(posicio: Vector3, mida: Vector3):
	var porta = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = mida
	porta.mesh = box
	porta.position = posicio
	porta.name = "PortaVisual"
	add_child(porta)
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.8, 0.0)
	material.emission = Color(0.8, 0.6, 0.0)
	material.emission_energy_multiplier = 2.0
	porta.set_surface_override_material(0, material)
	
func _input(event):
	if event.is_action_pressed("decorar"):
		if mode_construccio:
			sortir_mode_construccio()
		else:
			entrar_mode_construccio()
			
func _unhandled_input(event: InputEvent) -> void:
	if !mode_construccio:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if mode_eliminacio:
			desactivar_mode_eliminacio()
		return
	
	# ROTACIÓ DE MOBLES AMB Q/E
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			rotacio_preview -= 90
			print("Moble rotat -90°: ", rotacio_preview)
		elif event.keycode == KEY_E:
			rotacio_preview += 90
			print("Moble rotat +90°: ", rotacio_preview)
	
	# ROTACIÓ DE CÀMERA AMB BOTÓ CENTRAL DEL RATOLÍ
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# ROTACIÓ AMB MOVIMENT DEL RATOLÍ
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera_rotation_y -= event.relative.x * 0.01
		camera_rotation_x -= event.relative.y * 0.01
		camera_rotation_x = clamp(camera_rotation_x, -1.5, 1.5)
		actualitzar_posicio_camera()
	
	# ZOOM AMB RODETA
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed and mode_construccio:
			camera_distance -= 0.5
			camera_distance = clamp(camera_distance, 3.0, 15.0)
			actualitzar_posicio_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed and mode_construccio:
			camera_distance += 0.5
			camera_distance = clamp(camera_distance, 3.0, 15.0)
			actualitzar_posicio_camera()
	
	# SELECCIONAR/COL·LOCAR MOBLES (només fora de la UI)
	if event is InputEventMouseButton:
		#if not panel_ui.get_global_rect().has_point(event.position):
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				print("Entrant a col·locar")
				if mode_eliminacio:
					seleccionar_moble()
				else:
					col_locar_moble()
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				if mode_eliminacio:
					if moble_hovered:
						eliminar_moble(moble_hovered)
					else:
						print("No hi ha cap moble per eliminar")
				else:
					activar_mode_eliminacio()
func actualitzar_posicio_camera():
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	
	# Calcula la nova posició de la càmera
	var pos_x = sin(camera_rotation_y) * cos(camera_rotation_x) * camera_distance
	var pos_y = camera_height + sin(camera_rotation_x) * camera_distance
	var pos_z = cos(camera_rotation_y) * cos(camera_rotation_x) * camera_distance
	
	camera.global_position = Vector3(pos_x, pos_y, pos_z)
	camera.look_at(Vector3.ZERO, Vector3.UP)

func entrar_mode_construccio():
	mode_construccio = true
	panel_ui.visible = true
	mostrar_grid()
	actualitzar_posicio_camera()  # Posiciona la càmera

func sortir_mode_construccio():
	mode_construccio = false
	panel_ui.visible = false
	amagar_grid()

	if moble_preview:
		moble_preview.queue_free()
		moble_preview = null

	deseleccionar_moble()
	desactivar_mode_eliminacio()
	index_preview = -1
	rotacio_preview = 0
	guardar_decoracio()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)  # Restaura el ratolí
	
func _process(delta):
	if mode_construccio and moble_preview and not mode_eliminacio:
		actualitzar_preview()
	if mode_construccio and mode_eliminacio:
		actualitzar_hover_eliminacio()
		
func actualitzar_preview():

	var pos = obtenir_posicio_grid()

	if pos != Vector3.ZERO:
		moble_preview.visible = true
		moble_preview.global_position = pos
		moble_preview.rotation_degrees.y = rotacio_preview

func mostrar_grid():
	var grid_visual_size = 5
	
	for x in range(-grid_visual_size, grid_visual_size + 1):
		for z in range(-grid_visual_size, grid_visual_size + 1):
			var punto = MeshInstance3D.new()
			punto.mesh = SphereMesh.new()
			punto.mesh.radius = 0.05
			punto.mesh.height = 0.1
			punto.position = Vector3(x * grid_size, 0.02, z * grid_size)
			
			var material = StandardMaterial3D.new()
			material.albedo_color = Color(0.5, 0.5, 0.5, 0.5)
			punto.set_surface_override_material(0, material)
			
			add_child(punto)
			punts_grid.append(punto)

func amagar_grid():
	for punto in punts_grid:
		if is_instance_valid(punto):  # Comprova que sigui vàlid
			punto.queue_free()
	punts_grid.clear()

func _on_moble_seleccionat(index: int):
	index_preview = index
	rotacio_preview = 0

	if moble_preview:
		moble_preview.queue_free()

	moble_preview = mobles_disponibles[index].instantiate()
	add_child(moble_preview)
	moble_preview.visible = false

func col_locar_moble():
	print("Col·locar moble")
	if moble_preview == null:
		return
	if index_preview < 0 or index_preview >= mobles_disponibles.size():
		return
	
	var pos = moble_preview.global_position
	
	# Determina quin tipus és el moble que vols col·locar
	var es_barra = "barra" in moble_preview.name.to_lower()
	var es_decoracio = moble_preview.is_in_group("decoracio")
	
	# Busca QUALSEVOL moble a aquesta posició
	var moble_vell_barra = buscar_moble_a_posicio(pos, "barres")
	var moble_vell_cadira = buscar_moble_a_posicio(pos, "mobles_reposats")
	var moble_vell_deco = buscar_moble_a_posicio(pos, "decoracio")
	
	# Si és decoració (planta)
	if es_decoracio:
		# No es pot col·locar si hi ha cadira
		if moble_vell_cadira:
			print("No pots col·locar una planta aquí, hi ha una cadira")
			return
		# Només esborra altra decoració
		if moble_vell_deco:
			moble_vell_deco.queue_free()
	else:
		# Si és barra, no es pot col·locar si hi ha cadira
		if es_barra and moble_vell_cadira:
			print("No pots col·locar una barra aquí, hi ha una cadira")
			return
		
		# Si és cadira, no es pot col·locar si hi ha barra o planta
		if not es_barra and (moble_vell_barra or moble_vell_deco):
			print("No pots col·locar una cadira aquí")
			return
		
		# Esborra el moble vell del MATEIX tipus
		if es_barra and moble_vell_barra:
			moble_vell_barra.queue_free()
		elif not es_barra and moble_vell_cadira:
			moble_vell_cadira.queue_free()
	
	var moble = mobles_disponibles[index_preview].instantiate()
	
	# Afegeix als grups corresponents
	if es_decoracio:
		moble.add_to_group("decoracio")
		print("Planta afegida al grup decoracio: ", moble.is_in_group("decoracio"))
	else:
		moble.add_to_group("mobles_base")
		if es_barra:
			moble.add_to_group("barres")
		else:
			moble.add_to_group("mobles_reposats")
	
	add_child(moble)
	moble.global_position = pos
	moble.rotation = moble_preview.rotation
	
	print("Moble col·locat")
		
func buscar_moble_a_posicio(posicio: Vector3, grup: String) -> Node3D:

	for moble in get_tree().get_nodes_in_group(grup):

		if round(moble.global_position.x / grid_size) == round(posicio.x / grid_size) \
		and round(moble.global_position.z / grid_size) == round(posicio.z / grid_size):

			return moble

	return null
	
func obtenir_moble_desde_collider(collider: Node) -> Node3D:
	var node = collider
	while node and node != self:
		# Ignora elements de la sala
		if node.name in ["Sol", "Paret Fons", "Paret Esquerra", "Paret Dreta", "Finestra", "PortaVisual"]:
			return null
		
		# Busca els grups "mobles_base" o "decoracio"
		if node.is_in_group("mobles_base") or node.is_in_group("decoracio"):
			print("Moble/Planta trobat: ", node.name, " - Grups: ", node.get_groups())
			return node
		
		print("Node verificat: ", node.name, " - Grups: ", node.get_groups())
		node = node.get_parent()
	
	return null

func deseleccionar_moble():
	if moble_seleccionat:
		restaurar_materials(moble_hovered)
		moble_seleccionat = null

func activar_mode_eliminacio():
	mode_eliminacio = true
	print("Mode eliminació activat")
	deseleccionar_moble()
	if moble_preview:
		moble_preview.visible = false
	if moble_hovered:
		restaurar_materials(moble_hovered)
		moble_hovered = null

func desactivar_mode_eliminacio():
	mode_eliminacio = false
	if moble_preview:
		moble_preview.visible = true
	if moble_hovered:
		restaurar_materials(moble_hovered)
		moble_hovered = null

func actualitzar_hover_eliminacio():
	var ratoli = get_viewport().get_mouse_position()
	var camera = get_viewport().get_camera_3d()
	var origen = camera.project_ray_origin(ratoli)
	var direccio = camera.project_ray_normal(ratoli)
	var query = PhysicsRayQueryParameters3D.create(
		origen,
		origen + direccio * 100
	)
	var resultat = get_world_3d().direct_space_state.intersect_ray(query)
	var moble = null
	if resultat and resultat.collider:
		moble = obtenir_moble_desde_collider(resultat.collider)
	
	if moble_hovered and moble_hovered != moble:
		restaurar_materials(moble_hovered)
		moble_hovered = null
	
	# Detecta mobles_base o decoracio
	if moble and moble != moble_preview and (moble.is_in_group("mobles_base") or moble.is_in_group("decoracio")):
		moble_hovered = moble
		canviar_color_moble(moble_hovered)

func obtenir_posicio_grid() -> Vector3:
	var ratolí_pos = get_viewport().get_mouse_position()
	var camera = get_viewport().get_camera_3d()
	var origen = camera.project_ray_origin(ratolí_pos)
	var direccio = camera.project_ray_normal(ratolí_pos)
	
	var espai = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(origen, origen + direccio * 100.0)
	var resultat = espai.intersect_ray(query)
	
	if resultat:
		var pos = resultat.position
		pos.x = round(pos.x / grid_size) * grid_size
		pos.z = round(pos.z / grid_size) * grid_size
		pos.y = 0.5
		return pos
	
	return Vector3.ZERO

func validar_posicio(moble: Node3D) -> bool:
	# Comprova si hi ha col·lisió amb altres objectes
	return true

func canviar_color_moble(moble: Node3D):

	for child in moble.get_children():

		if child is MeshInstance3D:
			child.material_override = material_hover

		elif child is Node3D:
			canviar_color_moble(child)
			
func restaurar_materials(moble: Node3D):

	if moble == null:
		return

	for child in moble.get_children():

		if child is MeshInstance3D:
			child.material_override = null

		elif child is Node3D:
			restaurar_materials(child)
			
func eliminar_moble(moble: Node3D):
	if moble == null:
		return
	if moble_seleccionat and moble_seleccionat != moble:
		restaurar_materials(moble_hovered)
	moble_seleccionat = moble
	canviar_color_moble(moble_seleccionat)

	print("Eliminant moble: ", moble.name)
	moble.queue_free()
	if moble_seleccionat == moble:
		deseleccionar_moble()

func seleccionar_moble():
	var ratoli = get_viewport().get_mouse_position()
	var camera = get_viewport().get_camera_3d()
	var origen = camera.project_ray_origin(ratoli)
	var direccio = camera.project_ray_normal(ratoli)
	var query = PhysicsRayQueryParameters3D.create(
		origen,
		origen + direccio * 100
	)
	var resultat = get_world_3d().direct_space_state.intersect_ray(query)
	if !resultat:
		return
	var node = resultat.collider
	if node == null:
		return
	var moble = obtenir_moble_desde_collider(node)
	if !moble or moble == moble_preview:
		return
	
	if moble_seleccionat and moble_seleccionat != moble:
		restaurar_materials(moble_hovered)
	
	moble_seleccionat = moble
	canviar_color_moble(moble_seleccionat)
	
func guardar_decoracio():
	var mobles_data = []
	
	# Guarda tots els mobles del grup mobles_base
	for moble in get_tree().get_nodes_in_group("mobles_base"):
		var scene_path = obtenir_scene_path_moble(moble)
		mobles_data.append({
			"index": obtenir_index_moble(moble),
			"scene_path": scene_path,
			"posicio": {"x": moble.global_position.x, "y": moble.global_position.y, "z": moble.global_position.z},
			"rotacio": {"x": moble.rotation.x, "y": moble.rotation.y, "z": moble.rotation.z},
			"tipus": "mobles_base",
			"grup": obtenir_grup_moble(moble)
		})
	
	# Guarda tota la decoracio
	for planta in get_tree().get_nodes_in_group("decoracio"):
		var scene_path = obtenir_scene_path_moble(planta)
		mobles_data.append({
			"index": obtenir_index_moble(planta),
			"scene_path": scene_path,
			"posicio": {"x": planta.global_position.x, "y": planta.global_position.y, "z": planta.global_position.z},
			"rotacio": {"x": planta.rotation.x, "y": planta.rotation.y, "z": planta.rotation.z},
			"tipus": "decoracio",
			"grup": "decoracio"
		})
	
	# Guarda a un fitxer JSON
	var json = JSON.stringify(mobles_data)
	var fitxer = FileAccess.open("user://casa_interior_mobles.save", FileAccess.WRITE)
	if fitxer:
		fitxer.store_string(json)
		print("Decoració guardada!")
	else:
		print("Error: No es pot guardar la decoració")

func carregar_decoracio():
	var mobles_existents = get_tree().get_nodes_in_group("mobles_base") + get_tree().get_nodes_in_group("decoracio")
	for moble in mobles_existents:
		if is_instance_valid(moble):
			moble.queue_free()
	
	var fitxer = FileAccess.open("user://casa_interior_mobles.save", FileAccess.READ)
	if not fitxer:
		print("Cap decoració guardada prèviament")
		return
	
	var json_string = fitxer.get_as_text()
	if json_string.is_empty():
		print("Fitxer buit")
		return
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		print("Error al parsejar JSON: ", error)
		return
	
	var mobles_data = json.data
	
	if mobles_data == null:
		print("Error: Dades nules")
		return
	
	if not mobles_data is Array:
		print("Error: Dades no és Array")
		return
	
	print("Carregant ", mobles_data.size(), " mobles")
	
	# Carrega cada moble
	for data in mobles_data:
		if not data is Dictionary:
			print("Error: data no és Dictionary")
			continue
		
		var scene_path = data.get("scene_path", "")
		var moble_scene: PackedScene = null
		
		if typeof(scene_path) == TYPE_STRING and not scene_path.is_empty() and ResourceLoader.exists(scene_path):
			var recurso = load(scene_path)
			if recurso is PackedScene:
				moble_scene = recurso
			else:
				print("El recurs no és una escena: ", scene_path)
		
		if moble_scene == null:
			var index = data.get("index", 0)
			if index >= mobles_disponibles.size():
				print("Error: index fora de rang - ", index)
				continue
			moble_scene = mobles_disponibles[index]
		
		if moble_scene == null:
			print("No s'ha pogut crear el moble a partir de la informació guardada")
			continue
		
		var moble = moble_scene.instantiate()
		
		# Afegeix al grup corresponent
		if data.get("tipus") == "decoracio":
			moble.add_to_group("decoracio")
		else:
			var grup_guardat = data.get("grup", "")
			moble.add_to_group("mobles_base")
			if grup_guardat == "barres":
				moble.add_to_group("barres")
			elif grup_guardat == "mobles_reposats":
				moble.add_to_group("mobles_reposats")
			else:
				# Compatibilitat amb fitxers antics: dedueix el grup si no hi ha dada guardada
				if "barra" in moble.name.to_lower():
					moble.add_to_group("barres")
				else:
					moble.add_to_group("mobles_reposats")
		
		add_child(moble)
		
		# Convierte diccionari a Vector3 amb més cura
		var posicio_data = data.get("posicio")
		var rotacio_data = data.get("rotacio")
		
		if posicio_data is Dictionary and rotacio_data is Dictionary:
			var posicio = Vector3(posicio_data.get("x", 0), posicio_data.get("y", 0), posicio_data.get("z", 0))
			var rotacio = Vector3(rotacio_data.get("x", 0), rotacio_data.get("y", 0), rotacio_data.get("z", 0))
			
			moble.global_position = posicio
			moble.rotation = rotacio
			print("Moble carregat: ", moble.name)
		else:
			print("Error: posicio o rotacio no són diccionaris")
	
	print("Decoració carregada!")

func obtenir_index_moble(moble: Node3D) -> int:
	# Busca l'índex del moble a mobles_disponibles
	var nom = moble.name.split("@")[0]  # Treu el sufijo de Godot
	
	for i in range(mobles_disponibles.size()):
		if mobles_disponibles[i].resource_path.contains(nom.to_lower()):
			return i
	
	return 0  # Per defecte el primer

func obtenir_grup_moble(moble: Node3D) -> String:
	if moble.is_in_group("decoracio"):
		return "decoracio"
	if moble.is_in_group("barres"):
		return "barres"
	if moble.is_in_group("mobles_reposats"):
		return "mobles_reposats"
	return "mobles_base"

func obtenir_scene_path_moble(moble: Node3D) -> String:
	if not moble.scene_file_path.is_empty():
		return moble.scene_file_path
	
	var nom = moble.name.to_lower()
	for scene in mobles_disponibles:
		if scene and scene.resource_path.to_lower().contains(nom):
			return scene.resource_path
	
	return ""

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		guardar_decoracio()
		get_tree().quit()
	
func _on_salir_casa():
	print("Sortint de la casa")
	guardar_decoracio()
	call_deferred("change_scene_to_world")

func change_scene_to_world():
	get_tree().change_scene_to_file("res://Scenes/World.tscn")
