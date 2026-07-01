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

	# Instància temporal per saber de quin grup és el moble nou
	var moble_nou = mobles_disponibles[index_preview].instantiate()

	var grup = ""
	if moble_nou.is_in_group("mobles_base"):
		grup = "mobles_base"
	elif moble_nou.is_in_group("cadires"):
		grup = "cadires"
	elif moble_nou.is_in_group("decoracio"):
		grup = "decoracio"

	# Busca només un moble del mateix grup
	var moble_vell = buscar_moble_a_posicio(pos, grup)

	if moble_vell:
		moble_vell.queue_free()

	add_child(moble_nou)

	moble_nou.global_position = pos
	moble_nou.rotation = moble_preview.rotation

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
		if node.is_in_group("mobles_base") \
		or node.is_in_group("cadires") \
		or node.is_in_group("decoracio"):
			return node

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

	if resultat:
		print("Collider:", resultat.collider.name)

		moble = obtenir_moble_desde_collider(resultat.collider)

		if moble:
			print("Moble detectat:", moble.name)
		else:
			print("No pertany a cap grup")

	if moble_hovered and moble_hovered != moble:
		restaurar_materials(moble_hovered)
		moble_hovered = null

	if moble and moble != moble_preview:
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
	
func _on_salir_casa():
	print("Sortint de la casa")
	call_deferred("change_scene_to_world")

func change_scene_to_world():
	get_tree().change_scene_to_file("res://Scenes/World.tscn")
