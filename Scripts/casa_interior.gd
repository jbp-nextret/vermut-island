extends Node3D

@export var mobles_disponibles: Array[PackedScene]
@export var grid_size: float = 1.0

var mode_decoracio = false
var mode_construccio = false
var moble_actual: Node3D = null
var moble_preview: Node3D = null
var punts_grid: Array[Node3D] = []
var index_preview := -1
var rotacio_preview := 0.0
var moble_seleccionat: Node3D = null

@onready var panel_ui = $CanvasLayer/Panel
@onready var item_list = $CanvasLayer/ItemList
@onready var porta_sortida = $PortaSortida

func _ready():
	crear_interior()
	porta_sortida.salir_casa.connect(_on_salir_casa)
	
	# Mobles
	item_list.clear()
	var noms_mobles = ["Barra Normal", "Barra Mig", "Barra Lateral"]
	for nom in noms_mobles:
		item_list.add_item(nom)
	
	panel_ui.visible = false
	item_list.item_selected.connect(_on_moble_seleccionat)

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
	if Input.is_action_just_pressed("ui_focus_next"):
		if mode_construccio:
			sortir_mode_construccio()
		else:
			entrar_mode_construccio()
	if !mode_construccio:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			rotacio_preview += 90
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			rotacio_preview -= 90
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if moble_preview:
				col_locar_moble()
			else:
				seleccionar_moble()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			eliminar_moble()

func _process(delta):
	if mode_construccio and moble_preview:
		actualitzar_preview()
		
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

	if index_preview == -1:
		return

	var moble = mobles_disponibles[index_preview].instantiate()

	add_child(moble)

	moble.global_position = moble_preview.global_position
	moble.rotation = moble_preview.rotation

	print("Moble col·locat")

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

func canviar_color_moble(moble:Node3D, color:Color):
	for child in moble.get_children():
		if child is MeshInstance3D:
			var material = StandardMaterial3D.new()
			material.albedo_color = color
			child.set_surface_override_material(0, material)

func eliminar_moble():
	# Raycast per detectar quin moble hi ha al clic dret
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
	
	# Busca el pare (el moble sencer)
	var moble = node.get_parent()
	
	# Comprova que no sigui el preview ni els elements de la sala
	if moble == moble_preview or moble.name in ["Sol", "Paret Fons", "Paret Esquerra", "Paret Dreta"]:
		return
	
	print("Eliminant moble: ", moble.name)
	moble.queue_free()
	
	if moble_seleccionat == moble:
		moble_seleccionat = null
	
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
	var moble = node.get_parent()
	if moble_seleccionat:
		canviar_color_moble(moble_seleccionat, Color.GREEN)

	moble_seleccionat = moble

	canviar_color_moble(moble_seleccionat, Color.GREEN)


func entrar_mode_construccio():
	mode_construccio = true
	panel_ui.visible = true
	mostrar_grid()

func sortir_mode_construccio():
	mode_construccio = false
	panel_ui.visible = false
	amagar_grid()

	if moble_preview:
		moble_preview.queue_free()
		moble_preview = null

	index_preview = -1
	rotacio_preview = 0
	
func _on_salir_casa():
	print("Sortint de la casa")
	get_tree().change_scene_to_file("res://Scenes/World.tscn")
